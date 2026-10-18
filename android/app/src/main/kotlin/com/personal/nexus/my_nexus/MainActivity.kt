package com.personal.nexus.my_nexus

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.personal.nexus.my_nexus/share"

    /** 공유로 받은 내용. text 또는 imagePath 중 하나가 채워진다. */
    private var pendingPayload: Map<String, String>? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractShared(intent)
        registerDirectShareShortcut()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)  // singleTask: 새 인텐트로 교체
        extractShared(intent)
        pendingPayload?.let {
            methodChannel?.invokeMethod("onSharedPayload", it)
            pendingPayload = null
        }
    }

    private fun extractShared(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        val type = intent.type ?: return
        if (type == "text/plain") {
            intent.getStringExtra(Intent.EXTRA_TEXT)?.let {
                pendingPayload = mapOf("text" to it)
            }
        } else if (type.startsWith("image/")) {
            val uri = streamUri(intent) ?: return
            copyToCache(uri)?.let { pendingPayload = mapOf("imagePath" to it) }
        }
    }

    @Suppress("DEPRECATION")
    private fun streamUri(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }

    /**
     * 공유받은 content:// 이미지는 보낸 앱이 준 임시 권한으로만 읽을 수 있다.
     * Flutter가 나중에 읽을 수 있도록 앱 캐시에 복사해 둔다.
     * (Dart 쪽이 압축·업로드를 마치면 이 파일을 지운다)
     */
    private fun copyToCache(uri: Uri): String? = try {
        val dir = File(cacheDir, "shared_images").apply { mkdirs() }
        val out = File(dir, "share_${System.currentTimeMillis()}")
        contentResolver.openInputStream(uri)?.use { input ->
            out.outputStream().use { input.copyTo(it) }
        }
        if (out.length() > 0) out.absolutePath else null
    } catch (_: Exception) {
        null
    }

    /** 공유 시트 상단 Direct Share 행에 MyNexus 등록 */
    private fun registerDirectShareShortcut() {
        try {
            val shortcut = ShortcutInfoCompat.Builder(this, "save_to_mynexus")
                .setShortLabel("DB허브 저장")
                .setLongLabel("MyNexus DB허브에 저장")
                .setIcon(IconCompat.createWithResource(this, R.mipmap.ic_launcher))
                .setIntent(Intent(Intent.ACTION_DEFAULT).setPackage(packageName))
                .setCategories(setOf("com.personal.nexus.my_nexus.SHARE_TARGET"))
                .setLongLived(true)
                .build()
            ShortcutManagerCompat.pushDynamicShortcut(this, shortcut)
        } catch (_: Exception) { }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedPayload" -> {
                    result.success(pendingPayload)
                    pendingPayload = null
                }
                else -> result.notImplemented()
            }
        }
    }
}
