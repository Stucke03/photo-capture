import SwiftUI
import AVFoundation
import Photos
import Combine

struct ContentView: View {
    @StateObject private var camera = CameraModel()
    @StateObject private var gesture = GestureDetector()
    @StateObject private var smile = SmileDetector()
    @State private var showCountdown = false
    @State private var countdownValue = 5
    @State private var timer: Timer?
    @State private var albumName = "464 Lab Data"
    @State private var showDashboard = false

    var body: some View {
        ZStack {
            if let image = camera.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            }

            if showCountdown {
                Text("\(countdownValue)")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
            }

            VStack {
                Spacer()

                if camera.capturedImage == nil {
                    HStack {
                        TextField("Album name", text: $albumName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                            .frame(maxWidth: 250)
                        Button("Use") { }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.6))
                            .cornerRadius(8)
                    }
                }

                HStack(spacing: 40) {
                    if camera.capturedImage == nil {
                        Button(action: {
                            camera.takePhoto {
                                camera.savePhotoToLibrary(albumName: albumName)
                            }
                        }) {
                            Text("Take Photo")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(12)
                        }

                        Button(action: { showDashboard = true }) {
                            Text("Dashboard")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .confirmationDialog("Dashboard", isPresented: $showDashboard, titleVisibility: .visible) {
            Button("Timer Photo") {
                if !showCountdown {
                    startCountdown()
                }
            }
            Button(gesture.enabled ? "Stop Gesture Photo" : "Gesture Photo") {
                gesture.enabled.toggle()
                showDashboard = false
            }
            Button(smile.enabled ? "Stop Smile Photo" : "Smile Photo") {
                smile.enabled.toggle()
                showDashboard = false
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            camera.checkPermissions()
            camera.forwardSampleBuffer = { buffer in
                if gesture.enabled {
                    gesture.process(sampleBuffer: buffer)
                }
                if smile.enabled {
                    smile.process(sampleBuffer: buffer)
                }
            }
        }
        .onReceive(gesture.gestureFire) { _ in
            if !showCountdown {
                startCountdown()
            }
        }
        .onReceive(smile.smileFire) { _ in
            if !showCountdown {
                startCountdown()
            }
        }
    }

    func startCountdown() {
        showCountdown = true
        countdownValue = 5
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if countdownValue > 1 {
                countdownValue -= 1
            } else {
                t.invalidate()
                showCountdown = false
                camera.takePhoto {
                    camera.savePhotoToLibrary(albumName: albumName)
                }
            }
        }
    }
}

final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?
    var forwardSampleBuffer: ((CMSampleBuffer) -> Void)?

    private let output = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var photoCompletion: (() -> Void)?

    override init() {
        super.init()
        setup()
    }

    func setup() {
        session.beginConfiguration()
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.queue"))
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        if let conn = videoOutput.connection(with: .video) {
            if conn.isVideoMirroringSupported { conn.isVideoMirrored = true }
        }
        session.commitConfiguration()
        session.startRunning()
    }

    func takePhoto(completion: @escaping () -> Void) {
        photoCompletion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async { self.setup() }
                }
            }
        default:
            break
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async {
            self.capturedImage = image
            self.photoCompletion?()
            self.photoCompletion = nil
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        forwardSampleBuffer?(sampleBuffer)
    }

    func savePhotoToLibrary(albumName: String) {
        guard let image = capturedImage else { return }
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else { return }
            self.saveImage(image, toAlbum: albumName)
        }
    }

    private func saveImage(_ image: UIImage, toAlbum albumName: String) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholder = request.placeholderForCreatedAsset
        }) { success, _ in
            guard success, let placeholder = placeholder else { return }
            var album: PHAssetCollection?
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
            let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            album = collection.firstObject
            if album == nil {
                var albumPlaceholder: PHObjectPlaceholder?
                PHPhotoLibrary.shared().performChanges({
                    let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                    albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
                }) { success, _ in
                    if success, let albumPlaceholder = albumPlaceholder {
                        let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumPlaceholder.localIdentifier], options: nil)
                        album = fetchResult.firstObject
                        if let album = album {
                            self.addAsset(with: placeholder.localIdentifier, to: album)
                        }
                    }
                }
            } else {
                self.addAsset(with: placeholder.localIdentifier, to: album!)
            }
            DispatchQueue.main.async {
                self.capturedImage = nil
            }
        }
    }

    private func addAsset(with localIdentifier: String, to album: PHAssetCollection) {
        PHPhotoLibrary.shared().performChanges({
            if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject {
                let request = PHAssetCollectionChangeRequest(for: album)
                request?.addAssets([asset] as NSArray)
            }
        }, completionHandler: { _, _ in })
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        previewLayer.connection?.automaticallyAdjustsVideoMirroring = false
        previewLayer.connection?.isVideoMirrored = true
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
