package nl.hiddebalestra.privacychat

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import nl.hiddebalestra.privacychat.tor.TorController

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth
// for the biometric prompt to work on Android.
class MainActivity : FlutterFragmentActivity() {
    private val torController by lazy { TorController(applicationContext) }
    private var torEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "privacychat/tor")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        torController.start(
                            onProgress = { percent ->
                                runOnUiThread {
                                    torEventSink?.success(mapOf("state" to "connecting", "percent" to percent))
                                }
                            },
                            onConnected = {
                                runOnUiThread {
                                    torEventSink?.success(
                                        mapOf("state" to "connected", "percent" to 100, "socksPort" to TorController.SOCKS_PORT)
                                    )
                                }
                            },
                            onError = { message ->
                                runOnUiThread {
                                    torEventSink?.success(mapOf("state" to "failed", "message" to message))
                                }
                            },
                        )
                        result.success(null)
                    }
                    "stop" -> {
                        torController.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "privacychat/tor/status")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    torEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    torEventSink = null
                }
            })
    }
}
