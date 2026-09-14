package nl.hiddebalestra.privacychat.tor

import android.content.Context
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.io.OutputStream
import java.net.Socket
import java.util.concurrent.atomic.AtomicBoolean

class TorControlException(message: String) : Exception(message)

/**
 * Spawns and supervises the embedded `libtor.so` binary (from the
 * `org.briarproject:tor-android` artifact) as a plain child process, and
 * reports its bootstrap progress by reading its own notice-level log
 * output — the same "Bootstrapped NN%" lines `tor` has always printed.
 *
 * A local control port (cookie-authenticated) is also opened, used only for
 * [fetchCircuits] — a one-off, on-demand query for the "which relays am I
 * using" screen, not for bootstrap tracking (stdout parsing already covers
 * that, and is simpler).
 */
class TorController(private val context: Context) {
    companion object {
        // Distinct high ports, deliberately different from Orbot's
        // conventional 9050/9051, so a real Orbot install on the same
        // device can never collide with this app's own private instance.
        const val SOCKS_PORT = 19050
        const val CONTROL_PORT = 19051

        private val BOOTSTRAP_REGEX = Regex("Bootstrapped (\\d+)%")
    }

    private val running = AtomicBoolean(false)
    private var process: Process? = null
    private val dataDir by lazy { File(context.filesDir, "tor") }

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
                dataDir.mkdirs()
                val torrc = File(dataDir, "torrc").apply {
                    writeText(
                        """
                        SocksPort 127.0.0.1:$SOCKS_PORT
                        ControlPort 127.0.0.1:$CONTROL_PORT
                        CookieAuthentication 1
                        DataDirectory ${dataDir.absolutePath}
                        AvoidDiskWrites 1
                        DisableNetwork 0
                        ClientOnly 1
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

    /**
     * Queries tor's control port for the currently-built, general-purpose
     * circuits (the ones actual app traffic uses), resolving each hop's
     * nickname and address from the consensus. Blocking — call off the
     * main thread. Throws on any failure (control port not up yet, auth
     * rejected, connection refused, etc); the caller decides how to
     * surface that.
     */
    fun fetchCircuits(): List<Map<String, Any>> {
        val cookieFile = File(dataDir, "control_auth_cookie")
        val cookieHex = cookieFile.readBytes().joinToString("") { "%02X".format(it) }

        Socket("127.0.0.1", CONTROL_PORT).use { socket ->
            val out = socket.getOutputStream()
            val reader = BufferedReader(InputStreamReader(socket.getInputStream()))

            sendCommand(out, reader, "AUTHENTICATE $cookieHex")

            val circuitLines = sendCommand(out, reader, "GETINFO circuit-status")
            val circuits = mutableListOf<Map<String, Any>>()

            for (line in circuitLines) {
                val parts = line.split(" ")
                if (parts.size < 3 || parts[1] != "BUILT") continue
                val purpose = parts.drop(2).find { it.startsWith("PURPOSE=") }
                if (purpose != "PURPOSE=GENERAL") continue

                val hops = parts[2].split(",").map { hop ->
                    val fpAndNick = hop.removePrefix("$")
                    val sepIndex = fpAndNick.indexOfFirst { it == '=' || it == '~' }
                    val fingerprint =
                        if (sepIndex >= 0) fpAndNick.substring(0, sepIndex) else fpAndNick
                    val nickname =
                        if (sepIndex >= 0) fpAndNick.substring(sepIndex + 1) else ""
                    resolveHop(out, reader, fingerprint, nickname)
                }
                circuits.add(mapOf("id" to parts[0], "hops" to hops))
            }
            return circuits
        }
    }

    private fun resolveHop(
        out: OutputStream,
        reader: BufferedReader,
        fingerprint: String,
        nickname: String,
    ): Map<String, Any> {
        var ip = ""
        var orPort = 0
        try {
            val nsLines = sendCommand(out, reader, "GETINFO ns/id/$fingerprint")
            val routerLine = nsLines.firstOrNull { it.startsWith("r ") }
            val fields = routerLine?.split(" ")
            // "r Nickname IDBase64 DigestBase64 Date Time IP ORPort DirPort"
            if (fields != null && fields.size >= 8) {
                ip = fields[6]
                orPort = fields[7].toIntOrNull() ?: 0
            }
        } catch (_: Exception) {
            // Relay not (yet) in the local consensus cache — show what we
            // have (nickname/fingerprint) without an address.
        }
        return mapOf(
            "fingerprint" to fingerprint,
            "nickname" to nickname,
            "ip" to ip,
            "orPort" to orPort,
        )
    }

    /**
     * A minimal Tor control-protocol client: sends [command], reads back
     * its reply (handling both plain and "+"-prefixed multi-line data
     * blocks terminated by a lone "."), and returns the reply's content
     * lines with their status-code prefixes stripped. Throws
     * [TorControlException] if the final status code isn't 2xx.
     */
    private fun sendCommand(
        out: OutputStream,
        reader: BufferedReader,
        command: String,
    ): List<String> {
        out.write((command + "\r\n").toByteArray(Charsets.UTF_8))
        out.flush()

        val lines = mutableListOf<String>()
        var lastCode = "500"
        while (true) {
            val line = reader.readLine() ?: throw TorControlException("control connection closed")
            if (line.length < 4) continue
            lastCode = line.substring(0, 3)
            val rest = line.substring(4)
            when (line[3]) {
                '+' -> {
                    lines.add(rest)
                    while (true) {
                        val dataLine =
                            reader.readLine() ?: throw TorControlException("control connection closed")
                        if (dataLine == ".") break
                        lines.add(dataLine)
                    }
                }
                '-' -> lines.add(rest)
                ' ' -> {
                    lines.add(rest)
                    break
                }
                else -> lines.add(line)
            }
        }
        if (!lastCode.startsWith("2")) {
            throw TorControlException("tor control error $lastCode: ${lines.lastOrNull()}")
        }
        return lines
    }
}
