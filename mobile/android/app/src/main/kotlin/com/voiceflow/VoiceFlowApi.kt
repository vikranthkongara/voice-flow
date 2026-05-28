package com.voiceflow

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

object VoiceFlowApi {
    private const val ENDPOINT = "https://YOUR_API_GATEWAY_URL/Prod/clean"

    suspend fun cleanTranscript(transcript: String): String = withContext(Dispatchers.IO) {
        if (transcript.isBlank()) return@withContext ""

        try {
            val url = URL(ENDPOINT)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.doOutput = true

            val body = JSONObject().apply {
                put("transcript", transcript)
            }
            conn.outputStream.use { it.write(body.toString().toByteArray()) }

            if (conn.responseCode == 200) {
                val response = conn.inputStream.bufferedReader().readText()
                val json = JSONObject(response)
                json.getString("cleaned")
            } else {
                transcript
            }
        } catch (e: Exception) {
            transcript
        }
    }
}
