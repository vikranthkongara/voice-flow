import SwiftUI
import AVFoundation
import Speech

struct ContentView: View {
    @StateObject private var recorder = VoiceRecorder()

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(recorder.isRecording ? .red : .purple)
                .animation(.easeInOut, value: recorder.isRecording)

            Text(recorder.isRecording ? "Recording..." : "Hold to speak")
                .font(.title2)
                .foregroundColor(.secondary)

            if !recorder.cleanedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Result:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(recorder.cleanedText)
                        .font(.body)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Button("Copy to Clipboard") {
                    UIPasteboard.general.string = recorder.cleanedText
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }

            if recorder.isProcessing {
                ProgressView("Cleaning up...")
            }

            Spacer()
        }
        .padding(.top, 60)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !recorder.isRecording {
                        recorder.startRecording()
                    }
                }
                .onEnded { _ in
                    recorder.stopRecording()
                }
        )
    }
}
