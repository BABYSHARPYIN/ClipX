import Foundation
import Vision
import AppKit

final class OCRService {
    static let shared = OCRService()

    private let cache = NSCache<NSURL, NSString>()

    private init() {
        cache.countLimit = 50
    }

    func recognizeText(from imageURL: URL, completion: @escaping (String?) -> Void) {
        if let cached = cache.object(forKey: imageURL as NSURL) {
            completion(cached as String)
            return
        }

        guard let nsImage = NSImage(contentsOf: imageURL),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            completion(nil)
            return
        }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation]
            else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let text = observations.compactMap { obs in
                obs.topCandidates(1).first?.string
            }.joined(separator: "\n")

            if !text.isEmpty {
                self?.cache.setObject(text as NSString, forKey: imageURL as NSURL)
            }

            DispatchQueue.main.async {
                completion(text.isEmpty ? nil : text)
            }
        }

        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}
