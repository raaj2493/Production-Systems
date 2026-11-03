package com.arete.app.arete

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowManager
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
        const val EXTRA_IS_SHORT_FORM = "extra_is_short_form"
    }

    private var targetEndTimeMs: Long = 0L
    private var isStrictMode: Boolean = false
    private var isShortForm: Boolean = false
    private val handler = Handler(Looper.getMainLooper())

    private lateinit var ivAppIcon: ImageView
    private lateinit var tvAppName: TextView
    private lateinit var tvHeadline: TextView
    private lateinit var tvSubtitle: TextView
    private lateinit var tvTimerCountdown: TextView
    private lateinit var btnReturn: Button
    private lateinit var tvEmergency: TextView
    private lateinit var llQuickPass: View

    private val timerRunnable = object : Runnable {
        override fun run() {
            updateRemainingTime()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        setContentView(R.layout.activity_focus_shield_interruption)

        ivAppIcon = findViewById(R.id.ivBlockedAppIcon)
        tvAppName = findViewById(R.id.tvBlockedAppName)
        tvHeadline = findViewById(R.id.tvHeadline)
        tvSubtitle = findViewById(R.id.tvSubtitle)
        btnReturn = findViewById(R.id.btnReturnToArete)
        tvEmergency = findViewById(R.id.tvEmergencyExit)
        llQuickPass = findViewById(R.id.llQuickPassContainer)
        tvTimerCountdown = findViewById(R.id.tvTimerCountdown)

        btnReturn.setOnClickListener {
            returnToArete()
        }
        tvEmergency.setOnClickListener {
            handleEmergencyExit()
        }

        initFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent?.let {
            initFromIntent(it)
        }
    }

    private fun initFromIntent(intent: Intent) {
        val packageName = intent.getStringExtra(EXTRA_PACKAGE_NAME) ?: ""
        val sessionLabel = intent.getStringExtra(EXTRA_SESSION_LABEL) ?: "Deep Focus Session"
        targetEndTimeMs = intent.getLongExtra(EXTRA_END_TIME_MS, 0L)
        isStrictMode = intent.getBooleanExtra(EXTRA_STRICT_MODE, false)
        isShortForm = intent.getBooleanExtra(EXTRA_IS_SHORT_FORM, false)

        var appLabel = packageName
        try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            appLabel = packageManager.getApplicationLabel(appInfo).toString()
            val appIcon = packageManager.getApplicationIcon(appInfo)
            ivAppIcon.setImageDrawable(appIcon)
            ivAppIcon.visibility = View.VISIBLE
        } catch (_: Exception) {
            ivAppIcon.visibility = View.GONE
        }

        tvAppName.text = "$appLabel is Blocked"
        llQuickPass.visibility = View.GONE
        btnReturn.text = "Breathe & Return to Areté"

        updateRemainingTime()
    }

    override fun onResume() {
        super.onResume()
        handler.removeCallbacks(timerRunnable)
        handler.post(timerRunnable)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(timerRunnable)
    }

    private fun updateRemainingTime() {
        if (targetEndTimeMs <= 0L) {
            tvTimerCountdown.text = "Deep Focus Active"
            return
        }

        val now = System.currentTimeMillis()
        val remainingMs = targetEndTimeMs - now

        if (remainingMs <= 0) {
            tvTimerCountdown.text = "Session Complete"
            finish()
            return
        }

        val minutes = TimeUnit.MILLISECONDS.toMinutes(remainingMs)
        val seconds = TimeUnit.MILLISECONDS.toSeconds(remainingMs) % 60
        tvTimerCountdown.text = String.format(Locale.getDefault(), "Focus remaining: %02d:%02d", minutes, seconds)
    }

    private fun returnToArete() {
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage("com.arete.app.arete")
            if (launchIntent != null) {
                launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                startActivity(launchIntent)
            } else {
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)
            }
        } catch (_: Exception) {
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(homeIntent)
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
        returnToArete()
    }
}
