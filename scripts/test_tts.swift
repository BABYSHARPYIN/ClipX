#!/usr/bin/env swift
import Foundation
import AVFoundation

final class TTSTester: NSObject, AVSpeechSynthesizerDelegate {
    let synthesizer = AVSpeechSynthesizer()
    private var pending = 0
    private let lock = NSLock()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
        }
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        let useChinese = containsChinese(text)
        let language = useChinese ? "zh-CN" : "en-US"
        guard let voice = AVSpeechSynthesisVoice(language: language)
            ?? AVSpeechSynthesisVoice(language: useChinese ? "zh-Hans" : "en-GB")
        else {
            fputs("FAIL: no voice for \(language)\n", stderr)
            exit(1)
        }
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95

        lock.lock()
        pending += 1
        lock.unlock()

        print("SPEAK [\(language)] voice=\(voice.name): \(text)")
        synthesizer.speak(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        lock.lock()
        pending -= 1
        let left = pending
        lock.unlock()
        print("DONE: \(utterance.speechString)")
        if left <= 0 {
            print("PASS: TTS finished all utterances")
            exit(0)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        fputs("FAIL: utterance cancelled\n", stderr)
        exit(1)
    }
}

let zhVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") }
let enVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
print("Available zh voices: \(zhVoices.count), en voices: \(enVoices.count)")
guard !zhVoices.isEmpty || !enVoices.isEmpty else {
    fputs("FAIL: no speech voices installed\n", stderr)
    exit(1)
}

let tester = TTSTester()
assert(tester.containsChinese("你好世界") == true)
assert(tester.containsChinese("Hello world") == false)
assert(tester.containsChinese("Hello 你好") == true)
print("PASS: language detection")

tester.speak("Hello from ClipX text to speech.")
tester.speak("你好，这是剪切板语音朗读测试。")

// Fail if speech never completes
DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
    fputs("FAIL: timed out waiting for TTS\n", stderr)
    exit(1)
}

RunLoop.main.run()
