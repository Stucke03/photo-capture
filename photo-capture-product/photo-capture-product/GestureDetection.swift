import Foundation
import AVFoundation
import Vision
import Combine
import CoreGraphics

final class GestureDetector: ObservableObject {
    @Published var enabled = false
    let gestureFire = PassthroughSubject<Void, Never>()

    private let handRequest = VNDetectHumanHandPoseRequest()
    private var consecutive = 0
    private var lastFire = Date.distantPast

    func process(sampleBuffer: CMSampleBuffer) {
        if !enabled {
            DispatchQueue.main.async { self.consecutive = 0 }
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([handRequest])
            guard let observations = handRequest.results, !observations.isEmpty else {
                DispatchQueue.main.async { self.consecutive = 0 }
                return
            }

            var detected = false

            for obs in observations {
                guard let dict = try? obs.recognizedPoints(.all) else { continue }
                func y(_ n: VNHumanHandPoseObservation.JointName) -> CGFloat? {
                    guard let p = dict[n], p.confidence > 0.3 else { return nil }
                    return p.location.y
                }
                let iTip = y(.indexTip) ?? 0
                let iPIP = y(.indexPIP) ?? 1
                let mTip = y(.middleTip) ?? 0
                let mPIP = y(.middlePIP) ?? 1
                let rTip = y(.ringTip) ?? 1
                let pTip = y(.littleTip) ?? 1

                let indexUp = iTip > iPIP
                let middleUp = mTip > mPIP
                let ringDown = rTip < 0.5
                let pinkyDown = pTip < 0.5

                if indexUp && middleUp && ringDown && pinkyDown {
                    detected = true
                    break
                }
            }

            DispatchQueue.main.async {
                if detected {
                    self.consecutive += 1
                    if self.consecutive >= 6 && Date().timeIntervalSince(self.lastFire) > 3 {
                        self.lastFire = Date()
                        self.gestureFire.send(())
                        self.consecutive = 0
                    }
                } else {
                    self.consecutive = 0
                }
            }
        } catch {
            DispatchQueue.main.async { self.consecutive = 0 }
        }
    }
}
