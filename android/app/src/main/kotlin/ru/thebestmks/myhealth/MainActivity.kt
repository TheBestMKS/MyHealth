package ru.thebestmks.myhealth

import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ru.thebestmks.myhealth/bundled_assets",
        ).setMethodCallHandler { call, result ->
            if (call.method != "installBundledModel") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val modelAsset = call.argument<String>("modelAsset")
            val projectorAsset = call.argument<String>("projectorAsset")
            val modelPath = call.argument<String>("modelPath")
            val projectorPath = call.argument<String>("projectorPath")
            val modelSize = call.argument<Number>("modelSize")?.toLong()
            val projectorSize = call.argument<Number>("projectorSize")?.toLong()
            if (listOf(modelAsset, projectorAsset, modelPath, projectorPath).any { it.isNullOrBlank() } ||
                modelSize == null || projectorSize == null || modelSize <= 0L || projectorSize <= 0L
            ) {
                result.error("invalid_arguments", "Не заданы пути встроенной модели.", null)
                return@setMethodCallHandler
            }
            Thread {
                try {
                    copyFlutterAsset(modelAsset!!, File(modelPath!!), modelSize)
                    copyFlutterAsset(projectorAsset!!, File(projectorPath!!), projectorSize)
                    runOnUiThread { result.success(null) }
                } catch (error: Throwable) {
                    runOnUiThread {
                        result.error("asset_copy_failed", error.message, null)
                    }
                }
            }.start()
        }
    }

    private fun copyFlutterAsset(assetName: String, destination: File, expectedSize: Long) {
        if (destination.exists() && destination.length() == expectedSize) return
        if (destination.exists()) destination.delete()
        destination.parentFile?.mkdirs()
        val temporary = File("${destination.path}.part")
        if (temporary.exists()) temporary.delete()
        val lookupKey = FlutterInjector.instance()
            .flutterLoader()
            .getLookupKeyForAsset(assetName)
        assets.open(lookupKey).use { input ->
            FileOutputStream(temporary).use { output ->
                input.copyTo(output, bufferSize = 1024 * 1024)
                output.fd.sync()
            }
        }
        if (temporary.length() != expectedSize) {
            temporary.delete()
            throw IllegalStateException(
                "Встроенный GGUF-файл повреждён: ожидалось $expectedSize байт.",
            )
        }
        if (destination.exists()) destination.delete()
        if (!temporary.renameTo(destination)) {
            temporary.copyTo(destination, overwrite = true)
            temporary.delete()
        }
    }
}
