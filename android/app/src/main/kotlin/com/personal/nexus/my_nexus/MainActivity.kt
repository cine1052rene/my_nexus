package com.personal.nexus.my_nexus

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.personal.nexus.my_nexus/share"
    private var pendingSharedText: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractSharedText(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        extractSharedText(intent)
        // 앱이 이미 실행 중일 때 Flutter로 즉시 전달
        pendingSharedText?.let {
            methodChannel?.invokeMethod("onSharedText", it)
            pendingSharedText = null
        }
    }

    private fun extractSharedText(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            pendingSharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedText" -> {
                    result.success(pendingSharedText)
                    pendingSharedText = null
                }
                else -> result.notImplemented()
            }
        }
    }
}
