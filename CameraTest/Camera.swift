//
//  Camera.swift
//  CameraTest
//
//  Created by Andrés González on 10/04/2020.
//  Copyright © 2020 Andrés González. All rights reserved.
//

import Foundation
import AVFoundation
import Photos
import SwiftUI

class Camera {
    
    fileprivate let device: AVCaptureDevice
    fileprivate let photoOutput: AVCapturePhotoOutput
    fileprivate let delegate: AVCapturePhotoCaptureDelegate
    
    private var _focus: Float = 0.5
    private var _shutterSpeed: Double = 1 / 60
    private var _iso: Float = 400
    
    let viewfinder: CameraViewfinder
    
    init(
        device: AVCaptureDevice,
        photoOutput: AVCapturePhotoOutput,
        delegate: AVCapturePhotoCaptureDelegate,
        viewfinder: CameraViewfinder
    ) {
        self.device = device
        self.photoOutput = photoOutput
        self.delegate = delegate
        self.viewfinder = viewfinder
        
    }
    
    func takePhoto() {
        photoOutput.capturePhoto(with: .init(), delegate: delegate)
    }
    
    func focusBinding() -> Binding<Float> {
        return Binding(get: { self._focus }, set: {(newValue) in
            self._focus = newValue
            self.handleFocus(value: newValue)
        })
    }
    
    func shutterSpeedBinding() -> Binding<Double> {
        return Binding(get: { self._shutterSpeed }, set: {(newValue) in
            self._shutterSpeed = newValue
            self.handleShutterSpeed(value: newValue)
        })
    }
    
    func isoBinding() -> Binding<Float> {
        return Binding(get: { self._iso }, set: {(newValue) in
            self._iso = newValue
            self.handleISO(value: newValue)
        })
    }
    
    private func handleFocus(value: Float) {
        do {
            try device.lockForConfiguration()
            device.setFocusModeLocked(lensPosition: value, completionHandler: nil)
            device.unlockForConfiguration()
        } catch {}
    }
    
    private func handleShutterSpeed(value: Double) {
        do {
            try device.lockForConfiguration()
            
            let sanitizedShutterSpeed = getSanitizedShutterSpeed(value: value)
            
            device.setExposureModeCustom(duration: sanitizedShutterSpeed, iso: getSanitizedISO(value: self._iso), completionHandler: nil)
            device.unlockForConfiguration()
        } catch {}
    }
    
    private func getSanitizedShutterSpeed(value: Double) -> CMTime {
        let min = self.device.activeFormat.minExposureDuration
        let max = self.device.activeFormat.maxExposureDuration

        let xMax = -(log(min.seconds) / log(2))
        
        let aux = CMTime.init(
            seconds: 1 / pow(2, xMax * value),
            preferredTimescale: 1000000
        )

        if aux < min {
            return min
        } else if max < aux {
            return max
        } else {
            return aux
        }
    }
    
    private func handleISO(value: Float) {
        do {
            try device.lockForConfiguration()
            
            let sanitizedISO = getSanitizedISO(value: value)
            
            print(sanitizedISO)

            device.setExposureModeCustom(duration: getSanitizedShutterSpeed(value: self._shutterSpeed), iso: sanitizedISO, completionHandler: nil)
            device.unlockForConfiguration()
        } catch {}
    }
    
    private func getSanitizedISO(value: Float) -> Float {
        let min = self.device.activeFormat.minISO
        let max = self.device.activeFormat.maxISO
        
        print(min)
        print(max)

        let xMax = log(max / 100) / log(2)
        
        let aux = pow(2, value * (xMax + 2) - 2) * 100
        
        
        if aux < min {
            return min
        } else if max < aux {
            return max
        } else {
            return aux
        }
    }
    
}


struct CameraBuilder {
    func make() -> Camera? {
        if let device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) {
            
            let captureSession = AVCaptureSession()
            captureSession.beginConfiguration()
            
            let photoOutput = AVCapturePhotoOutput()
            
            do {
                try captureSession.addInput(AVCaptureDeviceInput(device: device))
                captureSession.addOutput(photoOutput)
            } catch {
                print("error in: captureSession.addInput(AVCaptureDeviceInput(device: device))")
                return nil
            }
            
            captureSession.sessionPreset = AVCaptureSession.Preset.photo
            
            captureSession.commitConfiguration()
            
            let photoCaptureSettings = AVCapturePhotoSettings()
            
            return Camera(
                device: device,
                photoOutput: photoOutput,
                delegate: PhotoCaptureProcessor(with: photoCaptureSettings),
                viewfinder: CameraViewfinder(session: captureSession)
            )
            
        } else {
            return nil
        }
    }
}




class PreviewView: UIView {
    private var captureSession: AVCaptureSession
    
    init(session: AVCaptureSession) {
        self.captureSession = session
        super.init(frame: .zero)
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if self.superview != nil {
            self.videoPreviewLayer.session = self.captureSession
            self.videoPreviewLayer.videoGravity = .resizeAspect
            self.captureSession.startRunning()
        } else {
            self.captureSession.stopRunning()
        }
    }
}


struct CameraViewfinder: UIViewRepresentable {
    
    internal var session: AVCaptureSession
    
    func makeUIView(context: UIViewRepresentableContext<CameraViewfinder>) -> PreviewView {
        PreviewView(session: session)
    }
    
    func updateUIView(_ uiView: PreviewView, context: UIViewRepresentableContext<CameraViewfinder>) {
    }
    
    typealias UIViewType = PreviewView
}







class PhotoCaptureProcessor: NSObject {
    private(set) var requestedPhotoSettings: AVCapturePhotoSettings
    
    //    private let willCapturePhotoAnimation: () -> Void
    
    //    private let livePhotoCaptureHandler: (Bool) -> Void
    
    lazy var context = CIContext()
    
    //    private let completionHandler: (PhotoCaptureProcessor) -> Void
    
    //    private let photoProcessingHandler: (Bool) -> Void
    
    private var photoData: Data?
    
    private var livePhotoCompanionMovieURL: URL?
    
    private var portraitEffectsMatteData: Data?
    
    private var semanticSegmentationMatteDataArray = [Data]()
    
    private var maxPhotoProcessingTime: CMTime?
    
    init(with requestedPhotoSettings: AVCapturePhotoSettings
        //         willCapturePhotoAnimation: @escaping () -> Void,
        //         livePhotoCaptureHandler: @escaping (Bool) -> Void,
        //         completionHandler: @escaping (PhotoCaptureProcessor) -> Void
        //         photoProcessingHandler: @escaping (Bool) -> Void
    ) {
        self.requestedPhotoSettings = requestedPhotoSettings
        //        self.willCapturePhotoAnimation = willCapturePhotoAnimation
        //        self.livePhotoCaptureHandler = livePhotoCaptureHandler
        //        self.completionHandler = completionHandler
        //        self.photoProcessingHandler = photoProcessingHandler
    }
    
    private func didFinish() {
        if let livePhotoCompanionMoviePath = livePhotoCompanionMovieURL?.path {
            if FileManager.default.fileExists(atPath: livePhotoCompanionMoviePath) {
                do {
                    try FileManager.default.removeItem(atPath: livePhotoCompanionMoviePath)
                } catch {
                    print("Could not remove file at url: \(livePhotoCompanionMoviePath)")
                }
            }
        }
        
        //        completionHandler(self)
    }
    
}

extension PhotoCaptureProcessor: AVCapturePhotoCaptureDelegate {
    /*
     This extension adopts all of the AVCapturePhotoCaptureDelegate protocol methods.
     */
    
    /// - Tag: WillBeginCapture
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        if resolvedSettings.livePhotoMovieDimensions.width > 0 && resolvedSettings.livePhotoMovieDimensions.height > 0 {
            //            livePhotoCaptureHandler(true)
        }
        maxPhotoProcessingTime = resolvedSettings.photoProcessingTimeRange.start + resolvedSettings.photoProcessingTimeRange.duration
    }
    
    /// - Tag: WillCapturePhoto
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        //        willCapturePhotoAnimation()
        
        guard let maxPhotoProcessingTime = maxPhotoProcessingTime else {
            return
        }
        
        // Show a spinner if processing time exceeds one second.
        let oneSecond = CMTime(seconds: 1, preferredTimescale: 1)
        if maxPhotoProcessingTime > oneSecond {
            //            photoProcessingHandler(true)
        }
    }
    
    func handleMatteData(_ photo: AVCapturePhoto, ssmType: AVSemanticSegmentationMatte.MatteType) {
        
        // Find the semantic segmentation matte image for the specified type.
        guard var segmentationMatte = photo.semanticSegmentationMatte(for: ssmType) else { return }
        
        // Retrieve the photo orientation and apply it to the matte image.
        if let orientation = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
            let exifOrientation = CGImagePropertyOrientation(rawValue: orientation) {
            // Apply the Exif orientation to the matte image.
            segmentationMatte = segmentationMatte.applyingExifOrientation(exifOrientation)
        }
        
        var imageOption: CIImageOption!
        
        // Switch on the AVSemanticSegmentationMatteType value.
        switch ssmType {
        case .hair:
            imageOption = .auxiliarySemanticSegmentationHairMatte
        case .skin:
            imageOption = .auxiliarySemanticSegmentationSkinMatte
        case .teeth:
            imageOption = .auxiliarySemanticSegmentationTeethMatte
        default:
            print("This semantic segmentation type is not supported!")
            return
        }
        
        guard let perceptualColorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        
        // Create a new CIImage from the matte's underlying CVPixelBuffer.
        let ciImage = CIImage( cvImageBuffer: segmentationMatte.mattingImage,
                               options: [imageOption: true,
                                         .colorSpace: perceptualColorSpace])
        
        // Get the HEIF representation of this image.
        guard let imageData = context.heifRepresentation(of: ciImage,
                                                         format: .RGBA8,
                                                         colorSpace: perceptualColorSpace,
                                                         options: [.depthImage: ciImage]) else { return }
        
        // Add the image data to the SSM data array for writing to the photo library.
        semanticSegmentationMatteDataArray.append(imageData)
    }
    
    /// - Tag: DidFinishProcessingPhoto
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        //        photoProcessingHandler(false)
        
        if let error = error {
            print("Error capturing photo: \(error)")
        } else {
            photoData = photo.fileDataRepresentation()
        }
        // A portrait effects matte gets generated only if AVFoundation detects a face.
        if var portraitEffectsMatte = photo.portraitEffectsMatte {
            if let orientation = photo.metadata[ String(kCGImagePropertyOrientation) ] as? UInt32 {
                portraitEffectsMatte = portraitEffectsMatte.applyingExifOrientation(CGImagePropertyOrientation(rawValue: orientation)!)
            }
            let portraitEffectsMattePixelBuffer = portraitEffectsMatte.mattingImage
            let portraitEffectsMatteImage = CIImage( cvImageBuffer: portraitEffectsMattePixelBuffer, options: [ .auxiliaryPortraitEffectsMatte: true ] )
            
            guard let perceptualColorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
                portraitEffectsMatteData = nil
                return
            }
            portraitEffectsMatteData = context.heifRepresentation(of: portraitEffectsMatteImage,
                                                                  format: .RGBA8,
                                                                  colorSpace: perceptualColorSpace,
                                                                  options: [.portraitEffectsMatteImage: portraitEffectsMatteImage])
        } else {
            portraitEffectsMatteData = nil
        }
        
        for semanticSegmentationType in output.enabledSemanticSegmentationMatteTypes {
            handleMatteData(photo, ssmType: semanticSegmentationType)
        }
    }
    
    /// - Tag: DidFinishRecordingLive
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        //        livePhotoCaptureHandler(false)
    }
    
    /// - Tag: DidFinishProcessingLive
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error != nil {
            print("Error processing Live Photo companion movie: \(String(describing: error))")
            return
        }
        livePhotoCompanionMovieURL = outputFileURL
    }
    
    /// - Tag: DidFinishCapture
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            didFinish()
            return
        }
        
        guard let photoData = photoData else {
            print("No photo data resource")
            didFinish()
            return
        }
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    let options = PHAssetResourceCreationOptions()
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    options.uniformTypeIdentifier = self.requestedPhotoSettings.processedFileType.map { $0.rawValue }
                    creationRequest.addResource(with: .photo, data: photoData, options: options)
                    
                    if let livePhotoCompanionMovieURL = self.livePhotoCompanionMovieURL {
                        let livePhotoCompanionMovieFileOptions = PHAssetResourceCreationOptions()
                        livePhotoCompanionMovieFileOptions.shouldMoveFile = true
                        creationRequest.addResource(with: .pairedVideo,
                                                    fileURL: livePhotoCompanionMovieURL,
                                                    options: livePhotoCompanionMovieFileOptions)
                    }
                    
                    // Save Portrait Effects Matte to Photos Library only if it was generated
                    if let portraitEffectsMatteData = self.portraitEffectsMatteData {
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .photo,
                                                    data: portraitEffectsMatteData,
                                                    options: nil)
                    }
                    // Save Portrait Effects Matte to Photos Library only if it was generated
                    for semanticSegmentationMatteData in self.semanticSegmentationMatteDataArray {
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .photo,
                                                    data: semanticSegmentationMatteData,
                                                    options: nil)
                    }
                    
                }, completionHandler: { _, error in
                    if let error = error {
                        print("Error occurred while saving photo to photo library: \(error)")
                    }
                    
                    self.didFinish()
                }
                )
            } else {
                self.didFinish()
            }
        }
    }
}
