import SwiftUI

struct ContentView: View {
    @StateObject private var cameraController = CameraController()
    @State private var showingSplashScreen = true
    @State private var showingCamera = false
    
    private let warningThreshold: Float = 0.3048 // 1 foot in meters
    
    var body: some View {
        Group {
            if showingSplashScreen {
                SplashScreenView()
            } else if showingCamera {
                cameraView
            } else {
                HomePageView(onStartCamera: {
                    self.showingCamera = true
                    self.cameraController.startSession()
                })
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation {
                    self.showingSplashScreen = false
                }
            }
        }
    }
    
    var cameraView: some View {
        ZStack {
            if let image = cameraController.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                
                // Overlay detected objects
                ForEach(cameraController.detectedObjects, id: \.id) { object in
                    BoundingBoxView(object: object)
                }
            }
            
            VStack {
                Spacer()
                
                VStack(spacing: 20) {
                    depthInfoView
                    
                    Button(action: {
                        cameraController.stopSession()
                        withAnimation {
                            self.showingCamera = false
                        }
                    }) {
                        Text("Stop Camera")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(minWidth: 200)
                            .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                                                       startPoint: .leading,
                                                       endPoint: .trailing))
                            .cornerRadius(25)
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
        .alert(item: Binding<AlertItem?>(
            get: { cameraController.errorMessage.map { AlertItem(message: $0) } },
            set: { _ in cameraController.errorMessage = nil }
        )) { alertItem in
            Alert(title: Text("Error"), message: Text(alertItem.message), dismissButton: .default(Text("OK")))
        }
    }
    
    var depthInfoView: some View {
        VStack(alignment: .leading, spacing: 10) {
            let distanceInFeet = cameraController.closestDepth * 3.28084 // Convert meters to feet
            
            Text("Closest Object: \(distanceInFeet, specifier: "%.2f") ft")
                .foregroundColor(.white)
                .font(.title3)
            
            if cameraController.closestDepth < warningThreshold {
                Text("WARNING: Object is very close!")
                    .foregroundColor(.red)
                    .font(.headline)
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
    }
}

struct BoundingBoxView: View {
    let object: DetectedObject
    
    var body: some View {
        GeometryReader { geometry in
            let rect = CGRect(
                x: object.boundingBox.minX * geometry.size.width,
                y: object.boundingBox.minY * geometry.size.height,
                width: object.boundingBox.width * geometry.size.width,
                height: object.boundingBox.height * geometry.size.height
            )
            
            Rectangle()
                .path(in: rect)
                .stroke(Color.red, lineWidth: 2)
            
            Text("\(object.label) (\(Int(object.confidence * 100))%)")
                .font(.caption)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .position(x: rect.midX, y: rect.minY - 10)
        }
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let message: String
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
