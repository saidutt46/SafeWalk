import AVFoundation
import UIKit
import Vision

class CameraController: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isSessionRunning = false
    @Published var closestDepth: Float = Float.infinity
    @Published var errorMessage: String?
    @Published var detectedObjects: [DetectedObject] = []
    
    private let objectDetectionManager = ObjectDetectionManager()
    private let captureSession = AVCaptureSession()
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var depthDataOutput: AVCaptureDepthDataOutput?
    
    private enum SetupError: Error {
        case cameraUnavailable
        case inputSetupFailed
        case outputSetupFailed
        case configurationFailed
    }
    
    override init() {
        super.init()
        do {
            try setupCaptureSession()
        } catch {
            handleSetupError(error)
        }
    }
    
    private func setupCaptureSession() throws {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        guard let device = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) else {
            throw SetupError.cameraUnavailable
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard captureSession.canAddInput(input) else { throw SetupError.inputSetupFailed }
            captureSession.addInput(input)
            
            try configureCamera(device)
            try setupVideoDataOutput()
            try setupDepthDataOutput()
            
            captureSession.sessionPreset = .high
        } catch {
            throw SetupError.configurationFailed
        }
    }
    
    private func configureCamera(_ device: AVCaptureDevice) throws {
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30) // 30 fps
            device.focusMode = .continuousAutoFocus
            device.unlockForConfiguration()
        } catch {
            throw SetupError.configurationFailed
        }
    }
    
    private func setupVideoDataOutput() throws {
        videoDataOutput = AVCaptureVideoDataOutput()
        guard let videoDataOutput = videoDataOutput,
              captureSession.canAddOutput(videoDataOutput) else {
            throw SetupError.outputSetupFailed
        }
        
        captureSession.addOutput(videoDataOutput)
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        if let connection = videoDataOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            connection.isVideoMirrored = false
        }
    }
    
    private func setupDepthDataOutput() throws {
        depthDataOutput = AVCaptureDepthDataOutput()
        guard let depthDataOutput = depthDataOutput,
              captureSession.canAddOutput(depthDataOutput) else {
            throw SetupError.outputSetupFailed
        }
        
        captureSession.addOutput(depthDataOutput)
        depthDataOutput.setDelegate(self, callbackQueue: DispatchQueue(label: "depthQueue"))
        depthDataOutput.isFilteringEnabled = true
        
        if let connection = depthDataOutput.connection(with: .depthData) {
            connection.videoOrientation = .portrait
        }
    }
    
    private func handleSetupError(_ error: Error) {
        switch error {
        case SetupError.cameraUnavailable:
            errorMessage = "LiDAR camera unavailable"
        case SetupError.inputSetupFailed:
            errorMessage = "Failed to set up camera input"
        case SetupError.outputSetupFailed:
            errorMessage = "Failed to set up camera output"
        case SetupError.configurationFailed:
            errorMessage = "Failed to configure camera"
        default:
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
    
    func startSession() {
        guard !isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = self?.captureSession.isRunning ?? false
            }
        }
    }
    
    func stopSession() {
        guard isSessionRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
                self?.closestDepth = Float.infinity
                self?.capturedImage = nil
            }
        }
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
                
        objectDetectionManager.detectObjects(in: cgImage) { [weak self] detectedObjects in
            DispatchQueue.main.async {
                self?.detectedObjects = detectedObjects
            }
        }
        
        let cropRect = calculateCenterCropRect(for: ciImage.extent)
        
        let transform = CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y)
        let correctedImage = ciImage.cropped(to: cropRect).transformed(by: transform)
        
        guard let cgImage = context.createCGImage(correctedImage, from: correctedImage.extent) else { return }
        
        let image = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async {
            self.capturedImage = image
        }
    }
    
    private func calculateCenterCropRect(for extent: CGRect) -> CGRect {
        let aspectRatio = extent.width / extent.height
        var cropWidth = extent.width
        var cropHeight = extent.height

        if aspectRatio > 1 { // width > height
            cropWidth = extent.height * aspectRatio
        } else { // height >= width
            cropHeight = extent.width / aspectRatio
        }

        let cropSize = CGSize(width: cropWidth, height: cropHeight)
        let cropOrigin = CGPoint(
            x: (extent.width - cropWidth) / 2,
            y: (extent.height - cropHeight) / 2
        )
        return CGRect(origin: cropOrigin, size: cropSize)
    }
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        let depthData = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let pixelBuffer = depthData.depthDataMap
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        var minDepth = Float.infinity
        
        let sampleStep = 5 // Sample every 5th pixel for performance
        for y in stride(from: 0, to: height, by: sampleStep) {
            for x in stride(from: 0, to: width, by: sampleStep) {
                let offset = y * bytesPerRow + x * MemoryLayout<Float>.size
                let depth = baseAddress.load(fromByteOffset: offset, as: Float.self)
                
                if depth > 0 && depth < minDepth {
                    minDepth = depth
                }
            }
        }
        
        DispatchQueue.main.async {
            if minDepth < Float.infinity {
                self.closestDepth = minDepth
            }
        }
    }
}
