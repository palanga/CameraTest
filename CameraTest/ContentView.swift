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
            
            Selector(onChange: self.camera.focus).padding(24)
            
        }
    }

}

class Settings: ObservableObject {
    @Published var focus: Float = 0
}

struct AnotherSlider: View {
    
    @Binding var value: Float
    
    var body: some View {
        
//        $value.on
        
        Slider(value: $value)
    }
    
}

struct Selector: View {
    
//    @State private var value: Float = 0.5
    
    @EnvironmentObject var settings: Settings

    let onChange: (Float) -> Void
    
    var body: some View {
        Slider(
            value: Binding(
                get: {
                    self.settings.focus
            },
                set: {(newValue) in
                    self.settings.focus = newValue
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
