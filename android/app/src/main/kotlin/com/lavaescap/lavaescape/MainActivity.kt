package com.lavaescap.lavaescape

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// ============================================================
// MainActivity — WebView file-upload bridge
// ============================================================
// Dependency-free WebView file upload path: the site's
// <input type="file"> triggers the WebView's file selector, which hops
// here over a MethodChannel, and the picked content:// URIs come back
// to the WebView as `List<String>`. No file_picker dependency (which
// would force pinning to 8.1.4 due to Kotlin-KGP conflicts — pitfalls §1).
//
// Channel name MUST match `_kUploadChannel` in
// `lib/lava/escape_view.dart`. Both strings are project-unique; rename
// them atomically if ever ported to a new project.
// ============================================================

class MainActivity : FlutterActivity() {
    private val channelId = "lavaEscape/attach"
    private val chooserRequestCode = 0x4C41 // "LA" — plausible unique short
    private var pendingReply: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelId)
            .setMethodCallHandler(::handleCall)
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "chooseFiles" -> {
                val multiple = call.argument<Boolean>("multiple") ?: false
                val mimes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                launchChooser(multiple, mimes, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun launchChooser(
        multiple: Boolean,
        mimes: List<String>,
        result: MethodChannel.Result,
    ) {
        // If a previous chooser is still pending, resolve it as
        // "nothing chosen" — otherwise Flutter would leak the completer.
        pendingReply?.success(emptyList<String>())
        pendingReply = result

        val cleaned = mimes.filter { it.contains("/") }
        val chooserIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            when {
                cleaned.isEmpty() -> type = "*/*"
                cleaned.size == 1 -> type = cleaned.first()
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, cleaned.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(
                Intent.createChooser(chooserIntent, null),
                chooserRequestCode,
            )
        } catch (_: Exception) {
            pendingReply = null
            result.success(emptyList<String>())
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != chooserRequestCode) return

        val reply = pendingReply ?: return
        pendingReply = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            reply.success(emptyList<String>())
            return
        }

        val urls = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                urls.add(clip.getItemAt(i).uri.toString())
            }
        } else {
            data.data?.let { urls.add(it.toString()) }
        }
        reply.success(urls)
    }
}
