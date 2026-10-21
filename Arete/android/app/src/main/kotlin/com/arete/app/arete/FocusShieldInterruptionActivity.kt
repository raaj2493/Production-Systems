package com.arete.app.arete

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import java.util.Locale
import java.util.concurrent.TimeUnit

class FocusShieldInterruptionActivity : Activity() {

    companion object {
        const val EXTRA_PACKAGE_NAME = "extra_package_name"
        const val EXTRA_SESSION_LABEL = "extra_session_label"
        const val EXTRA_END_TIME_MS = "extra_end_time_ms"
        const val EXTRA_STRICT_MODE = "extra_strict_mode"
    }

    private var targetEndTimeMs: Long = 0L
    private var isStrictMode: Boolean = false
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var tvTimerCountdown: TextView

    private val timerRunnable = object : Runnable {
        override fun run() {
            updateRemainingTime()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_focus_shield_interruption)

        val packageName = intent.getStringExtra(EXTRA_PACKAGE_NAME) ?: ""
        val sessionLabel = intent.getStringExtra(EXTRA_SESSION_LABEL) ?: "Deep Focus Session"
        targetEndTimeMs = intent.getLongExtra(EXTRA_END_TIME_MS, 0L)
        isStrictMode = intent.getBooleanExtra(EXTRA_STRICT_MODE, false)

        val ivAppIcon = findViewById<ImageView>(R.id.ivBlockedAppIcon)
        val tvAppName = findViewById<TextView>(R.id.tvBlockedAppName)
        val tvHeadline = findViewById<TextView>(R.id.tvHeadline)
        val btnReturn = findViewById<Button>(R.id.btnReturnToArete)
        val tvEmergency = findViewById<TextView>(R.id.tvEmergencyExit)
        tvTimerCountdown = findViewById(R.id.tvTimerCountdown)

        // Load blocked app details from PackageManager
        var appLabel = packageName
        try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            appLabel = packageManager.getApplicationLabel(appInfo).toString()
            val appIcon = packageManager.getApplicationIcon(appInfo)
            ivAppIcon.setImageDrawable(appIcon)
        } catch (e: Exception) {
            ivAppIcon.visibility = View.GONE
        }
        tvAppName.text = "$appLabel is Blocked"

        // Setup primary action: Return directly to Areté
        btnReturn.setOnClickListener {
            returnToArete()
        }

        // Setup emergency exit
        tvEmergency.setOnClickListener {
            handleEmergencyExit()
        }
    }

    override fun onResume() {
        super.onResume()
        handler.post(timerRunnable)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(timerRunnable)
    }

    private fun updateRemainingTime() {
        val now = System.currentTimeMillis()
        val remainingMs = targetEndTimeMs - now

        if (remainingMs <= 0) {
            tvTimerCountdown.text = "Session Complete"
            FocusShieldPreferences.deactivateShield(this)
            finish()
            return
        }

        val minutes = TimeUnit.MILLISECONDS.toMinutes(remainingMs)
        val seconds = TimeUnit.MILLISECONDS.toSeconds(remainingMs) % 60
        tvTimerCountdown.text = String.format(Locale.getDefault(), "Focus remaining: %02d:%02d", minutes, seconds)
    }

    private fun returnToArete() {
        val launchIntent = packageManager.getLaunchIntentForPackage("com.arete.app.arete")
        if (launchIntent != null) {
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            startActivity(launchIntent)
        }
        finish()
    }

    private fun handleEmergencyExit() {
        if (isStrictMode) {
            AlertDialog.Builder(this)
                .setTitle("Strict Mode Active")
                .setMessage("You committed to this focus block without early exits. Are you sure you need to break this session?")
                .setPositiveButton("Break Session") { _, _ ->
                    FocusShieldPreferences.deactivateShield(this)
                    returnToArete()
                }
                .setNegativeButton("Keep Focusing", null)
                .show()
        } else {
            AlertDialog.Builder(this)
                .setTitle("Pause Focus Shield?")
                .setMessage("Return to home screen and pause blocking for now?")
                .setPositiveButton("Pause") { _, _ ->
                    FocusShieldPreferences.pauseShield(this)
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(homeIntent)
                    finish()
                }
                .setNegativeButton("Keep Focusing", null)
                .show()
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Prevent bypassing interruption screen by pressing Back into the blocked app.
        // Direct the user back to Areté or Home.
        returnToArete()
    }
}
