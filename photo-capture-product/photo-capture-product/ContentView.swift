import SwiftUI
import AVFoundation
internal import Combine

struct ContentView: View {
    @StateObject private var camera = CameraModel()
    @State private var showPreview = false

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                Spacer()

                if let image = camera.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(10)
                        .padding()
                }

                HStack(spacing: 30) {
                    Button("Take Photo") {
                        camera.capturePhoto()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("5s Timer") {
                        camera.startTimerCapture(seconds: 5)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .onAppear {
            camera.checkPermissions()
            camera.setupSession()
        }
    }
}

// MARK: - Camera Model
final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var capturedImage: UIImage?
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "cameraQueue")
    private var timer: Timer?

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        default: break
        }
    }

    func setupSession() {
        session.beginConfiguration()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input),
              session.canAddOutput(output)
        else { return }

        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()
        queue.async { self.session.startRunning() }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }

    func startTimerCapture(seconds: Int) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: false) { _ in
            self.capturePhoto()
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: data) else { return }
        DispatchQueue.main.async {
            self.capturedImage = uiImage
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
