package org.brianiplayer.app

import android.app.UiModeManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var bridge: MethodChannel? = null
    private var audio: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null
    private var externalPending = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audio = getSystemService(AUDIO_SERVICE) as AudioManager
        bridge = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.brianiplayer.app/platform")
        val listener = AudioManager.OnAudioFocusChangeListener { event ->
            bridge?.invokeMethod("audioFocus", when (event) {
                AudioManager.AUDIOFOCUS_GAIN -> "gain"
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> "duck"
                else -> "loss"
            })
        }
        focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE).build())
            .setAcceptsDelayedFocusGain(false).setWillPauseWhenDucked(true)
            .setOnAudioFocusChangeListener(listener, Handler(Looper.getMainLooper())).build()
        bridge?.setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> result.success(mapOf("television" to
                    ((getSystemService(UI_MODE_SERVICE) as UiModeManager).currentModeType == Configuration.UI_MODE_TYPE_TELEVISION),
                    "sdk" to Build.VERSION.SDK_INT, "abis" to Build.SUPPORTED_ABIS.toList()))
                "requestAudioFocus" -> result.success(audio?.requestAudioFocus(focusRequest!!) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
                "abandonAudioFocus" -> { audio?.abandonAudioFocusRequest(focusRequest!!); result.success(null) }
                "videoHandlers", "launchVideo" -> video(call, result)
                else -> result.notImplemented()
            }
        }
    }
    private fun video(call: MethodCall, result: MethodChannel.Result) {
        val value = call.argument<String>("url")
        val mime = call.argument<String>("mime")
        val uri = value?.let { Uri.parse(it) }
        val parts = uri?.pathSegments
        if (value == null || value.length > 4096 || value.any { it.code < 32 || it.code == 127 } ||
            uri == null || uri.scheme !in listOf("http", "https") || uri.host.isNullOrEmpty() ||
            uri.userInfo != null || uri.query != null || uri.fragment != null || parts == null ||
            parts.size != 3 || parts[0] != "stream" || !parts[1].matches(Regex("[A-Za-z0-9_-]{43}")) ||
            parts[2].isEmpty() || parts[2].length > 512 || parts[2].any { it.code < 32 || it.code == 127 } || parts[2].contains('/') || mime == null || !mime.matches(Regex("video/[A-Za-z0-9.+-]{1,64}"))) {
            result.error("invalid_media", "Invalid scoped video request.", null); return
        }
        val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri, mime)
        @Suppress("DEPRECATION")
        val handlers = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
        if (call.method == "videoHandlers") {
            result.success(handlers.take(32).map { mapOf("name" to it.loadLabel(packageManager).toString().take(128),
                "package" to it.activityInfo.packageName) }.distinctBy { it["package"] }); return
        }
        if (handlers.isEmpty()) { result.error("no_handler", "No compatible video player is installed.", null); return }
        val preferred = call.argument<String>("package")
        if (preferred != null) {
            if (preferred.length > 256 || !preferred.matches(Regex("[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+")) ||
                handlers.none { it.activityInfo.packageName == preferred }) {
                result.error("preferred_unavailable", "The preferred player is unavailable. Choose another player.", null); return
            }
            intent.setPackage(preferred)
        }
        try {
            externalPending = true
            startActivity(if (preferred == null) Intent.createChooser(intent, "Play with") else intent)
            result.success(null)
        } catch (_: ActivityNotFoundException) {
            externalPending = false; result.error("no_handler", "No compatible video player is installed.", null)
        } catch (_: SecurityException) {
            externalPending = false; result.error("launch_denied", "The selected player could not be opened.", null)
        }
    }
    override fun onResume() {
        super.onResume()
        if (externalPending) { externalPending = false; bridge?.invokeMethod("externalReturned", null) }
    }
    override fun onDestroy() {
        focusRequest?.let { audio?.abandonAudioFocusRequest(it) }
        bridge?.setMethodCallHandler(null); bridge = null
        super.onDestroy()
    }
}
