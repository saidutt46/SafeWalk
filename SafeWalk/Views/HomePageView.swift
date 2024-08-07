//
//  HomePageView.swift
//  SafeWalk
//
//  Created by Sai Dutt Ganduri on 8/5/24.
//

import SwiftUI

struct HomePageView: View {
    var onStartCamera: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color(white: 0.98)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Text("SafeWalk")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.black)
                
                Text("Welcome to SafeWalk")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("• Use the camera to detect obstacles")
                    Text("• Get real-time depth information")
                    Text("• Receive warnings for close objects")
                }
                .font(.body)
                .foregroundColor(.black)
                
                Spacer()
                
                Button(action: onStartCamera) {
                    Text("Start Camera")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(minWidth: 200)
                        .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                                                   startPoint: .leading,
                                                   endPoint: .trailing))
                        .cornerRadius(25)
                        .shadow(color: .gray.opacity(0.3), radius: 5, x: 0, y: 3)
                }
            }
            .padding()
        }
    }
}
