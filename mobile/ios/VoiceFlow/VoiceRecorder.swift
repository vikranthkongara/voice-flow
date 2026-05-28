import Foundation
import AVFoundation
import Speech

class VoiceRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var cleanedText = ""

    private var audioEngine = AVAudioEngine()
    private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var rawTranscript = ""

    private let apiEndpoint: String = {
        Bundle.main.object(forInfoDictionaryKey: "VOICE_FLOW_API_ENDPOINT") as? String
            ?? "https://YOUR_API_GATEWAY_URL/Prod/clean"
    }()

    init() {
        requestPermissions()
    }

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioApplication.requestRecordPermission { _ in }
    }

    func startRecording() {
        guard !isRecording else { return }

        rawTranscript = ""
        cleanedText = ""

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                self?.rawTranscript = result.bestTranscription.formattedString
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isRecording = true
    }

    func stopRecording() {
        guard isRecording else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isRecording = false

        guard !rawTranscript.isEmpty else { return }
        sendToBackend(transcript: rawTranscript)
    }

    private func sendToBackend(transcript: String) {
        isProcessing = true

        guard let url = URL(string: apiEndpoint) else {
            isProcessing = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["transcript": transcript])

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isProcessing = false

                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let cleaned = json["cleaned"] as? String else {
                    self?.cleanedText = transcript
                    return
                }
                self?.cleanedText = cleaned
                UIPasteboard.general.string = cleaned
            }
        }.resume()
    }
}
