package com.arete.app.arete

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Outline
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PixelFormat
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewOutlineProvider
import android.view.WindowManager
import android.view.animation.AlphaAnimation
import android.view.animation.Animation
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import kotlin.math.abs
import kotlin.math.hypot

/**
 * Translucent Glassmorphic Material You Floating Overlay Service with Native Dismiss Target ("✕").
 *
 * Features:
 * 1. Default Minimized State: Micro Translucent Glass Bubble (~44dp x 44dp):
 *    - Translucent glassmorphic container (70% opacity sage/amber glass with specular white rim).
 *    - Refined 3.2dp animated progress ring with luminous dual-tone SweepGradient.
 *    - 3D embossed Electric Amber Gold lightning bolt (⚡).
 *    - Crisp, bold tabular countdown digits ("59m") in deep obsidian forest.
 *    - Floating ambient drop shadow (0 6px 20px rgba(0,0,0,0.18)).
 * 2. Stage 1 Tap: Smooth spring expansion into Dynamic Island horizontal capsule pill
 *    (Electric badge + "59:08" digits + circular play/pause control).
 *    Auto-collapses back to Micro Circular Bubble after 4 seconds of idle time.
 * 3. Stage 2 Tap: Tapping the Expanded Pill (or double-tapping bubble)
 *    immediately launches Areté into Full-Screen Focus View.
 * 4. Bottom-Center Dismiss Target ("✕"):
 *    - When dragging starts, an Android system bubble dismissal target ("✕") appears at bottom-center.
 *    - Dragging over the dismiss target triggers haptic feedback, expands to 1.2x, and glows active red.
 *    - Releasing over the target dismisses / removes the floating bubble!
 */
class FloatingTimerOverlayService : Service() {

    enum class OverlayState {
        MINIMIZED_CIRCLE,
        EXPANDED_PILL
    }

    companion object {
        const val ACTION_SHOW = "com.arete.app.FLOATING_TIMER_SHOW"
        const val ACTION_HIDE = "com.arete.app.FLOATING_TIMER_HIDE"
        const val ACTION_UPDATE = "com.arete.app.FLOATING_TIMER_UPDATE"

        const val EXTRA_REMAINING_SECONDS = "extra_remaining_seconds"
        const val EXTRA_TOTAL_SECONDS = "extra_total_seconds"
        const val EXTRA_IS_RUNNING = "extra_is_running"
        const val EXTRA_IS_BREAK = "extra_is_break"

        private const val NOTIFICATION_ID = 9015
        private const val CHANNEL_ID = "arete_floating_overlay_channel"
        private const val AUTO_COLLAPSE_DELAY_MS = 4000L

        var isOverlayShowing: Boolean = false
            private set

        fun show(
            context: Context,
            remainingSeconds: Int,
            totalSeconds: Int,
            isRunning: Boolean,
            isBreak: Boolean
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
                return
            }
            val intent = Intent(context, FloatingTimerOverlayService::class.java).apply {
                action = ACTION_SHOW
                putExtra(EXTRA_REMAINING_SECONDS, remainingSeconds)
                putExtra(EXTRA_TOTAL_SECONDS, totalSeconds)
                putExtra(EXTRA_IS_RUNNING, isRunning)
                putExtra(EXTRA_IS_BREAK, isBreak)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Exception) {}
        }

        fun update(
            context: Context,
            remainingSeconds: Int,
            totalSeconds: Int,
            isRunning: Boolean,
            isBreak: Boolean
        ) {
            if (!isOverlayShowing) return
            val intent = Intent(context, FloatingTimerOverlayService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_REMAINING_SECONDS, remainingSeconds)
                putExtra(EXTRA_TOTAL_SECONDS, totalSeconds)
                putExtra(EXTRA_IS_RUNNING, isRunning)
                putExtra(EXTRA_IS_BREAK, isBreak)
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {}
        }

        fun hide(context: Context) {
            if (!isOverlayShowing) return
            val intent = Intent(context, FloatingTimerOverlayService::class.java).apply {
                action = ACTION_HIDE
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {}
        }
    }

    private var windowManager: WindowManager? = null
    private var rootView: FrameLayout? = null
    private var bubbleView: CircularProgressBubbleView? = null
    private var capsuleContainer: LinearLayout? = null
    private var lightningBadgeView: MicroLightningBadgeView? = null
    private var timerTextView: TextView? = null
    private var playPauseBtn: FrameLayout? = null
    private var playPauseIcon: ImageView? = null
    private var windowLayoutParams: WindowManager.LayoutParams? = null

    // Native Dismiss Target ("✕" at bottom-center)
    private var dismissTargetView: FrameLayout? = null
    private var dismissCrossView: DismissCrossTargetView? = null
    private var dismissParams: WindowManager.LayoutParams? = null
    private var isHoveringDismiss: Boolean = false
    private var isDismissShowing: Boolean = false

    private var currentState: OverlayState = OverlayState.MINIMIZED_CIRCLE
    private var isTransitioning: Boolean = false
    private var lastBubbleTapTime: Long = 0L

    private val collapseHandler = Handler(Looper.getMainLooper())
    private val collapseRunnable = Runnable {
        if (currentState == OverlayState.EXPANDED_PILL) {
            transitionToState(OverlayState.MINIMIZED_CIRCLE, animate = true)
        }
    }

    private var remainingSeconds: Int = 25 * 60
    private var totalSeconds: Int = 25 * 60
    private var isRunning: Boolean = true
    private var isBreak: Boolean = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        startServiceForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        when (intent.action) {
            ACTION_SHOW -> {
                remainingSeconds = intent.getIntExtra(EXTRA_REMAINING_SECONDS, remainingSeconds)
                totalSeconds = intent.getIntExtra(EXTRA_TOTAL_SECONDS, totalSeconds)
                isRunning = intent.getBooleanExtra(EXTRA_IS_RUNNING, true)
                isBreak = intent.getBooleanExtra(EXTRA_IS_BREAK, false)
                // Always spawn in DEFAULT MINIMIZED STATE: Micro Circular Bubble
                currentState = OverlayState.MINIMIZED_CIRCLE
                createOrUpdateOverlay()
            }
            ACTION_UPDATE -> {
                remainingSeconds = intent.getIntExtra(EXTRA_REMAINING_SECONDS, remainingSeconds)
                val newTotal = intent.getIntExtra(EXTRA_TOTAL_SECONDS, 0)
                if (newTotal > 0) totalSeconds = newTotal
                isRunning = intent.getBooleanExtra(EXTRA_IS_RUNNING, isRunning)
                isBreak = intent.getBooleanExtra(EXTRA_IS_BREAK, isBreak)
                updateUiState()
            }
            ACTION_HIDE -> {
                cancelAutoCollapseTimer()
                removeOverlayView()
                stopForeground(true)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun startServiceForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Areté Floating Pill Service",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Background floating timer overlay"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = if (launchIntent != null) {
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            PendingIntent.getActivity(this, 9020, launchIntent, flags)
        } else null

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_arete)
            .setContentTitle("Areté Focus Session Active")
            .setContentText("Floating overlay is active. Tap to return.")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun dpToPx(dp: Float): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp,
            resources.displayMetrics
        ).toInt()
    }

    private fun formatPillTime(seconds: Int): String {
        val safeSeconds = seconds.coerceAtLeast(0)
        val mins = safeSeconds / 60
        val secs = safeSeconds % 60
        return String.format("%02d:%02d", mins, secs)
    }

    private fun formatBubbleTime(seconds: Int): String {
        val safeSeconds = seconds.coerceAtLeast(0)
        return if (safeSeconds < 60) {
            "${safeSeconds}s"
        } else {
            val mins = safeSeconds / 60
            "${mins}m"
        }
    }

    private fun triggerHaptic() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                vibrator?.vibrate(VibrationEffect.createOneShot(24, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                rootView?.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
            }
        } catch (_: Exception) {}
    }

    private fun createOrUpdateOverlay() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }

        if (rootView != null) {
            cancelAutoCollapseTimer()
            transitionToState(OverlayState.MINIMIZED_CIRCLE, animate = false)
            updateUiState()
            return
        }

        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels
        val circleSize = dpToPx(44f)
        val margin = dpToPx(12f)

        // 1. Native WindowManager.LayoutParams: 100% transparent overlay with zero PiP window box
        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            // Default position: top right edge
            x = screenWidth - circleSize - margin
            y = screenHeight / 4
        }
        windowLayoutParams = params

        // 2. Root FrameLayout with 100% transparent background
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.TRANSPARENT)
            setPadding(0, 0, 0, 0)
            clipChildren = false
            clipToPadding = false
        }
        rootView = root

        // 3. Stage 1 View: Elevated Electric Micro Circular Bubble (~44dp x 44dp)
        val bubble = CircularProgressBubbleView(this).apply {
            layoutParams = FrameLayout.LayoutParams(circleSize, circleSize, Gravity.START or Gravity.TOP)
            visibility = View.VISIBLE
        }
        bubbleView = bubble
        root.addView(bubble)

        // 4. Stage 2 View: Luxury Dynamic Island Capsule Pill (~40dp height)
        val capsule = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val horizontalPadding = dpToPx(11f)
            val verticalPadding = dpToPx(5.5f)
            setPadding(horizontalPadding, verticalPadding, dpToPx(7f), verticalPadding)
            elevation = dpToPx(14f).toFloat()
            clipChildren = false
            clipToPadding = false
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                dpToPx(40f),
                Gravity.START or Gravity.TOP
            )
            visibility = View.GONE
        }
        capsuleContainer = capsule

        // Left: Animated Micro Electric Lightning Badge
        val badge = MicroLightningBadgeView(this).apply {
            val size = dpToPx(24f)
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                gravity = Gravity.CENTER_VERTICAL
            }
        }
        lightningBadgeView = badge
        capsule.addView(badge)

        // Center: Bold Countdown Digits
        val timerView = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER_VERTICAL
                marginStart = dpToPx(9.5f)
                marginEnd = dpToPx(10f)
            }
            textSize = 16f
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            includeFontPadding = false
        }
        timerTextView = timerView
        capsule.addView(timerView)

        // Right: Circular Tactile Play/Pause Control Button Disc
        val playBtn = FrameLayout(this).apply {
            val size = dpToPx(28f)
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                gravity = Gravity.CENTER_VERTICAL
            }
        }
        playPauseBtn = playBtn

        val icon = ImageView(this).apply {
            val size = dpToPx(15f)
            layoutParams = FrameLayout.LayoutParams(size, size, Gravity.CENTER)
        }
        playPauseIcon = icon
        playBtn.addView(icon)
        capsule.addView(playBtn)

        root.addView(capsule)

        // 5. Setup Native Dismiss Target ("✕" at bottom-center)
        setupDismissTarget(layoutType)

        // 6. Setup Drag-and-Snap & Tap Listeners
        setupBubbleInteractions(bubble, params)
        setupPillInteractions(capsule, params)

        updateUiState()

        try {
            windowManager?.addView(root, params)
            isOverlayShowing = true
        } catch (_: Exception) {
            isOverlayShowing = false
            stopSelf()
        }
    }

    private fun setupDismissTarget(layoutType: Int) {
        val dParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            y = dpToPx(64f)
        }
        dismissParams = dParams

        val crossView = DismissCrossTargetView(this)
        dismissCrossView = crossView

        val target = FrameLayout(this).apply {
            val size = dpToPx(56f)
            layoutParams = FrameLayout.LayoutParams(size, size)
            addView(crossView)
            visibility = View.GONE
            alpha = 0f
            scaleX = 0.5f
            scaleY = 0.5f
        }
        dismissTargetView = target

        try {
            windowManager?.addView(target, dParams)
        } catch (_: Exception) {}
    }

    private fun showDismissTarget() {
        val target = dismissTargetView ?: return
        if (isDismissShowing) return
        isDismissShowing = true
        target.visibility = View.VISIBLE
        target.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(190)
            .setInterpolator(OvershootInterpolator(1.2f))
            .start()
    }

    private fun hideDismissTarget(onComplete: (() -> Unit)? = null) {
        val target = dismissTargetView ?: return
        if (!isDismissShowing) {
            onComplete?.invoke()
            return
        }
        isDismissShowing = false
        isHoveringDismiss = false
        dismissCrossView?.isDropTargetHovered = false
        target.animate()
            .alpha(0f)
            .scaleX(0.5f)
            .scaleY(0.5f)
            .setDuration(170)
            .setInterpolator(DecelerateInterpolator())
            .withEndAction {
                target.visibility = View.GONE
                onComplete?.invoke()
            }
            .start()
    }

    private fun checkDismissHover(currentWidth: Int, currentHeight: Int) {
        val params = windowLayoutParams ?: return
        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels

        val bubbleCenterX = params.x + currentWidth / 2f
        val bubbleCenterY = params.y + currentHeight / 2f

        val dismissCenterX = screenWidth / 2f
        val dismissCenterY = screenHeight - dpToPx(64f + 28f).toFloat()

        val dx = bubbleCenterX - dismissCenterX
        val dy = bubbleCenterY - dismissCenterY
        val dist = hypot(dx.toDouble(), dy.toDouble()).toFloat()
        val threshold = dpToPx(76f).toFloat()

        val hovering = dist < threshold
        if (hovering != isHoveringDismiss) {
            isHoveringDismiss = hovering
            dismissCrossView?.isDropTargetHovered = hovering
            if (hovering) {
                triggerHaptic()
                dismissTargetView?.animate()?.scaleX(1.22f)?.scaleY(1.22f)?.setDuration(140)?.start()
            } else {
                dismissTargetView?.animate()?.scaleX(1.0f)?.scaleY(1.0f)?.setDuration(140)?.start()
            }
        }
    }

    private fun setupBubbleInteractions(bubble: View, params: WindowManager.LayoutParams) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false
        var touchStartTime = 0L
        val circleSize = dpToPx(44f)

        bubble.setOnTouchListener { _, event ->
            if (isTransitioning) return@setOnTouchListener true

            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    touchStartTime = System.currentTimeMillis()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (abs(dx) > 10 || abs(dy) > 10) {
                        if (!isDragging) {
                            isDragging = true
                            showDismissTarget()
                        }
                    }
                    if (isDragging) {
                        val screenHeight = resources.displayMetrics.heightPixels
                        params.x = initialX + dx
                        params.y = (initialY + dy).coerceIn(dpToPx(36f), screenHeight - dpToPx(90f))
                        try {
                            windowManager?.updateViewLayout(rootView, params)
                        } catch (_: Exception) {}
                        checkDismissHover(circleSize, circleSize)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val duration = System.currentTimeMillis() - touchStartTime
                    val totalDx = abs(event.rawX - initialTouchX)
                    val totalDy = abs(event.rawY - initialTouchY)

                    if (isHoveringDismiss) {
                        // User dropped bubble onto the bottom-center "✕" dismissal target!
                        triggerHaptic()
                        hideDismissTarget {
                            hide(this@FloatingTimerOverlayService)
                        }
                    } else if (isDragging) {
                        hideDismissTarget()
                        snapToNearestEdge(circleSize)
                    } else if (totalDx < 15 && totalDy < 15 && duration < 350) {
                        val now = System.currentTimeMillis()
                        if (now - lastBubbleTapTime < 320L) {
                            // Double Tap on Bubble: Immediately launch full app
                            lastBubbleTapTime = 0L
                            openApp()
                        } else {
                            // Single Tap on Bubble: Expand to Active Pill
                            lastBubbleTapTime = now
                            transitionToState(OverlayState.EXPANDED_PILL, animate = true)
                        }
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    hideDismissTarget()
                    true
                }
                else -> false
            }
        }
    }

    private fun setupPillInteractions(capsule: View, params: WindowManager.LayoutParams) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false
        var touchStartTime = 0L

        capsule.setOnTouchListener { _, event ->
            if (isTransitioning) return@setOnTouchListener true

            // Check if touch target is the play/pause button
            if (isTouchInsideView(playPauseBtn, event.rawX, event.rawY)) {
                if (event.action == MotionEvent.ACTION_DOWN) {
                    resetAutoCollapseTimer()
                } else if (event.action == MotionEvent.ACTION_UP) {
                    togglePlayPause()
                    resetAutoCollapseTimer()
                }
                return@setOnTouchListener true
            }

            val pillWidth = capsuleContainer?.width?.takeIf { it > 0 } ?: dpToPx(140f)
            val pillHeight = dpToPx(40f)

            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    cancelAutoCollapseTimer()
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    touchStartTime = System.currentTimeMillis()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (abs(dx) > 10 || abs(dy) > 10) {
                        if (!isDragging) {
                            isDragging = true
                            showDismissTarget()
                        }
                    }
                    if (isDragging) {
                        val screenHeight = resources.displayMetrics.heightPixels
                        params.x = initialX + dx
                        params.y = (initialY + dy).coerceIn(dpToPx(36f), screenHeight - dpToPx(90f))
                        try {
                            windowManager?.updateViewLayout(rootView, params)
                        } catch (_: Exception) {}
                        checkDismissHover(pillWidth, pillHeight)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val duration = System.currentTimeMillis() - touchStartTime
                    val totalDx = abs(event.rawX - initialTouchX)
                    val totalDy = abs(event.rawY - initialTouchY)

                    if (isHoveringDismiss) {
                        // User dropped pill onto dismissal target!
                        triggerHaptic()
                        hideDismissTarget {
                            hide(this@FloatingTimerOverlayService)
                        }
                    } else if (isDragging) {
                        hideDismissTarget()
                        snapToNearestEdge(pillWidth)
                        resetAutoCollapseTimer()
                    } else if (totalDx < 15 && totalDy < 15 && duration < 350) {
                        // Stage 2 Tap on Pill: Launch Full App into Focus View
                        cancelAutoCollapseTimer()
                        openApp()
                    } else {
                        resetAutoCollapseTimer()
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    hideDismissTarget()
                    resetAutoCollapseTimer()
                    true
                }
                else -> false
            }
        }
    }

    private fun isTouchInsideView(view: View?, rawX: Float, rawY: Float): Boolean {
        if (view == null || view.visibility != View.VISIBLE) return false
        val location = IntArray(2)
        view.getLocationOnScreen(location)
        val left = location[0]
        val top = location[1]
        val right = left + view.width
        val bottom = top + view.height
        val slop = dpToPx(6f)
        return rawX >= (left - slop) && rawX <= (right + slop) &&
            rawY >= (top - slop) && rawY <= (bottom + slop)
    }

    private fun transitionToState(targetState: OverlayState, animate: Boolean) {
        if (currentState == targetState || isTransitioning) return
        if (rootView == null || windowLayoutParams == null) return

        val params = windowLayoutParams ?: return
        val bubble = bubbleView ?: return
        val capsule = capsuleContainer ?: return

        val screenWidth = resources.displayMetrics.widthPixels
        val margin = dpToPx(12f)
        val circleSize = dpToPx(44f)
        val pillWidth = capsule.width.takeIf { it > 0 } ?: dpToPx(142f)
        val pillHeight = dpToPx(40f)

        val currentWidth = if (currentState == OverlayState.MINIMIZED_CIRCLE) circleSize else pillWidth
        val isOnRight = (params.x + currentWidth / 2) >= screenWidth / 2

        val startX = params.x
        val targetX = if (targetState == OverlayState.EXPANDED_PILL) {
            if (isOnRight) screenWidth - pillWidth - margin else margin
        } else {
            if (isOnRight) screenWidth - circleSize - margin else margin
        }

        val startY = params.y
        val targetY = if (targetState == OverlayState.EXPANDED_PILL) {
            (params.y + (circleSize - pillHeight) / 2).coerceIn(dpToPx(36f), resources.displayMetrics.heightPixels - dpToPx(90f))
        } else {
            (params.y - (circleSize - pillHeight) / 2).coerceIn(dpToPx(36f), resources.displayMetrics.heightPixels - dpToPx(90f))
        }

        currentState = targetState

        if (!animate) {
            params.x = targetX
            params.y = targetY
            if (targetState == OverlayState.EXPANDED_PILL) {
                bubble.visibility = View.GONE
                capsule.visibility = View.VISIBLE
                capsule.alpha = 1f
                capsule.scaleX = 1f
                capsule.scaleY = 1f
                resetAutoCollapseTimer()
            } else {
                capsule.visibility = View.GONE
                bubble.visibility = View.VISIBLE
                bubble.alpha = 1f
                bubble.scaleX = 1f
                bubble.scaleY = 1f
                cancelAutoCollapseTimer()
            }
            try {
                windowManager?.updateViewLayout(rootView, params)
            } catch (_: Exception) {}
            return
        }

        isTransitioning = true

        if (targetState == OverlayState.EXPANDED_PILL) {
            cancelAutoCollapseTimer()
            capsule.visibility = View.VISIBLE
            capsule.alpha = 0f
            capsule.scaleX = 0.5f
            capsule.scaleY = 0.5f

            val animator = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 260
                interpolator = OvershootInterpolator(1.15f)
                addUpdateListener { va ->
                    val fraction = va.animatedFraction
                    params.x = (startX + (targetX - startX) * fraction).toInt()
                    params.y = (startY + (targetY - startY) * fraction).toInt()

                    bubble.alpha = (1f - fraction * 1.5f).coerceIn(0f, 1f)
                    bubble.scaleX = 1f - fraction * 0.3f
                    bubble.scaleY = 1f - fraction * 0.3f

                    capsule.alpha = (fraction * 1.5f).coerceIn(0f, 1f)
                    capsule.scaleX = 0.5f + fraction * 0.5f
                    capsule.scaleY = 0.5f + fraction * 0.5f

                    try {
                        windowManager?.updateViewLayout(rootView, params)
                    } catch (_: Exception) {}
                }
                addListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        bubble.visibility = View.GONE
                        isTransitioning = false
                        resetAutoCollapseTimer()
                    }
                })
            }
            animator.start()
        } else {
            cancelAutoCollapseTimer()
            bubble.visibility = View.VISIBLE
            bubble.alpha = 0f
            bubble.scaleX = 0.7f
            bubble.scaleY = 0.7f

            val animator = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 240
                interpolator = DecelerateInterpolator()
                addUpdateListener { va ->
                    val fraction = va.animatedFraction
                    params.x = (startX + (targetX - startX) * fraction).toInt()
                    params.y = (startY + (targetY - startY) * fraction).toInt()

                    capsule.alpha = (1f - fraction * 1.5f).coerceIn(0f, 1f)
                    capsule.scaleX = 1f - fraction * 0.25f
                    capsule.scaleY = 1f - fraction * 0.25f

                    bubble.alpha = (fraction * 1.5f).coerceIn(0f, 1f)
                    bubble.scaleX = 0.7f + fraction * 0.3f
                    bubble.scaleY = 0.7f + fraction * 0.3f

                    try {
                        windowManager?.updateViewLayout(rootView, params)
                    } catch (_: Exception) {}
                }
                addListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        capsule.visibility = View.GONE
                        isTransitioning = false
                    }
                })
            }
            animator.start()
        }
    }

    private fun resetAutoCollapseTimer() {
        collapseHandler.removeCallbacks(collapseRunnable)
        if (currentState == OverlayState.EXPANDED_PILL) {
            collapseHandler.postDelayed(collapseRunnable, AUTO_COLLAPSE_DELAY_MS)
        }
    }

    private fun cancelAutoCollapseTimer() {
        collapseHandler.removeCallbacks(collapseRunnable)
    }

    private fun snapToNearestEdge(currentWidth: Int) {
        val params = windowLayoutParams ?: return
        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val margin = dpToPx(12f)
        val targetX = if (params.x + currentWidth / 2 < screenWidth / 2) {
            margin
        } else {
            screenWidth - currentWidth - margin
        }

        ValueAnimator.ofInt(params.x, targetX).apply {
            duration = 220
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                params.x = anim.animatedValue as Int
                try {
                    windowManager?.updateViewLayout(rootView, params)
                } catch (_: Exception) {}
            }
            start()
        }
    }

    private fun togglePlayPause() {
        val nextRunningState = !isRunning
        isRunning = nextRunningState

        val actionIntent = Intent(this, AreteNotificationActionReceiver::class.java).apply {
            action = if (nextRunningState) {
                AreteNotificationHelper.ACTION_FOCUS_RESUME
            } else {
                AreteNotificationHelper.ACTION_FOCUS_PAUSE
            }
        }
        sendBroadcast(actionIntent)
        MainActivity.sendTimerAction(if (nextRunningState) "resume" else "pause")

        updateUiState()
    }

    private fun openApp() {
        cancelAutoCollapseTimer()
        hideDismissTarget()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("action", "open_focus_view")
        }
        if (launchIntent != null) {
            startActivity(launchIntent)
        }
        MainActivity.sendTimerAction("open_focus_view")
        hide(this)
    }

    private fun updateUiState() {
        val bubble = bubbleView ?: return
        val text = timerTextView ?: return
        val icon = playPauseIcon ?: return
        val badge = lightningBadgeView ?: return
        val capsule = capsuleContainer ?: return
        val playBtn = playPauseBtn ?: return

        val progress = if (totalSeconds > 0) {
            (remainingSeconds.toFloat() / totalSeconds.toFloat()).coerceIn(0f, 1f)
        } else 1.0f

        // 1. Update Elevated Electric Micro Circular Bubble
        bubble.isBreak = isBreak
        bubble.isTimerActive = isRunning
        bubble.progress = progress
        bubble.timeText = formatBubbleTime(remainingSeconds)

        // 2. Update Luxury Translucent Pill Capsule (Material You Glass Container)
        val textColor = if (isBreak) Color.parseColor("#2A1604") else Color.parseColor("#082112")
        val borderColor = if (isBreak) Color.argb(160, 251, 146, 60) else Color.argb(160, 163, 212, 171)
        val playBtnBg = if (isBreak) Color.argb(230, 254, 215, 170) else Color.argb(230, 184, 221, 190)
        val playBtnBorder = if (isBreak) Color.argb(180, 253, 186, 116) else Color.argb(180, 158, 207, 167)

        // Translucent gradient fill
        capsule.background = GradientDrawable(
            GradientDrawable.Orientation.TOP_BOTTOM,
            if (isBreak) {
                intArrayOf(Color.argb(215, 255, 247, 237), Color.argb(225, 254, 222, 186))
            } else {
                intArrayOf(Color.argb(215, 236, 248, 238), Color.argb(225, 202, 234, 208))
            }
        ).apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dpToPx(9999f).toFloat()
            setStroke(dpToPx(1.3f), borderColor)
        }

        // Update Lightning Badge
        badge.isBreak = isBreak
        badge.invalidate()
        if (isRunning) {
            if (badge.animation == null) {
                val anim = AlphaAnimation(1.0f, 0.45f).apply {
                    duration = 900
                    repeatMode = Animation.REVERSE
                    repeatCount = Animation.INFINITE
                }
                badge.startAnimation(anim)
            }
        } else {
            badge.clearAnimation()
            badge.alpha = 0.6f
        }

        // Center Display Digits
        text.text = formatPillTime(remainingSeconds)
        text.setTextColor(textColor)

        // Circular Play/Pause Button Disc
        playBtn.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(playBtnBg)
            setStroke(dpToPx(1f), playBtnBorder)
        }

        icon.setImageResource(
            if (isRunning) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        )
        icon.setColorFilter(textColor)
    }

    private fun removeOverlayView() {
        cancelAutoCollapseTimer()
        hideDismissTarget()
        if (dismissTargetView != null && windowManager != null) {
            try {
                windowManager?.removeView(dismissTargetView)
            } catch (_: Exception) {}
            dismissTargetView = null
            dismissCrossView = null
        }
        if (rootView != null && windowManager != null) {
            try {
                windowManager?.removeView(rootView)
            } catch (_: Exception) {}
            rootView = null
            bubbleView = null
            capsuleContainer = null
            lightningBadgeView = null
            timerTextView = null
            playPauseBtn = null
            playPauseIcon = null
            isOverlayShowing = false
        }
    }

    override fun onDestroy() {
        cancelAutoCollapseTimer()
        removeOverlayView()
        super.onDestroy()
    }

    /**
     * Custom View for the Stage 1 Electric Lightning Micro Circular Bubble (~44dp x 44dp).
     *
     * Aesthetic Features:
     * - Translucent Frosted Glass Lens gradient fill (70-78% alpha) with specular white rim.
     * - Refined 3.2dp animated progress ring with luminous dual-tone SweepGradient.
     * - 3D embossed Electric Amber Gold lightning bolt (⚡).
     * - High-contrast bold tabular digits ("59m") in deep obsidian forest (#082112).
     * - Soft ambient elevation shadow (0 6px 20px rgba(0,0,0,0.18)).
     */
    inner class CircularProgressBubbleView(context: Context) : View(context) {

        private val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
        }

        private val progressPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
        }

        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }

        private val specularPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
        }

        private val boltPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            isAntiAlias = true
        }

        private val boltShadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
            isAntiAlias = true
        }

        private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            isAntiAlias = true
        }

        private val arcRect = RectF()
        private val lightningPath = Path()
        private val boltShadowPath = Path()
        private val gradientMatrix = Matrix()

        var progress: Float = 1.0f
            set(value) {
                field = value.coerceIn(0f, 1f)
                invalidate()
            }

        var timeText: String = "59m"
            set(value) {
                field = value
                invalidate()
            }

        var isBreak: Boolean = false
            set(value) {
                field = value
                invalidate()
            }

        var isTimerActive: Boolean = true
            set(value) {
                field = value
                invalidate()
            }

        init {
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    outline.setOval(0, 0, maxOf(1, view.width), maxOf(1, view.height))
                }
            }
            elevation = dpToPx(12f).toFloat()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                outlineAmbientShadowColor = Color.parseColor("#38000000")
                outlineSpotShadowColor = Color.parseColor("#48000000")
            }
        }

        override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
            val size = dpToPx(44f)
            setMeasuredDimension(size, size)
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            if (w <= 0f || h <= 0f) return

            val cx = w / 2f
            val cy = h / 2f

            // Refined progress ring stroke-width = 3.2dp
            val strokeWidth = dpToPx(3.2f).toFloat()
            trackPaint.strokeWidth = strokeWidth
            progressPaint.strokeWidth = strokeWidth

            val radius = (minOf(w, h) - strokeWidth) / 2f
            val innerRadius = radius - strokeWidth / 2f

            // 1. Draw Translucent Frosted Glass Lens Base (70-78% alpha, wallpaper softly shows through)
            val topColor = if (isBreak) Color.argb(175, 255, 248, 238) else Color.argb(175, 235, 248, 238)
            val bottomColor = if (isBreak) Color.argb(195, 254, 222, 185) else Color.argb(195, 202, 232, 208)
            bgPaint.shader = LinearGradient(
                cx, cy - innerRadius, cx, cy + innerRadius,
                topColor, bottomColor,
                Shader.TileMode.CLAMP
            )
            canvas.drawCircle(cx, cy, innerRadius, bgPaint)

            // 2. Draw Specular White Glass Rim Highlight (delicate optical reflection)
            specularPaint.color = Color.argb(170, 255, 255, 255)
            specularPaint.strokeWidth = dpToPx(1.0f).toFloat()
            canvas.drawCircle(cx, cy, innerRadius - dpToPx(0.5f).toFloat(), specularPaint)

            // 3. Draw Outer Translucent Track Ring
            trackPaint.color = if (isBreak) Color.argb(85, 254, 215, 170) else Color.argb(85, 163, 212, 171)
            canvas.drawCircle(cx, cy, radius, trackPaint)

            // 4. Draw Outer Active Progress Arc with Luminous SweepGradient
            val gradientColors = if (isBreak) {
                intArrayOf(
                    Color.parseColor("#D97706"),
                    Color.parseColor("#F59E0B"),
                    Color.parseColor("#FBBF24"),
                    Color.parseColor("#B45309"),
                    Color.parseColor("#D97706")
                )
            } else {
                intArrayOf(
                    Color.parseColor("#059669"),
                    Color.parseColor("#10B981"),
                    Color.parseColor("#34D399"),
                    Color.parseColor("#047857"),
                    Color.parseColor("#059669")
                )
            }
            val sweepGradient = SweepGradient(cx, cy, gradientColors, null)
            gradientMatrix.setRotate(-90f, cx, cy)
            sweepGradient.setLocalMatrix(gradientMatrix)
            progressPaint.shader = sweepGradient

            arcRect.set(cx - radius, cy - radius, cx + radius, cy + radius)
            val sweepAngle = 360f * progress
            if (sweepAngle > 0.5f) {
                canvas.drawArc(arcRect, -90f, sweepAngle, false, progressPaint)
            }

            // 5. Draw 3D Embossed Electric Amber Lightning Bolt (⚡)
            val boltCenterY = cy - dpToPx(4.5f).toFloat()
            val s = dpToPx(1.05f).toFloat()

            // Subtle Bevel Shadow under bolt
            boltShadowPath.reset()
            val sy = boltCenterY + dpToPx(0.7f).toFloat()
            boltShadowPath.moveTo(cx + 0.85f * s, sy - 4.6f * s)
            boltShadowPath.lineTo(cx - 3.2f * s, sy - 0.2f * s)
            boltShadowPath.lineTo(cx - 0.4f * s, sy - 0.2f * s)
            boltShadowPath.lineTo(cx - 1.2f * s, sy + 4.6f * s)
            boltShadowPath.lineTo(cx + 2.9f * s, sy + 0.2f * s)
            boltShadowPath.lineTo(cx + 0.2f * s, sy + 0.2f * s)
            boltShadowPath.close()

            boltShadowPaint.color = if (isBreak) Color.parseColor("#7C2D12") else Color.parseColor("#14532D")
            boltShadowPaint.alpha = if (isTimerActive) 75 else 40
            canvas.drawPath(boltShadowPath, boltShadowPaint)

            // Main Electric Lightning Bolt
            lightningPath.reset()
            lightningPath.moveTo(cx + 0.85f * s, boltCenterY - 4.6f * s)
            lightningPath.lineTo(cx - 3.2f * s, boltCenterY - 0.2f * s)
            lightningPath.lineTo(cx - 0.4f * s, boltCenterY - 0.2f * s)
            lightningPath.lineTo(cx - 1.2f * s, boltCenterY + 4.6f * s)
            lightningPath.lineTo(cx + 2.9f * s, boltCenterY + 0.2f * s)
            lightningPath.lineTo(cx + 0.2f * s, boltCenterY + 0.2f * s)
            lightningPath.close()

            val boltColor = if (isBreak) Color.parseColor("#EA580C") else Color.parseColor("#F59E0B")
            boltPaint.color = boltColor
            boltPaint.alpha = if (isTimerActive) 255 else 180
            canvas.drawPath(lightningPath, boltPaint)

            // 6. Draw Crisp High-Contrast Bold Countdown Digits
            val textColor = if (isBreak) Color.parseColor("#2A1604") else Color.parseColor("#082112")
            textPaint.color = textColor
            textPaint.textSize = dpToPx(10.5f).toFloat()
            textPaint.alpha = if (isTimerActive) 255 else 190

            val textY = cy + dpToPx(8.2f).toFloat()
            canvas.drawText(timeText, cx, textY, textPaint)
        }
    }

    /**
     * Micro Circular Badge View for the Expanded Pill (left icon).
     */
    inner class MicroLightningBadgeView(context: Context) : View(context) {
        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
        private val boltPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL; isAntiAlias = true }
        private val boltPath = Path()
        var isBreak: Boolean = false

        override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
            val s = dpToPx(24f)
            setMeasuredDimension(s, s)
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            val cx = w / 2f
            val cy = h / 2f
            val r = minOf(w, h) / 2f - dpToPx(1f).toFloat()

            // Badge Background
            bgPaint.color = if (isBreak) Color.argb(220, 255, 237, 213) else Color.argb(220, 220, 252, 231)
            strokePaint.color = if (isBreak) Color.argb(180, 254, 215, 170) else Color.argb(180, 187, 247, 208)
            strokePaint.strokeWidth = dpToPx(1.2f).toFloat()
            canvas.drawCircle(cx, cy, r, bgPaint)
            canvas.drawCircle(cx, cy, r, strokePaint)

            // Micro Lightning Bolt (⚡)
            val scale = dpToPx(0.85f).toFloat()
            boltPath.reset()
            boltPath.moveTo(cx + 0.7f * scale, cy - 3.8f * scale)
            boltPath.lineTo(cx - 2.5f * scale, cy - 0.2f * scale)
            boltPath.lineTo(cx - 0.3f * scale, cy - 0.2f * scale)
            boltPath.lineTo(cx - 0.9f * scale, cy + 3.8f * scale)
            boltPath.lineTo(cx + 2.3f * scale, cy + 0.2f * scale)
            boltPath.lineTo(cx + 0.2f * scale, cy + 0.2f * scale)
            boltPath.close()

            boltPaint.color = if (isBreak) Color.parseColor("#EA580C") else Color.parseColor("#F59E0B")
            canvas.drawPath(boltPath, boltPaint)
        }
    }

    /**
     * Native Bottom-Center Dismiss Target ("✕" Cross).
     *
     * Appears during bubble/pill dragging and highlights in Coral Red (#E11D48)
     * with haptic feedback when the bubble is dragged over it.
     */
    inner class DismissCrossTargetView(context: Context) : View(context) {
        private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
        private val crossPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            color = Color.WHITE
        }

        var isDropTargetHovered: Boolean = false
            set(value) {
                if (field != value) {
                    field = value
                    invalidate()
                }
            }

        init {
            outlineProvider = object : ViewOutlineProvider() {
                override fun getOutline(view: View, outline: Outline) {
                    outline.setOval(0, 0, maxOf(1, view.width), maxOf(1, view.height))
                }
            }
            elevation = dpToPx(16f).toFloat()
        }

        override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
            val s = dpToPx(56f)
            setMeasuredDimension(s, s)
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val w = width.toFloat()
            val h = height.toFloat()
            val cx = w / 2f
            val cy = h / 2f
            val radius = minOf(w, h) / 2f - dpToPx(2f).toFloat()

            // Normal Dark Translucent vs Hovered Vibrant Crimson Red
            if (isDropTargetHovered) {
                bgPaint.color = Color.parseColor("#E11D48") // Vibrant Red
                strokePaint.color = Color.parseColor("#FDA4AF")
            } else {
                bgPaint.color = Color.argb(210, 24, 36, 28) // Translucent Dark Charcoal
                strokePaint.color = Color.argb(70, 255, 255, 255)
            }
            strokePaint.strokeWidth = dpToPx(1.5f).toFloat()

            canvas.drawCircle(cx, cy, radius, bgPaint)
            canvas.drawCircle(cx, cy, radius, strokePaint)

            // Draw crisp "✕" Cross
            val arm = dpToPx(9f).toFloat()
            crossPaint.strokeWidth = dpToPx(2.5f).toFloat()

            canvas.drawLine(cx - arm, cy - arm, cx + arm, cy + arm, crossPaint)
            canvas.drawLine(cx - arm, cy + arm, cx + arm, cy - arm, crossPaint)
        }
    }
}
