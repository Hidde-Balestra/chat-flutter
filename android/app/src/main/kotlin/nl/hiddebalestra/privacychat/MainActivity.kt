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

    // TorController.start() is a one-shot no-op once tor is already
    // running (see its `running` guard), so it never re-fires onProgress/
    // onConnected for a *second* caller. Without replaying the last known
    // status to a freshly-attached listener, a new PlatformTorService
    // created after "lock now"/auto-lock (which drops the old Dart-side
    // instance but leaves this native controller and its already-running
    // tor process alone) would wait forever: its status never updates and
    // its socksPort future never completes, silently breaking networking
    // until the whole app process is killed and relaunched.
    private var lastStatus: Map<String, Any>? = null

    private fun emitStatus(status: Map<String, Any>) {
        lastStatus = status
        runOnUiThread { torEventSink?.success(status) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "privacychat/tor")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        torController.start(
                            onProgress = { percent ->
                                emitStatus(mapOf("state" to "connecting", "percent" to percent))
                            },
                            onConnected = {
                                emitStatus(
                                    mapOf("state" to "connected", "percent" to 100, "socksPort" to TorController.SOCKS_PORT)
                                )
                            },
                            onError = { message ->
                                emitStatus(mapOf("state" to "failed", "message" to message))
                            },
                        )
                        result.success(null)
                    }
                    "stop" -> {
                        torController.stop()
                        result.success(null)
                    }
                    "getCircuits" -> {
                        Thread {
                            try {
                                val circuits = torController.fetchCircuits()
                                runOnUiThread { result.success(circuits) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("tor_control_error", e.message, null)
                                }
                            }
                        }.apply { isDaemon = true }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "privacychat/tor/status")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    torEventSink = events
                    lastStatus?.let { events?.success(it) }
                }

                override fun onCancel(arguments: Any?) {
                    torEventSink = null
                }
            })
    }
}
