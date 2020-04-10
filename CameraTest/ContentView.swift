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
            
            FocusSlider(onChange: self.camera.focus).padding(32)
                
            //            Slider(
            //                value: Binding(
            //                    get: {
            //                        self.focus
            //                },
            //                    set: {(newValue) in
            //                        self.focus = newValue
            //                        self.camera.focus(value: newValue)
            //                }),
            //                in: 0...1
            //            ).padding(32)
        }
    }
}

struct FocusSlider: View {
    
    @State private var value: Float = 0.5
    
    let onChange: (Float) -> Void
    
    var body: some View {
        Slider(
            value: Binding(
                get: {
                    self.value
            },
                set: {(newValue) in
                    self.value = newValue
                    self.onChange(newValue)
            }),
            in: 0...1
        )
    }
}


//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView()
//    }
//}
