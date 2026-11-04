package com.example.maxei

import android.Manifest
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val channelName = "app.maxei/device_media"
    private val permissionRequestCode = 4107
    private val maxLyricsReadBytes = 256L * 1024 * 1024
    private val scannerExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingScanResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanMedia" -> requestPermissionAndScan(result)
                    "openAppSettings" -> {
                        openAppSettings()
                        result.success(null)
                    }
                    "copyAudioForLyrics" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val uri = arguments?.get("uri") as? String
                        val extension = arguments?.get("extension") as? String
                        if (uri == null || extension == null) {
                            result.error(
                                "invalid_audio_uri",
                                "URI ou extension audio manquante.",
                                null
                            )
                        } else {
                            scannerExecutor.execute {
                                try {
                                    val path = copyAudioForLyrics(uri, extension)
                                    mainHandler.post { result.success(path) }
                                } catch (error: Exception) {
                                    mainHandler.post {
                                        result.error(
                                            "lyrics_metadata_unavailable",
                                            "Impossible de lire les métadonnées de ce morceau.",
                                            error.message
                                        )
                                    }
                                }
                            }
                        }
                    }
                    "deleteLyricsTempFile" -> {
                        val path = call.arguments as? String
                        if (path == null) {
                            result.error(
                                "invalid_temp_path",
                                "Chemin temporaire manquant.",
                                null
                            )
                        } else {
                            try {
                                result.success(deleteLyricsTempFile(path))
                            } catch (error: Exception) {
                                result.error(
                                    "lyrics_temp_cleanup_failed",
                                    "Impossible de supprimer le fichier temporaire des paroles.",
                                    error.message
                                )
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun copyAudioForLyrics(rawUri: String, rawExtension: String): String {
        val uri = Uri.parse(rawUri)
        if (uri.scheme != "content" || uri.authority != MediaStore.AUTHORITY) {
            throw IllegalArgumentException("Only local MediaStore audio is supported.")
        }
        val extension = rawExtension.lowercase()
        if (extension !in setOf(
                "mp3", "flac", "mp4", "m4a", "ape", "ogg", "opus",
                "wav", "aif", "aiff", "aifc", "mov", "webm", "mkv"
            )
        ) {
            throw IllegalArgumentException("Audio container is not supported.")
        }
        val temporaryFile =
            File.createTempFile("maxei-lyrics-", ".$extension", cacheDir)
        try {
            val input = contentResolver.openInputStream(uri)
                ?: throw IllegalStateException("MediaStore returned no audio stream.")
            input.use { source ->
                temporaryFile.outputStream().use { destination ->
                    val buffer = ByteArray(64 * 1024)
                    var totalBytes = 0L
                    while (true) {
                        val count = source.read(buffer)
                        if (count < 0) break
                        totalBytes += count
                        if (totalBytes > maxLyricsReadBytes) {
                            throw IllegalArgumentException(
                                "Audio file exceeds the 256 MiB lyrics-reading limit."
                            )
                        }
                        destination.write(buffer, 0, count)
                    }
                }
            }
            return temporaryFile.absolutePath
        } catch (error: Exception) {
            temporaryFile.delete()
            throw error
        }
    }

    private fun deleteLyricsTempFile(rawPath: String): Boolean {
        val file = File(rawPath).canonicalFile
        if (file.parentFile != cacheDir.canonicalFile ||
            !file.name.startsWith("maxei-lyrics-")
        ) {
            throw IllegalArgumentException("Path is outside the lyrics cache.")
        }
        if (file.exists() && !file.delete()) {
            throw IOException("Could not remove temporary lyrics file.")
        }
        return true
    }

    private fun audioPermission(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_AUDIO
        } else Manifest.permission.READ_EXTERNAL_STORAGE

    private fun videoPermission(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_VIDEO
        } else Manifest.permission.READ_EXTERNAL_STORAGE

    private fun hasMediaPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(this, permission) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestPermissionAndScan(result: MethodChannel.Result) {
        if (pendingScanResult != null) {
            result.error("scan_in_progress", "Un scan média est déjà en cours.", null)
            return
        }
        val permissions = listOf(audioPermission(), videoPermission()).distinct()
        val missingPermissions = permissions.filterNot(::hasMediaPermission)
        if (missingPermissions.isEmpty()) {
            scanMedia(result)
            return
        }
        pendingScanResult = result
        requestPermissions(missingPermissions.toTypedArray(), permissionRequestCode)
    }

    @Deprecated("Deprecated in Android")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequestCode) return

        val result = pendingScanResult ?: return
        pendingScanResult = null
        scanMedia(result)
    }

    private fun scanMedia(result: MethodChannel.Result) {
        val canReadAudio = hasMediaPermission(audioPermission())
        val canReadVideo = hasMediaPermission(videoPermission())
        scannerExecutor.execute {
            try {
                val items = queryDeviceMedia(canReadAudio, canReadVideo)
                mainHandler.post {
                    result.success(
                        mapOf(
                            "audioPermissionGranted" to canReadAudio,
                            "videoPermissionGranted" to canReadVideo,
                            "items" to items
                        )
                    )
                }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error(
                        "device_media_scan_failed",
                        "Impossible d’analyser la bibliothèque média.",
                        error.message
                    )
                }
            }
        }
    }

    private fun queryDeviceMedia(
        canReadAudio: Boolean,
        canReadVideo: Boolean
    ): List<Map<String, Any?>> {
        val items = mutableListOf<Map<String, Any?>>()
        if (canReadAudio) items.addAll(queryDeviceAudio())
        if (canReadVideo) items.addAll(queryDeviceVideo())
        return items
    }

    private fun externalVolumes(): Set<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.getExternalVolumeNames(applicationContext)
        } else setOf("external")

    private fun queryDeviceAudio(): List<Map<String, Any?>> {
        val resolver = applicationContext.contentResolver
        val volumes = externalVolumes()
        val columns = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_ADDED
        )
        val items = mutableListOf<Map<String, Any?>>()
        val seenUris = mutableSetOf<String>()

        for (volume in volumes) {
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Audio.Media.getContentUri(volume)
            } else {
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            }
            val cursor = resolver.query(
                collection,
                columns,
                "${MediaStore.Audio.Media.IS_MUSIC} != 0",
                null,
                "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"
            ) ?: throw IllegalStateException("MediaStore audio query returned no cursor")
            cursor.use {
                val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val dateAddedColumn =
                    cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)

                while (cursor.moveToNext()) {
                    val uri = ContentUris.withAppendedId(
                        collection,
                        cursor.getLong(idColumn)
                    ).toString()
                    if (!seenUris.add(uri)) continue
                    val name = cursor.getString(nameColumn)
                        ?: cursor.getString(titleColumn)
                        ?: "audio"
                    items.add(
                        mapOf(
                            "uri" to uri,
                            "name" to name,
                            "title" to (cursor.getString(titleColumn) ?: ""),
                            "artist" to (cursor.getString(artistColumn) ?: ""),
                            "album" to (cursor.getString(albumColumn) ?: ""),
                            "size" to cursor.getLong(sizeColumn),
                            "durationMs" to cursor.getLong(durationColumn),
                            "dateAdded" to cursor.getLong(dateAddedColumn),
                            "kind" to "audio"
                        )
                    )
                }
            }
        }
        return items
    }

    private fun queryDeviceVideo(): List<Map<String, Any?>> {
        val resolver = applicationContext.contentResolver
        val items = mutableListOf<Map<String, Any?>>()
        val seenUris = mutableSetOf<String>()
        val columns = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.TITLE,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.DATE_ADDED
        )
        val selection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            "${MediaStore.Video.Media.IS_PENDING} = 0"
        } else null

        for (volume in externalVolumes()) {
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Video.Media.getContentUri(volume)
            } else {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }
            val cursor = resolver.query(
                collection,
                columns,
                selection,
                null,
                null
            ) ?: throw IllegalStateException("MediaStore video query returned no cursor")
            cursor.use {
                val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
                val nameColumn =
                    cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
                val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.TITLE)
                val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.SIZE)
                val durationColumn =
                    cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
                val dateAddedColumn =
                    cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)

                while (cursor.moveToNext()) {
                    val uri = ContentUris.withAppendedId(
                        collection,
                        cursor.getLong(idColumn)
                    ).toString()
                    if (!seenUris.add(uri)) continue
                    val name = cursor.getString(nameColumn)
                        ?: cursor.getString(titleColumn)
                        ?: "video"
                    items.add(
                        mapOf(
                            "uri" to uri,
                            "name" to name,
                            "title" to (cursor.getString(titleColumn) ?: ""),
                            "size" to cursor.getLong(sizeColumn),
                            "durationMs" to cursor.getLong(durationColumn),
                            "dateAdded" to cursor.getLong(dateAddedColumn),
                            "kind" to "video"
                        )
                    )
                }
            }
        }
        return items
    }

    private fun openAppSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", packageName, null)
        )
        startActivity(intent)
    }

    override fun onDestroy() {
        pendingScanResult = null
        scannerExecutor.shutdownNow()
        super.onDestroy()
    }
}
