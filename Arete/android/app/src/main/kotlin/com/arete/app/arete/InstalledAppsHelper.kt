package com.arete.app.arete

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Log
import java.io.ByteArrayOutputStream

object InstalledAppsHelper {

    private val EXCLUDED_PACKAGES = setOf(
        "com.arete.app.arete",
        "com.android.settings",
        "com.android.systemui",
        "com.google.android.dialer",
        "com.android.dialer",
        "com.samsung.android.dialer",
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.google.android.permissioncontroller",
        "com.android.permissioncontroller"
    )

    fun getInstalledLaunchableApps(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val appList = mutableListOf<Map<String, Any?>>()
        val seenPackages = mutableSetOf<String>()

        // 1. Primary: Query all activities matching ACTION_MAIN + CATEGORY_LAUNCHER
        val launcherIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.queryIntentActivities(launcherIntent, PackageManager.ResolveInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                pm.queryIntentActivities(launcherIntent, 0)
            }
        } catch (e: Exception) {
            Log.e("InstalledAppsHelper", "Error querying launcher activities: ${e.message}")
            emptyList()
        }

        for (resolveInfo in resolveInfos) {
            val pkgName = resolveInfo.activityInfo?.packageName ?: continue
            if (pkgName.isBlank() || EXCLUDED_PACKAGES.contains(pkgName) || seenPackages.contains(pkgName)) {
                continue
            }
            seenPackages.add(pkgName)

            val label = try {
                resolveInfo.loadLabel(pm).toString()
            } catch (_: Exception) {
                pkgName
            }
            val isSystem = (resolveInfo.activityInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            var iconBytes: ByteArray? = null
            try {
                val drawable = resolveInfo.loadIcon(pm)
                iconBytes = drawableToByteArray(drawable)
            } catch (_: Exception) {}

            appList.add(
                mapOf(
                    "packageName" to pkgName,
                    "appName" to label,
                    "iconBytes" to iconBytes,
                    "isSystemApp" to isSystem
                )
            )
        }

        // 2. Secondary fallback: Query all installed applications that possess a valid launch intent
        // (Guarantees custom vendor games, modded clients like Revanced, web-apps & vendor apps are included)
        try {
            val allInstalledApps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                pm.getInstalledApplications(0)
            }

            for (appInfo in allInstalledApps) {
                val pkgName = appInfo.packageName ?: continue
                if (pkgName.isBlank() || EXCLUDED_PACKAGES.contains(pkgName) || seenPackages.contains(pkgName)) {
                    continue
                }

                // Verify the application has a user-facing launch intent
                val launchIntent = pm.getLaunchIntentForPackage(pkgName) ?: continue
                seenPackages.add(pkgName)

                val label = try {
                    pm.getApplicationLabel(appInfo).toString()
                } catch (_: Exception) {
                    pkgName
                }
                val isSystem = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

                var iconBytes: ByteArray? = null
                try {
                    val drawable = pm.getApplicationIcon(appInfo)
                    iconBytes = drawableToByteArray(drawable)
                } catch (_: Exception) {}

                appList.add(
                    mapOf(
                        "packageName" to pkgName,
                        "appName" to label,
                        "iconBytes" to iconBytes,
                        "isSystemApp" to isSystem
                    )
                )
            }
        } catch (e: Exception) {
            Log.e("InstalledAppsHelper", "Error in secondary fallback app query: ${e.message}")
        }

        // Sort alphabetically by app name for a delightful user experience
        appList.sortBy { (it["appName"] as? String)?.lowercase() ?: "" }
        return appList
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray? {
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
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
