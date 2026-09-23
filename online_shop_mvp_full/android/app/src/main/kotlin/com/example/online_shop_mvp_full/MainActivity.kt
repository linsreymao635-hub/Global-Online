package com.example.online_shop_mvp_full

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val fingerprintChannel = "com.example.online_shop_mvp_full/fingerprint"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, fingerprintChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "signing_sha1") {
                    result.success(signingSha1Fingerprints())
                } else {
                    result.notImplemented()
                }
            }
    }

    /** SHA-1 certificate fingerprints of the certs that actually signed this
     *  installed APK — the exact value Google Cloud checks for this build. */
    private fun signingSha1Fingerprints(): List<String> {
        return try {
            val info = packageManager.getPackageInfo(
                packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            val certs = info.signingInfo?.apkContentsSigners ?: return emptyList()
            certs.map { cert ->
                val digest = MessageDigest.getInstance("SHA-1").digest(cert.toByteArray())
                digest.joinToString(":") { String.format("%02X", it) }
            }
        } catch (e: Exception) {
            emptyList()
        }
    }
}