import UIKit
import AVFoundation
import MediaPlayer

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {
    var captureSession: AVCaptureSession!
    var videoOutput: AVCaptureMovieFileOutput!
    var blackOverlay: UIView!
    var originalBrightness: CGFloat = 0.5
    var volumeChangeCount = 0
    var volumeTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupStealthUI()
        setupCamera(mode: "zoom05") 
        setupVolumeListener()
    }
    
    func setupStealthUI() {
        originalBrightness = UIScreen.main.brightness
        UIScreen.main.brightness = 0.0
        blackOverlay = UIView(frame: self.view.bounds)
        blackOverlay.backgroundColor = .black
        blackOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(blackOverlay)
    }
    
    func setupCamera(mode: String) {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let device = getCameraDevice(for: mode),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        
        videoOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
        
        do {
            try device.lockForConfiguration()
            if mode == "cam12" {
                device.videoZoomFactor = 1.2
            } else if mode.contains("slomo") {
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 120)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 120)
            }
            device.unlockForConfiguration()
        } catch { print("Lỗi cấu hình camera") }
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
            self.startRecording()
        }
    }
    
    func getCameraDevice(for mode: String) -> AVCaptureDevice? {
        let deviceType: AVCaptureDevice.DeviceType = (mode.contains("05")) ? .builtInUltraWideCamera : .builtInWideAngleCamera
        return AVCaptureDevice.default(deviceType, for: .video, position: .back)
    }
    
    func startRecording() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
    }
    
    func setupVolumeListener() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(true)
        audioSession.addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            volumeChangeCount += 1
            volumeTimer?.invalidate()
            
            if volumeChangeCount >= 2 {
                restoreNormalMode()
                volumeChangeCount = 0
            } else {
                volumeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                    self.volumeChangeCount = 0
                }
            }
        }
    }
    
    func restoreNormalMode() {
        DispatchQueue.main.async {
            UIScreen.main.brightness = self.originalBrightness
            self.blackOverlay.removeFromSuperview()
            self.videoOutput.stopRecording()
            self.captureSession.stopRunning()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        UISaveVideoAtPathToSavedPhotosAlbum(outputFileURL.path, nil, nil, nil)
    }
}
