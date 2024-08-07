//
//  ObjectDetectionManager.swift
//  SafeWalk
//
//  Created by Sai Dutt Ganduri on 8/6/24.
//

import Vision
import CoreML

class ObjectDetectionManager {
    private var visionModel: VNCoreMLModel?
    
    init() {
        setupModel()
    }
    
    private func setupModel() {
        guard let model = try? VNCoreMLModel(for: YOLOv3(configuration: MLModelConfiguration()).model) else {
            fatalError("Failed to load Vision ML model")
        }
        visionModel = model
    }
    
    func detectObjects(in image: CGImage, completion: @escaping ([DetectedObject]) -> Void) {
        guard let model = visionModel else {
            completion([])
            return
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNRecognizedObjectObservation] else {
                completion([])
                return
            }
            
            let detectedObjects = results.map { observation -> DetectedObject in
                let boundingBox = observation.boundingBox
                let label = observation.labels.first?.identifier ?? "Unknown"
                let confidence = observation.confidence
                
                return DetectedObject(boundingBox: boundingBox, label: label, confidence: confidence)
            }
            
            completion(detectedObjects)
        }
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform detection: \(error)")
            completion([])
        }
    }
}

struct DetectedObject {
    let id = UUID()
    let boundingBox: CGRect
    let label: String
    let confidence: Float
}
