package com.example.customer_emi_app

import android.app.WallpaperManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.BitmapDrawable
import android.util.Log
import java.io.File
import java.io.FileOutputStream

class WallpaperReceiver : BroadcastReceiver() {
    private val TAG = "WallpaperReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "Received action: $action")

        if (action == "com.example.customer_emi_app.SET_WALLPAPER") {
            val filePath = intent.getStringExtra("filePath")
            if (filePath != null) {
                setWallpaper(context, filePath)
            } else {
                Log.e(TAG, "filePath is null")
            }
        } else if (action == "com.example.customer_emi_app.RESET_WALLPAPER") {
            resetWallpaper(context)
        }
    }

    private fun setWallpaper(context: Context, filePath: String) {
        try {
            val wallpaperManager = WallpaperManager.getInstance(context)
            
            // Backup current wallpaper if original_wallpaper.jpg doesn't exist
            val backupFile = File(context.filesDir, "original_wallpaper.jpg")
            if (!backupFile.exists()) {
                val drawable = wallpaperManager.drawable
                if (drawable is BitmapDrawable) {
                    val bitmap = drawable.bitmap
                    val out = FileOutputStream(backupFile)
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 90, out)
                    out.flush()
                    out.close()
                    Log.d(TAG, "Backed up current wallpaper to ${backupFile.absolutePath}")
                }
            }

            val bitmap = BitmapFactory.decodeFile(filePath)
            if (bitmap != null) {
                wallpaperManager.setBitmap(bitmap)
                Log.d(TAG, "Successfully set new wallpaper from $filePath")
            } else {
                Log.e(TAG, "Could not decode image at $filePath")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting wallpaper", e)
        }
    }

    private fun resetWallpaper(context: Context) {
        try {
            val wallpaperManager = WallpaperManager.getInstance(context)
            val backupFile = File(context.filesDir, "original_wallpaper.jpg")
            
            if (backupFile.exists()) {
                val bitmap = BitmapFactory.decodeFile(backupFile.absolutePath)
                if (bitmap != null) {
                    wallpaperManager.setBitmap(bitmap)
                    Log.d(TAG, "Restored original wallpaper")
                    backupFile.delete() // Clean up after restore
                }
            } else {
                // If no backup exists, we can clear to system default
                wallpaperManager.clear()
                Log.d(TAG, "Cleared wallpaper to system default")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error resetting wallpaper", e)
        }
    }
}
