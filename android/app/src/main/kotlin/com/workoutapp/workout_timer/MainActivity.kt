package com.workoutapp.workout_timer

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.workoutapp.workout_timer/app_launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchApp" -> {
                    val packageName = call.argument<String>("package")
                    if (packageName != null) {
                        try {
                            var launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                            if (launchIntent == null) {
                                val intent = Intent(Intent.ACTION_MAIN).apply {
                                    addCategory(Intent.CATEGORY_LAUNCHER)
                                    setPackage(packageName)
                                }
                                val resolve = packageManager.queryIntentActivities(intent, 0)
                                if (resolve.isNotEmpty()) {
                                    val activity = resolve[0].activityInfo
                                    intent.setClassName(activity.packageName, activity.name)
                                    launchIntent = intent
                                }
                            }
                            if (launchIntent != null) {
                                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(launchIntent)
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.error("LAUNCH_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is null", null)
                    }
                }
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("package")
                    if (packageName != null) {
                        try {
                            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                            result.success(launchIntent != null)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                "launchMusicPlayer" -> {
                    try {
                        val intent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_APP_MUSIC)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        if (intent.resolveActivity(packageManager) != null) {
                            startActivity(intent)
                            result.success(true)
                        } else {
                            val fallback = Intent(android.provider.MediaStore.INTENT_ACTION_MUSIC_PLAYER).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallback)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("LAUNCH_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
