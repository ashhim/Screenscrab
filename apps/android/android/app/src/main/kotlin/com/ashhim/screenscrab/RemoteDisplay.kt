package com.ashhim.screenscrab

import android.content.Context
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.view.View
import android.widget.ImageView
import androidx.annotation.NonNull
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

object RemoteDisplayRegistry {
    @Volatile
    var controller: RemoteDisplayController? = null
}

class RemoteDisplayController {
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile
    private var imageView: ImageView? = null

    fun attach(view: ImageView) {
        imageView = view
    }

    fun detach(view: ImageView) {
        if (imageView === view) {
            imageView = null
        }
    }

    fun renderFrame(frameBytes: ByteArray, width: Int, height: Int, strideBytes: Int): Boolean {
        if (width <= 0 || height <= 0 || strideBytes <= 0) {
            return false
        }
        val expectedBytes = strideBytes * height
        if (frameBytes.size < expectedBytes) {
            return false
        }

        val pixels = IntArray(width * height)
        var sourceOffset = 0
        for (y in 0 until height) {
            var rowOffset = sourceOffset
            for (x in 0 until width) {
                val b = frameBytes[rowOffset].toInt() and 0xFF
                val g = frameBytes[rowOffset + 1].toInt() and 0xFF
                val r = frameBytes[rowOffset + 2].toInt() and 0xFF
                val a = frameBytes[rowOffset + 3].toInt() and 0xFF
                pixels[(y * width) + x] = (a shl 24) or (r shl 16) or (g shl 8) or b
                rowOffset += 4
            }
            sourceOffset += strideBytes
        }

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        bitmap.setPixels(pixels, 0, width, 0, 0, width, height)

        mainHandler.post {
            imageView?.setImageBitmap(bitmap)
        }
        return true
    }
}

class RemoteDisplayViewFactory(
    private val controller: RemoteDisplayController,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return RemoteDisplayView(context, controller)
    }
}

class RemoteDisplayView(
    context: Context,
    private val controller: RemoteDisplayController,
) : PlatformView {
    private val view = ImageView(context).apply {
        scaleType = ImageView.ScaleType.FIT_CENTER
        adjustViewBounds = true
        setBackgroundColor(0xFF101418.toInt())
    }

    init {
        controller.attach(view)
    }

    override fun getView(): View = view

    override fun dispose() {
        controller.detach(view)
    }
}
