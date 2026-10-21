package com.arete.app.arete

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream

object InstalledAppsHelper {

    private val EXCLUDED_PACKAGES = setOf(
        "com.arete.app.arete",
        "com.android.settings",
        "com.android.systemui",
        "com.google.android.dialer",
        "com.android.dialer",
        "com.google.android.packageinstaller",
        "com.android.packageinstaller"
    )

    fun getInstalledLaunchableApps(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val intent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val resolveInfos = pm.queryIntentActivities(intent, 0)
        val appList = mutableListOf<Map<String, Any?>>()
        val seenPackages = mutableSetOf<String>()

        for (resolveInfo in resolveInfos) {
            val pkgName = resolveInfo.activityInfo.packageName
            if (pkgName.isNullOrBlank() || EXCLUDED_PACKAGES.contains(pkgName) || seenPackages.contains(pkgName)) {
                continue
            }
            seenPackages.add(pkgName)

            val label = resolveInfo.loadLabel(pm).toString()
            val isSystem = (resolveInfo.activityInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            var iconBytes: ByteArray? = null
            try {
                val drawable = resolveInfo.loadIcon(pm)
                iconBytes = drawableToByteArray(drawable)
            } catch (e: Exception) {
                // Ignore icon conversion error
            }

            appList.add(
                mapOf(
                    "packageName" to pkgName,
                    "appName" to label,
                    "iconBytes" to iconBytes,
                    "isSystemApp" to isSystem
                )
            )
        }

        // Sort alphabetically by app name
        appList.sortBy { (it["appName"] as? String)?.lowercase() ?: "" }
        return appList
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray? {
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            // Scale if very large to conserve memory over MethodChannel
            val bmp = drawable.bitmap
            if (bmp.width > 96 || bmp.height > 96) {
                Bitmap.createScaledBitmap(bmp, 96, 96, true)
            } else {
                bmp
            }
        } else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth.coerceAtMost(96) else 96
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight.coerceAtMost(96) else 96
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }

        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 85, outputStream)
        return outputStream.toByteArray()
    }
}
