package com.example.filezoor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.net.Uri
import java.io.InputStream
class MainActivity: FlutterActivity() {
  private val CHANNEL = "com.example.filezoor/content_resolver"
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      if (call.method == "openInputStream") {
        val uriString = call.argument<String>("uri")
        if (uriString != null) {
          try {
            val uri = Uri.parse(uriString)
            val inputStream = contentResolver.openInputStream(uri)
            if (inputStream != null) {
              val bytes = inputStream.readBytes()
              inputStream.close()
              result.success(bytes)
            } else {
              result.error("URI_NULL", "Impossible d'ouvrir l'InputStream", null)
            }
          } catch (e: Exception) {
            result.error("ERROR", e.toString(), null)
          }
        } else {
          result.error("INVALID_URI", "URI non fourni", null)
        }
      } else {
        result.notImplemented()
      }
    }
  }
}