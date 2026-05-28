import UIKit
import Speech
import AVFoundation

class KeyboardViewController: UIInputViewController {
    private var micButton: UIButton!
    private var statusLabel: UILabel!
    private var isRecording = false
    private var audioEngine = AVAudioEngine()
    private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var rawTranscript = ""

    private let apiEndpoint = "https://YOUR_API_GATEWAY_URL/Prod/clean"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        // Mic button
        micButton = UIButton(type: .system)
        micButton.setImage(UIImage(systemName: "mic.circle.fill"), for: .normal)
        micButton.tintColor = .systemPurple
        micButton.transform = CGAffineTransform(scaleX: 2.0, y: 2.0)
        micButton.addTarget(self, action: #selector(micPressed), for: .touchDown)
        micButton.addTarget(self, action: #selector(micReleased), for: [.touchUpInside, .touchUpOutside])
        stack.addArrangedSubview(micButton)

        // Status label
        statusLabel = UILabel()
        statusLabel.text = "Hold mic to speak"
        statusLabel.textColor = .secondaryLabel
        statusLabel.font = .systemFont(ofSize: 14)
        stack.addArrangedSubview(statusLabel)

        // Next keyboard button
        let nextKB = UIButton(type: .system)
        nextKB.setImage(UIImage(systemName: "globe"), for: .normal)
        nextKB.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        stack.addArrangedSubview(nextKB)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            view.heightAnchor.constraint(equalToConstant: 80),
        ])
    }

    @objc private func micPressed() {
        startRecording()
    }

    @objc private func micReleased() {
        stopRecording()
    }

    private func startRecording() {
        guard !isRecording else { return }
        rawTranscript = ""

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement)
        try? audioSession.setActive(true)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            if let result = result {
                self?.rawTranscript = result.bestTranscription.formattedString
                self?.statusLabel.text = self?.rawTranscript
            }
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isRecording = true
        micButton.tintColor = .systemRed
        statusLabel.text = "Listening..."
    }

    private func stopRecording() {
        guard isRecording else { return }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isRecording = false
        micButton.tintColor = .systemPurple

        guard !rawTranscript.isEmpty else {
            statusLabel.text = "Hold mic to speak"
            return
        }

        statusLabel.text = "Cleaning up..."
        sendToBackend(transcript: rawTranscript)
    }

    private func sendToBackend(transcript: String) {
        guard let url = URL(string: apiEndpoint) else {
            insertText(transcript)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["transcript": transcript])

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let cleaned = json["cleaned"] as? String else {
                    self?.insertText(transcript)
                    return
                }
                self?.insertText(cleaned)
            }
        }.resume()
    }

    private func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
        statusLabel.text = "Hold mic to speak"
    }
}
