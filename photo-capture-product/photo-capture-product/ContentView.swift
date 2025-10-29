import SwiftUI
import AVFoundation
import Photos
import Combine

struct ContentView: View {
    @StateObject private var camera = CameraModel()
    @State private var showCountdown = false
    @State private var countdownValue = 5
    @State private var timer: Timer?
    @State private var showSaveAlert = false
    @State private var albumName = "My Custom Album" // Default album name

    var body: some View {
        ZStack {
            // Camera preview or captured image
            if let image = camera.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            }

            // Countdown overlay
            if showCountdown {
                Text("\(countdownValue)")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
            }

            VStack {
                Spacer()

                // Album name entry field
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
                                showSaveAlert = true
                            }
                        }) {
                            Text("Take Photo")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(12)
                        }

                        Button(action: startCountdown) {
                            Text("Timer Photo")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: { camera.capturedImage = nil }) {
                            Text("Retake")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red.opacity(0.8))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .alert(isPresented: $showSaveAlert) {
            Alert(
                title: Text("Save Photo?"),
                message: Text("Do you want to keep this photo and save it to your library?"),
                primaryButton: .default(Text("Save")) {
                    camera.savePhotoToLibrary(albumName: albumName)
                },
                secondaryButton: .cancel(Text("Retake")) {
                    camera.capturedImage = nil
                }
            )
        }
        .onAppear {
            camera.checkPermissions()
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
                    showSaveAlert = true
                }
            }
        }
    }
}

final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?

    private let output = AVCapturePhotoOutput()
    private var photoCompletion: (() -> Void)?

    override init() {
        super.init()
        setup()
    }

    func setup() {
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
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
            print("Camera access denied or restricted.")
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else { return }

        DispatchQueue.main.async {
            self.capturedImage = image
            self.photoCompletion?()
        }
    }

    // MARK: - Album Saving

    func savePhotoToLibrary(albumName: String) {
        guard let image = capturedImage else { return }

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                print("Photo library access not granted.")
                return
            }

            self.saveImage(image, toAlbum: albumName)
        }
    }

    private func saveImage(_ image: UIImage, toAlbum albumName: String) {
        var placeholder: PHObjectPlaceholder?

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholder = request.placeholderForCreatedAsset
        }) { success, error in
            guard success, let placeholder = placeholder else {
                print("Error saving photo: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

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
                }) { success, error in
                    if success, let albumPlaceholder = albumPlaceholder {
                        let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumPlaceholder.localIdentifier], options: nil)
                        album = fetchResult.firstObject
                        if let album = album {
                            self.addAsset(with: placeholder.localIdentifier, to: album)
                        }
                    } else {
                        print("Error creating album: \(error?.localizedDescription ?? "Unknown error")")
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
        }, completionHandler: { success, error in
            if success {
                print("Photo added to album successfully.")
            } else {
                print("Failed to add photo to album: \(error?.localizedDescription ?? "Unknown error")")
            }
        })
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Nothing to update dynamically
    }
}
