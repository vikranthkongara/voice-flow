package com.voiceflow.keyboard

import android.content.Intent
import android.inputmethodservice.InputMethodService
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.widget.ImageButton
import android.widget.TextView
import com.voiceflow.VoiceFlowApi
import kotlinx.coroutines.*

class VoiceFlowIME : InputMethodService() {
    private var speechRecognizer: SpeechRecognizer? = null
    private var transcript = ""
    private var micButton: ImageButton? = null
    private var statusText: TextView? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onCreateInputView(): View {
        val view = LayoutInflater.from(this).inflate(
            resources.getIdentifier("keyboard_view", "layout", packageName), null
        )

        micButton = view.findViewById(resources.getIdentifier("mic_button", "id", packageName))
        statusText = view.findViewById(resources.getIdentifier("status_text", "id", packageName))

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(createListener())
        }

        micButton?.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startListening()
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    stopListening()
                    true
                }
                else -> false
            }
        }

        return view
    }

    private fun startListening() {
        transcript = ""
        statusText?.text = "Listening..."

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-US")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        }
        speechRecognizer?.startListening(intent)
    }

    private fun stopListening() {
        speechRecognizer?.stopListening()
        if (transcript.isNotBlank()) {
            statusText?.text = "Cleaning..."
            scope.launch {
                val cleaned = VoiceFlowApi.cleanTranscript(transcript)
                currentInputConnection?.commitText(cleaned, 1)
                statusText?.text = "Hold mic to speak"
            }
        } else {
            statusText?.text = "Hold mic to speak"
        }
    }

    private fun createListener() = object : RecognitionListener {
        override fun onResults(results: Bundle?) {
            results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.let {
                transcript = it
            }
        }
        override fun onPartialResults(partialResults: Bundle?) {
            partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()?.let {
                transcript = it
                statusText?.text = it
            }
        }
        override fun onError(error: Int) {}
        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: Bundle?) {}
    }

    override fun onDestroy() {
        scope.cancel()
        speechRecognizer?.destroy()
        super.onDestroy()
    }
}
