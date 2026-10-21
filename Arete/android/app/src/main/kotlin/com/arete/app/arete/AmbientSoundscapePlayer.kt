package com.arete.app.arete

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.Random

object AmbientSoundscapePlayer {
    private var audioTrack: AudioTrack? = null
    @Volatile private var isPlaying = false
    @Volatile private var currentType: String? = null
    @Volatile private var currentVolume = 0.6f
    private const val sampleRate = 22050
    private var workerThread: Thread? = null

    @Synchronized
    fun play(type: String, volume: Float = 0.6f) {
        stop()
        currentVolume = volume.coerceIn(0f, 1f)
        currentType = type
        isPlaying = true

        val bufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(4096)

        try {
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            audioTrack?.setVolume(currentVolume)
            audioTrack?.play()

            workerThread = Thread {
                val random = Random()
                val shortBuffer = ShortArray(bufferSize / 2)
                var lastSample = 0.0
                var phase = 0.0

                while (isPlaying) {
                    for (i in shortBuffer.indices) {
                        val raw = random.nextDouble() * 2.0 - 1.0 // -1.0 to 1.0
                        val sample = when (currentType) {
                            "rain" -> {
                                // Pink/brown filtered noise with random droplet impulses
                                lastSample = (lastSample * 0.94) + (raw * 0.06)
                                var s = lastSample * 2.5
                                if (random.nextInt(1200) == 0) {
                                    s += (random.nextDouble() - 0.5) * 1.5
                                }
                                s.coerceIn(-1.0, 1.0)
                            }
                            "forest" -> {
                                // Gentle oscillating wind canopy breeze
                                phase += 0.0003
                                val windMod = 0.35 + 0.65 * Math.sin(phase)
                                lastSample = (lastSample * 0.96) + (raw * 0.04)
                                (lastSample * 2.3 * windMod).coerceIn(-1.0, 1.0)
                            }
                            "cafe" -> {
                                // Low frequency warm chatter/rumble
                                lastSample = (lastSample * 0.98) + (raw * 0.02)
                                (lastSample * 3.2).coerceIn(-1.0, 1.0)
                            }
                            else -> { // white noise
                                raw * 0.35
                            }
                        }
                        shortBuffer[i] = (sample * 32767).toInt().toShort()
                    }
                    audioTrack?.write(shortBuffer, 0, shortBuffer.size)
                }
            }.apply {
                isDaemon = true
                priority = Thread.MIN_PRIORITY + 1
                start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            stop()
        }
    }

    @Synchronized
    fun setVolume(volume: Float) {
        currentVolume = volume.coerceIn(0f, 1f)
        try {
            audioTrack?.setVolume(currentVolume)
        } catch (_: Exception) {}
    }

    @Synchronized
    fun stop() {
        isPlaying = false
        try {
            workerThread?.interrupt()
        } catch (_: Exception) {}
        workerThread = null

        try {
            audioTrack?.stop()
            audioTrack?.release()
        } catch (_: Exception) {}
        audioTrack = null
        currentType = null
    }

    fun isPlaying(): Boolean = isPlaying
    fun getCurrentType(): String? = currentType
}
