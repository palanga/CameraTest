//
//  ContentView.swift
//  CameraTest
//
//  Created by Andrés González on 10/04/2020.
//  Copyright © 2020 Andrés González. All rights reserved.
//

import SwiftUI
import AVFoundation
import Combine


struct ContentView: View {
    
    let camera: Camera = CameraBuilder().make()!
    
    var body: some View {
        
        return VStack {
            
            camera
                .viewfinder
                .onTapGesture { self.camera.takePhoto() }
            
            Slider(value: camera.focusBinding())
            Slider(value: camera.shutterSpeedBinding())
            
        }
    }

}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
