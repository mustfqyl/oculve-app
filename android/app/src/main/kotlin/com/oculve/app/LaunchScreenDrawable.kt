package com.oculve.app

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ColorFilter
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.drawable.Drawable

// Keep the dimensions and colors in sync with Flutter's LoadingScreen.
class LaunchScreenDrawable(context: Context, dark: Boolean) : Drawable() {
    private val density = context.resources.displayMetrics.density
    private val artwork = BitmapFactory.decodeResource(
        context.resources,
        if (dark) R.drawable.launch_veil_dark else R.drawable.launch_veil_light,
    )
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val colors = if (dark) {
        intArrayOf(0xFF252525.toInt(), 0xFF101419.toInt(), 0xFF081426.toInt())
    } else {
        intArrayOf(0xFFFFFFFF.toInt(), 0xFFF3F4F6.toInt(), 0xFFE8EDF5.toInt())
    }

    override fun draw(canvas: Canvas) {
        val rect = RectF(bounds)
        paint.shader = LinearGradient(
            0f, rect.top, 0f, rect.bottom, colors, null, Shader.TileMode.CLAMP,
        )
        canvas.drawRect(rect, paint)
        paint.shader = null
        val width = minOf(
            rect.width() * .92f,
            400f * density,
            (rect.height() - 40f * density).coerceAtLeast(0f) * 280f / 188f,
        )
        val height = width * 188f / 280f
        canvas.drawBitmap(
            artwork, null,
            RectF(
                rect.centerX() - width / 2, rect.centerY() - height / 2,
                rect.centerX() + width / 2, rect.centerY() + height / 2,
            ),
            paint,
        )
    }

    override fun setAlpha(alpha: Int) { paint.alpha = alpha }
    override fun setColorFilter(colorFilter: ColorFilter?) { paint.colorFilter = colorFilter }
    @Deprecated("Deprecated in Android")
    override fun getOpacity(): Int = PixelFormat.OPAQUE
}
