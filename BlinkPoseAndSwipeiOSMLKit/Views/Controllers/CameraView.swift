//
//  CameraView.swift
//  BlinkPoseAndSwipeiOSMLKit
//
//  Created by Anupam Chugh on 25/01/20.
//  Copyright © 2020 iowncode. All rights reserved.
//

import UIKit
import AVFoundation
#if canImport(MLKitFaceDetection)
import MLKitFaceDetection
import MLKitVision
#endif

final class CameraView: UIView {
    
    var blinkDelegate : BlinkSwiperDelegate?
    var headDelegate : headSwiperDelegate?
    var restingFace = true
    var restFace = true
    
    #if canImport(MLKitFaceDetection)
    lazy var options : FaceDetectorOptions = {
        let o = FaceDetectorOptions()
        o.performanceMode = .accurate
        o.classificationMode = .all
        o.isTrackingEnabled = false
//        o.performanceMode = .fast
        return o
    }()
    #endif
    
    
    private lazy var videoDataOutput: AVCaptureVideoDataOutput = {
        let v = AVCaptureVideoDataOutput()
        v.alwaysDiscardsLateVideoFrames = true
        v.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        v.connection(with: .video)?.isEnabled = true
        return v
    }()
    
    private let videoDataOutputQueue: DispatchQueue = DispatchQueue(label: "VideoDataOutputQueue")
    
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let l = AVCaptureVideoPreviewLayer(session: session)
        l.videoGravity = .resizeAspect
        return l
    }()
    
    private let captureDevice: AVCaptureDevice? = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    private lazy var session: AVCaptureSession = {
        return AVCaptureSession()
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func beginSession() {
        
        guard let captureDevice = captureDevice else { return }
        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        layer.masksToBounds = true
        layer.addSublayer(previewLayer)
        previewLayer.frame = bounds
        session.startRunning()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

extension CameraView: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer from sample buffer.")
            return
        }
        #if canImport(MLKitFaceDetection)
        let visionImage = VisionImage(buffer: sampleBuffer)
        visionImage.orientation = imageOrientation()
        let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        
        DispatchQueue.global().async {
            self.detectFacesOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
        }
        #endif
        
        
    }
    
    public  func imageOrientation(
        fromDevicePosition devicePosition: AVCaptureDevice.Position = .front
    ) -> UIImage.Orientation {
        var deviceOrientation = UIDevice.current.orientation
        if deviceOrientation == .faceDown || deviceOrientation == .faceUp ||
            deviceOrientation == .unknown {
            deviceOrientation = currentUIOrientation()
        }
        switch deviceOrientation {
        case .portrait:
            return devicePosition == .front ? .leftMirrored : .right
        case .landscapeLeft:
            return devicePosition == .front ? .downMirrored : .up
        case .portraitUpsideDown:
            return devicePosition == .front ? .rightMirrored : .left
        case .landscapeRight:
            return devicePosition == .front ? .upMirrored : .down
        case .faceDown, .faceUp, .unknown:
            return .up
        @unknown default:
            fatalError()
        }
    }
    
    private func currentUIOrientation() -> UIDeviceOrientation {
        let deviceOrientation = { () -> UIDeviceOrientation in
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .portrait, .unknown:
                return .portrait
            @unknown default:
                fatalError()
            }
        }
        guard Thread.isMainThread else {
            var currentOrientation: UIDeviceOrientation = .portrait
            DispatchQueue.main.sync {
                currentOrientation = deviceOrientation()
            }
            return currentOrientation
        }
        return deviceOrientation()
    }
    
    
    
    #if canImport(MLKitFaceDetection)
    private func detectFacesOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
        
        let faceDetector = FaceDetector.faceDetector(options: options)
        
        faceDetector.process(image, completion: { features, error in
            if let error = error {
                print(error.localizedDescription)
                return
            }
            
            guard error == nil, let features = features, !features.isEmpty else {
                //print("On-Device face detector returned no results.")
                return
            }
            
            
            if let face = features.first {
                
             
                let rightHeadMoveProbability = face.headEulerAngleZ
                let leftHeadMoveProbability = face.headEulerAngleZ
                
//                print("head euler X angle is \(face.headEulerAngleZ)")
//                print("left eye movement is \(face.leftEyeOpenProbability)")
//                print("right eye movement is \(face.rightEyeOpenProbability)")
             
                 if rightHeadMoveProbability < -25
                {
                    if self.restingFace{
                        self.restingFace = false
                        self.headDelegate?.rightPose()
                    }
                }
                
                else if leftHeadMoveProbability > 25
                {
                    if self.restingFace{
                        self.restingFace = false
                        self.headDelegate?.leftPose()
                    }
                }
                
                else{
                    self.restingFace = true
                }
            }
            
            
            if let faces = features.first{

                let leftEyeOpenProbability = faces.leftEyeOpenProbability
                let rightEyeOpenProbability = faces.rightEyeOpenProbability
//              let smilingProbability = faces.smilingProbability
                
//                print("smiling value is \(faces.smilingProbability)")
//                                print("left eye movement is \(faces.leftEyeOpenProbability)")
//                                print("right eye movement is \(faces.rightEyeOpenProbability)")
                
//                if leftEyeOpenProbability > 0.95 && rightEyeOpenProbability > 0.95
//                                {
//                                    self.restFace = true
//                             }
                
                 if leftEyeOpenProbability > 0.95 && rightEyeOpenProbability < 0.1
                                {
                                    if self.restFace {
                                        self.restFace = false
//                                        self.blinkDelegate?.rightBlink()
                                        self.blinkDelegate?.leftBlink()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1)
                                        {self.restFace = true}
                                    }
                                }
        
                else if rightEyeOpenProbability > 0.95 && leftEyeOpenProbability < 0.1
                                {
                                    if self.restFace {
                                        self.restFace = false
//                                        self.blinkDelegate?.leftBlink()
                                        self.blinkDelegate?.rightBlink()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1)
                                        {self.restFace = true}
                                    }
                            }
                
                else if rightEyeOpenProbability >=  leftEyeOpenProbability && leftEyeOpenProbability <= rightEyeOpenProbability {
                    self.restFace = true
                }
                
//                else {
//                    self.restFace = false
//                }
            }

        })
    }
    #endif
        
    
}

//extension CameraView {
//
//    private func addObservers() {
//        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanges), name: Notification.Name("AVCaptureSessionRuntimeErrorNotification"), object: session)
//    }
//
//    @objc func sessionChanges(_ notification: Notification){
//        let session = AVCaptureSession()
//        guard let changeValue = notification.userInfo?[AVCaptureSession] as?  NSData else { return }
//
//        let valueChanged = AVCaptureVideoDataOutput()
//
//        if valueChanged == .KeyValueObservingPublisher {
//            sessionQueue.async
//        }
//    }
//}
