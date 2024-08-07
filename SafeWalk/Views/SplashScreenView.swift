import SwiftUI

struct SplashScreenView: View {
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                // Hero text
                Text("SafeWalk")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Version number
                Text("v1.0")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom)
            }
        }
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
    }
}
