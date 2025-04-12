package com.tojkuv.lifesignal

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.Firebase
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.firestore
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d("FCM", "New FCM token: $token")

        val currentUser = FirebaseAuth.getInstance().currentUser
        if (currentUser != null) {
            Firebase.firestore.collection("users")
                .document(currentUser.uid)
                .update("fcmToken", token)
                .addOnSuccessListener {
                    Log.d("FCM", "Token successfully updated in Firestore")
                }
                .addOnFailureListener { e ->
                    Log.w("FCM", "Failed to update token in Firestore", e)
                }
        } else {
            Log.w("FCM", "User not authenticated — token not saved")
        }
    }


    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d("FCM", "Message received")

        remoteMessage.data.takeIf { it.isNotEmpty() }?.let {
            Log.d("FCM", "Data: $it")
        }

        remoteMessage.notification?.let { notification ->
            val title = notification.title ?: "Notification"
            val body = notification.body ?: "You have a message"
            Log.d("FCM", "Notification Title: $title")
            Log.d("FCM", "Notification Body: $body")

            showLocalNotification(title, body)
        }
    }

    private fun showLocalNotification(title: String, body: String) {
        val channelId = "default_channel"
        val notificationId = 1

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Default Channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.life_signal_logo)
            .setAutoCancel(true)
            .build()

        manager.notify(notificationId, notification)
    }
}
