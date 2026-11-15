package com.rotaplus

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Rect
import android.os.Bundle
import androidx.core.view.WindowCompat
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import android.view.LayoutInflater
import android.widget.TextView
import android.widget.Button
import android.widget.ImageView
import com.rotaplus.R
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val factory = ListTileNativeAdFactory(layoutInflater)
        GoogleMobileAdsPlugin.registerNativeAdFactory(flutterEngine, "listTile", factory)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rotaplus/video_exporter")
            .setMethodCallHandler { call, result ->
                if (call.method == "encodeFramesToMp4") {
                    val framePaths = call.argument<List<String>>("framePaths") ?: emptyList()
                    val outputPath = call.argument<String>("outputPath") ?: ""
                    val fps = call.argument<Int>("fps") ?: 8
                    if (framePaths.isEmpty() || outputPath.isEmpty()) {
                        result.error("INVALID_ARGS", "Kare veya cikti yolu bos", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val outFile = encodeFramesToMp4(framePaths, outputPath, fps)
                            runOnUiThread { result.success(outFile) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("ENCODE_ERROR", e.message, null) }
                        }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun encodeFramesToMp4(framePaths: List<String>, outputPath: String, fps: Int): String {
        val firstBmp = BitmapFactory.decodeFile(framePaths.first())
            ?: throw IllegalStateException("Ilk kare okunamadi")
        val maxW = 720
        val scale = if (firstBmp.width > maxW) maxW.toFloat() / firstBmp.width else 1f
        val width = ((firstBmp.width * scale).toInt() / 2) * 2
        val height = ((firstBmp.height * scale).toInt() / 2) * 2
        firstBmp.recycle()

        val outFile = File(outputPath)
        if (outFile.exists()) outFile.delete()

        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 2_500_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }

        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        val inputSurface = codec.createInputSurface()
        codec.start()

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var trackIndex = -1
        var muxerStarted = false
        val bufferInfo = MediaCodec.BufferInfo()

        fun drainEncoder(endOfStream: Boolean) {
            if (endOfStream) codec.signalEndOfInputStream()
            while (true) {
                val outIdx = codec.dequeueOutputBuffer(bufferInfo, 10_000)
                if (outIdx == MediaCodec.INFO_TRY_AGAIN_LATER) {
                    if (!endOfStream) break
                } else if (outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    if (!muxerStarted) {
                        trackIndex = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                } else if (outIdx >= 0) {
                    val encodedData = codec.getOutputBuffer(outIdx)
                    if (encodedData != null && bufferInfo.size > 0 && muxerStarted && (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                        encodedData.position(bufferInfo.offset)
                        encodedData.limit(bufferInfo.offset + bufferInfo.size)
                        muxer.writeSampleData(trackIndex, encodedData, bufferInfo)
                    }
                    codec.releaseOutputBuffer(outIdx, false)
                    if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) break
                }
            }
        }

        try {
            val destRect = Rect(0, 0, width, height)
            for (path in framePaths) {
                val bmp = BitmapFactory.decodeFile(path) ?: continue
                val canvas = inputSurface.lockCanvas(null)
                canvas.drawBitmap(bmp, null, destRect, null)
                inputSurface.unlockCanvasAndPost(canvas)
                bmp.recycle()
                drainEncoder(false)
            }
            drainEncoder(true)
        } finally {
            try { codec.stop() } catch (_: Exception) {}
            try { codec.release() } catch (_: Exception) {}
            try { inputSurface.release() } catch (_: Exception) {}
            try { if (muxerStarted) muxer.stop() } catch (_: Exception) {}
            try { muxer.release() } catch (_: Exception) {}
        }

        return outputPath
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "listTile")
    }
}

class ListTileNativeAdFactory(private val layoutInflater: LayoutInflater) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.native_ad_list_tile, null) as NativeAdView

        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        bodyView.text = nativeAd.body
        adView.bodyView = bodyView

        val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)
        if (nativeAd.icon != null) {
            iconView.setImageDrawable(nativeAd.icon?.drawable)
        }
        adView.iconView = iconView

        val callToActionView = adView.findViewById<Button>(R.id.ad_call_to_action)
        callToActionView.text = nativeAd.callToAction
        adView.callToActionView = callToActionView

        adView.setNativeAd(nativeAd)
        return adView
    }
}
