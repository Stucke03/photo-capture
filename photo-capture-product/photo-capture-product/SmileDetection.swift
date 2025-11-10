//import UIKit
import Foundation
import AVFoundation
import Vision
import Combine
import CoreGraphics

final class SmileDetector: ObservableObject {
    @Published var enabled = false
    let smileFire = PassthroughSubject<Void, Never>()

    private let faceLandmarksRequest = VNDetectFaceLandmarksRequest()
    private var consecutive = 0
    private var lastFire = Date.distantPast

    func process(sampleBuffer: CMSampleBuffer) {
        if !enabled {
            DispatchQueue.main.async { self.consecutive = 0 }
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

      
        do {
            try requestHandler.perform([faceLandmarksRequest])
            guard let results = faceLandmarksRequest.results, !results.isEmpty else {
                DispatchQueue.main.async { self.consecutive = 0 }
                return
            }
            var detected = false

            //tested - face detected 
            for face in results {
                guard let landmarks = face.landmarks,
                    let mouthPoints = landmarks.outerLips?.normalizedPoints else {return}
                
                let leftCorner = mouthPoints.first!
                let rightCorner = mouthPoints.last!
                let upper = mouthPoints[mouthPoints.count/3]
                let lower = mouthPoints[2 * mouthPoints.count/3]

                let width = abs(rightCorner.x - leftCorner.x)
                let height = abs(lower.y - upper.y)
                let mouthAspectRatio = height / width

                if mouthAspectRation > 1.5 {
                    detected = true
                    break
                }
            }

            DispatchQueue.main.async {
                if detected {
                    self.consecutive += 1
                    if self.consecutive >= 6 && Date().timeIntervalSince(self.lastFire) > 3 {
                        self.lastFire = Date()
                        self.smileFire.send(())
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

