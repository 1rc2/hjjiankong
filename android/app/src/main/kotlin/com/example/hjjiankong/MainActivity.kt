package com.example.hjjiankong

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 主 Activity
 *
 * 提供原生能力给 Flutter 侧（MethodChannel: com.example.hjjiankong/install）：
 * - canRequestInstall：是否已允许安装未知来源应用
 * - openInstallSettings：跳转系统「允许安装未知应用」设置页
 * - installApk：用系统安装器安装 APK（FileProvider 生成 content:// URI）
 * - requestNotificationPermission：Android 13+ 申请通知权限
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.example.hjjiankong/install"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canRequestInstall" -> {
                        result.success(canRequestInstallPackages())
                    }
                    "openInstallSettings" -> {
                        openInstallSettings()
                        result.success(null)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("NO_PATH", "apk path is null", null)
                        } else {
                            result.success(installApk(File(path)))
                        }
                    }
                    "requestNotificationPermission" -> {
                        requestNotificationPermission()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** 是否已允许安装未知来源应用（Android 8+ 才需要，旧版本直接放行） */
    private fun canRequestInstallPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    /** 跳转系统「允许安装未知应用」设置页 */
    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                .setData(Uri.parse("package:$packageName"))
            startActivity(intent)
        }
    }

    /** Android 13+ 申请通知权限（下载进度通知需要，拒绝不影响下载） */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001)
            }
        }
    }

    /** 使用系统安装器安装 APK */
    private fun installApk(file: File): Boolean {
        if (!file.exists()) return false
        // FileProvider 生成 content:// URI，避免 Android 7+ 的 FileUriExposedException
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
        return true
    }
}
