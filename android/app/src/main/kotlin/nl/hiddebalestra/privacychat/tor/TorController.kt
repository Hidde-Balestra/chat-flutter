package nl.hiddebalestra.privacychat.tor

import android.content.Context
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Spawns and supervises the embedded `libtor.so` binary (from the
 * `org.briarproject:tor-android` artifact) as a plain child process, and
 * reports its bootstrap progress by reading its own notice-level log
 * output — the same "Bootstrapped NN%" lines `tor` has always printed.
 *
 * No control port is used: parsing stdout is simpler and avoids having to
 * implement the Tor control-protocol's cookie authentication, and it's
 * sufficient for "are we connected yet" purposes.
 */
class TorController(private val context: Context) {
    companion object {
        // A distinct high port, deliberately different from Orbot's
        // conventional 9050/9051, so a real Orbot install on the same
        // device can never collide with this app's own private instance.
        const val SOCKS_PORT = 19050

        private val BOOTSTRAP_REGEX = Regex("Bootstrapped (\\d+)%")
    }

    private val running = AtomicBoolean(false)
    private var process: Process? = null

    /**
     * Starts tor if it isn't already running. [onProgress] is called with
     * 0-100 as bootstrap advances; [onConnected] fires once, when it first
     * reaches 100; [onError] fires if the process can't be started at all
     * or exits before bootstrapping finished.
     */
    fun start(
        onProgress: (Int) -> Unit,
        onConnected: () -> Unit,
        onError: (String) -> Unit,
    ) {
        if (!running.compareAndSet(false, true)) {
            return
        }
        Thread {
            try {
                val dataDir = File(context.filesDir, "tor").apply { mkdirs() }
                val torrc = File(dataDir, "torrc").apply {
                    writeText(
                        """
                        SocksPort 127.0.0.1:$SOCKS_PORT
                        DataDirectory ${dataDir.absolutePath}
                        AvoidDiskWrites 1
                        DisableNetwork 0
                        ClientOnly 1
                        CookieAuthentication 0
                        """.trimIndent()
                    )
                }
                val binary = File(context.applicationInfo.nativeLibraryDir, "libtor.so")
                if (!binary.exists()) {
                    running.set(false)
                    onError("tor binary not found at ${binary.absolutePath}")
                    return@Thread
                }

                val proc = ProcessBuilder(binary.absolutePath, "-f", torrc.absolutePath)
                    .redirectErrorStream(true)
                    .directory(dataDir)
                    .start()
                process = proc

                var connected = false
                BufferedReader(InputStreamReader(proc.inputStream)).useLines { lines ->
                    for (line in lines) {
                        val match = BOOTSTRAP_REGEX.find(line) ?: continue
                        val percent = match.groupValues[1].toIntOrNull() ?: continue
                        onProgress(percent)
                        if (percent >= 100 && !connected) {
                            connected = true
                            onConnected()
                        }
                    }
                }

                // The process' stdout closed — tor exited. If that happened
                // before it ever bootstrapped, surface it as an error so the
                // Dart side can show something other than a stuck spinner.
                running.set(false)
                if (!connected) {
                    onError("tor exited before connecting (code ${proc.waitFor()})")
                }
            } catch (e: Exception) {
                running.set(false)
                onError(e.message ?: e.toString())
            }
        }.apply { isDaemon = true }.start()
    }

    fun stop() {
        process?.destroy()
        process = null
        running.set(false)
    }
}
