package com.example.image_editor

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private data class SaveRequest(val bytes: ByteArray, val name: String, val result: MethodChannel.Result)
    private var pending: SaveRequest? = null
    private val permissionRequest = 7421

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "io.github.clcty.chromivelle/gallery")
            .setMethodCallHandler { call, result ->
                if (call.method != "savePng") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("name")
                if (bytes == null || bytes.isEmpty() || name == null || !name.matches(Regex("Chromivelle_[0-9]+\\.png"))) {
                    result.error("INVALID_IMAGE", "图片数据无效", null)
                    return@setMethodCallHandler
                }
                if (pending != null) {
                    result.error("BUSY", "正在保存另一张图片", null)
                    return@setMethodCallHandler
                }
                val request = SaveRequest(bytes, name, result)
                if (Build.VERSION.SDK_INT < 29 && checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                    pending = request
                    requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), permissionRequest)
                } else {
                    writeImage(request)
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequest) return
        val request = pending ?: return
        pending = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            writeImage(request)
        } else {
            request.result.error("PERMISSION_DENIED", "请允许保存图片到相册", null)
        }
    }

    private fun writeImage(request: SaveRequest) {
        Thread {
            var createdUri: Uri? = null
            var createdFile: File? = null
            try {
                if (Build.VERSION.SDK_INT >= 29) {
                    val values = ContentValues().apply {
                        put(MediaStore.Images.Media.DISPLAY_NAME, request.name)
                        put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                        put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Chromivelle")
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    }
                    val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                        ?: error("无法创建相册图片")
                    createdUri = uri
                    val stream = contentResolver.openOutputStream(uri) ?: error("无法写入相册")
                    stream.use { it.write(request.bytes) }
                    val published = contentResolver.update(uri, ContentValues().apply {
                        put(MediaStore.Images.Media.IS_PENDING, 0)
                    }, null, null)
                    check(published > 0) { "无法发布到相册" }
                    runOnUiThread { request.result.success(uri.toString()) }
                } else {
                    val directory = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "Chromivelle")
                    check(directory.isDirectory || directory.mkdirs()) { "无法创建相册目录" }
                    val file = File(directory, request.name)
                    check(file.createNewFile()) { "图片名称冲突，请重试" }
                    createdFile = file
                    file.outputStream().use { it.write(request.bytes) }
                    MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), arrayOf("image/png")) { _, uri ->
                        runOnUiThread { request.result.success((uri ?: Uri.fromFile(file)).toString()) }
                    }
                }
            } catch (e: Exception) {
                createdUri?.let { runCatching { contentResolver.delete(it, null, null) } }
                createdFile?.delete()
                runOnUiThread { request.result.error("SAVE_FAILED", e.message ?: "保存失败", null) }
            }
        }.start()
    }
}
