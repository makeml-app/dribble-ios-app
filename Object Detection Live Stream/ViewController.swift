//
//  ViewController.swift
//  Object Detection Live Stream
//
//  Created by Alexey Korotkov on 6/25/19.
//  Copyright © 2019 Alexey Korotkov. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var bufferSize: CGSize = .zero
    var rootLayer: CALayer! = nil
    
    @IBOutlet weak private var previewView: UIView!
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    let viewOnTop = UIView()
    let startButton = UIButton()
    let stopButton = UIButton()
    let labelWithTimer = UILabel()
    let labelWithNumberOfTouches = UILabel()
    var timer = Timer()
    var miliseconds = 0
    
    var ballXCenterArray = [CGFloat]()
    
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // to be implemented in the subclass
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAVCapture()
        
        self.view.addSubview(stopButton)
        stopButton.layer.cornerRadius = 20
        stopButton.layer.masksToBounds = true
        stopButton.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        stopButton.setTitle("Stop", for: .normal)
        stopButton.setTitleColor(.black, for: .normal)
        stopButton.frame = CGRect(x: 20, y: UIScreen.screens.first!.bounds.size.height - 100, width: 120, height: 60)
        
        stopButton.addTarget(self, action: #selector(stopButtonPressed), for: .touchUpInside)
        
        self.view.addSubview(labelWithTimer)
        labelWithTimer.layer.cornerRadius = 20
        labelWithTimer.layer.masksToBounds = true
        labelWithTimer.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        labelWithTimer.frame = CGRect(x: UIScreen.screens.first!.bounds.size.width - 140, y: UIScreen.screens.first!.bounds.size.height - 100, width: 120, height: 60)
        labelWithTimer.textColor = .black
        labelWithTimer.textAlignment = .center
        
        self.view.addSubview(labelWithNumberOfTouches)
        labelWithNumberOfTouches.layer.cornerRadius = 20
        labelWithNumberOfTouches.layer.masksToBounds = true
        labelWithNumberOfTouches.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        labelWithNumberOfTouches.frame = CGRect(x: 20, y: 40, width: 120, height: 60)
        labelWithNumberOfTouches.textColor = .black
        labelWithNumberOfTouches.textAlignment = .center
        
        self.view.addSubview(viewOnTop)
        viewOnTop.backgroundColor = UIColor(red: 32.0/255.0, green: 206.0/255.0, blue: 136.0/255.0, alpha: 1.0)
        viewOnTop.frame = UIScreen.screens.first!.bounds
        
        viewOnTop.addSubview(startButton)
        startButton.setImage(UIImage(named: "start_button"), for: .normal)
        startButton.frame = CGRect(x: UIScreen.screens.first!.bounds.size.width / 2 - 100, y: UIScreen.screens.first!.bounds.size.height / 2 - 100, width: 200, height: 200)
        
        startButton.addTarget(self, action: #selector(startButtonPressed), for: .touchUpInside)
        
        runTimer()
    }
    
    func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self,   selector: (#selector(ViewController.updateTimer)), userInfo: nil, repeats: true)
    }
    
    @objc func updateTimer() {
        miliseconds = miliseconds + 1
        labelWithTimer.text = "\(miliseconds / 10).\(miliseconds % 10)"
        labelWithTimer.isHidden = false
        stopButton.isHidden = false
    }
    
    @objc func startButtonPressed() {
        viewOnTop.isHidden = true
        miliseconds = 0
        ballXCenterArray = [CGFloat]()
    }
    
    @objc func stopButtonPressed() {
        viewOnTop.isHidden = false
    }
    
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!
        
        // Select a video device, make an input
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .vga640x480 // Model image size is smaller.
        
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        let captureConnection = videoDataOutput.connection(with: .video)
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try  videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice!.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        rootLayer = previewView.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
    }
    
    func startCaptureSession() {
        session.startRunning()
    }
    
    // Clean up capture setup
    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
}


