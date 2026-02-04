package com.ntwritecode.flowcontroller

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val VOLUME_CHANNEL = "com.ntwritecode.flowcontroller/volume"
    private val VOLUME_EVENT_CHANNEL = "com.ntwritecode.flowcontroller/volume_events"
    private var volumeButtonEnabled = false
    private var volumeEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Method channel for enabling/disabling volume button interception
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableVolumeButtons" -> {
                    volumeButtonEnabled = true
                    result.success(true)
                }
                "disableVolumeButtons" -> {
                    volumeButtonEnabled = false
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Event channel for streaming volume button events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    volumeEventSink = null
                }
            }
        )
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (volumeButtonEnabled) {
            when (keyCode) {
                KeyEvent.KEYCODE_VOLUME_UP -> {
                    volumeEventSink?.success("volume_up")
                    return true  // Consume the event
                }
                KeyEvent.KEYCODE_VOLUME_DOWN -> {
                    volumeEventSink?.success("volume_down")
                    return true  // Consume the event
                }
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}
