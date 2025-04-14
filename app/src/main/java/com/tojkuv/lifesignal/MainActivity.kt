﻿package com.tojkuv.lifesignal

// Android platform
import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentUris
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.util.Log
import android.widget.Toast

// AndroidX - Activity & Compose
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts

// CameraX
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview as CameraPreview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView

// Compose UI
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.Sms
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf


// Core utilities
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

// Lifecycle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel

// Navigation
import androidx.navigation.compose.*
import com.google.firebase.FirebaseException
import com.google.firebase.FirebaseTooManyRequestsException
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseAuthInvalidCredentialsException
import com.google.firebase.auth.FirebaseAuthMissingActivityForRecaptchaException
import com.google.firebase.auth.PhoneAuthCredential
import com.google.firebase.auth.PhoneAuthOptions
import com.google.firebase.auth.PhoneAuthProvider
import com.google.firebase.firestore.DocumentReference
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ktx.firestore
import com.google.firebase.ktx.Firebase
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.functions.FirebaseFunctions


// ML Kit
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.common.InputImage

// Project-specific
import com.tojkuv.lifesignal.ui.theme.LifeSignalTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.util.concurrent.TimeUnit
import com.google.i18n.phonenumbers.PhoneNumberUtil
import com.google.i18n.phonenumbers.NumberParseException
import kotlinx.coroutines.tasks.await
import java.util.Date
import java.util.UUID
import androidx.core.content.edit
import com.google.firebase.firestore.SetOptions
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import androidx.core.graphics.createBitmap
import androidx.core.graphics.set
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import coil.compose.rememberAsyncImagePainter
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import java.io.File
import java.io.FileOutputStream
import java.util.Locale
import androidx.core.net.toUri

@JvmInline
value class Phone(val number: String) {

    fun isValid(region: String = "US"): Boolean {
        return try {
            val parsed = util.parse(number, region)
            util.isValidNumber(parsed)
        } catch (_: Exception) {
            false
        }
    }

    fun format(region: String = "US"): String? {
        return try {
            val parsed = util.parse(number, region)
            val numberRegion = util.getRegionCodeForNumber(parsed)

            val format = when {
                numberRegion == region -> PhoneNumberUtil.PhoneNumberFormat.NATIONAL
                else -> PhoneNumberUtil.PhoneNumberFormat.INTERNATIONAL
            }

            util.format(parsed, format)
        } catch (_: NumberParseException) {
            null
        }
    }

    companion object {
        private val util = PhoneNumberUtil.getInstance()
    }
}



data class UserProfile(
    val name: String = "",
    val phoneNumber: String = "",
    val phoneRegion: String = "",
    val note: String = "",
    val checkInInterval: Long = 24 * 60 * 60 * 1000L,
    val lastCheckedIn: Timestamp = Timestamp.now(),
    val checkInExpiration: Timestamp,
    val contacts: List<ContactRef> = emptyList(),
    val notify30MinBefore: Boolean = true,
    val notify2HoursBefore: Boolean = true,
    val qrCodeId: String = "",
    val sessionId: String = "",
    val fcmToken: String = ""
) {
    val phone: Phone
        get() = Phone(phoneNumber)
}


class UserViewModel : ViewModel() {
    private val auth = FirebaseAuth.getInstance()
    private val db = FirebaseFirestore.getInstance()

    private val _profile = MutableStateFlow<UserProfile?>(null)
    val profile: StateFlow<UserProfile?> = _profile

    fun loadUserProfile() {
        val uid = auth.currentUser?.uid
        Log.d("UserViewModel", "UID: $uid")

        if (uid == null) {
            Log.e("UserViewModel", "No authenticated user")
            return
        }

        viewModelScope.launch {
            try {
                val snapshot = db.collection("users").document(uid).get().await()
                Log.d("UserViewModel", "Document exists: ${snapshot.exists()}")

                if (snapshot.exists()) {
                    val name = snapshot.getString("name") ?: ""
                    val phoneNumber = snapshot.getString("phoneNumber") ?: ""
                    val phoneRegion = snapshot.getString("phoneRegion") ?: "US"
                    val note = snapshot.getString("note") ?: ""
                    val intervalMillis = snapshot.getLong("checkInInterval") ?: 86400000L
                    val lastCheckedIn = snapshot.getTimestamp("lastCheckedIn") ?: Timestamp.now()
                    val checkInExpiration = Timestamp(Date(lastCheckedIn.toDate().time + intervalMillis))
                    val sessionId = snapshot.getString("sessionId") ?: ""
                    val fcmToken = snapshot.getString("fcmToken") ?: ""
                    val notify30 = snapshot.getBoolean("notify30MinBefore") ?: true
                    val notify2hr = snapshot.getBoolean("notify2HoursBefore") ?: true
                    val qrCodeId = snapshot.getString("qrCodeId") ?: ""

                    val contactsRefs = mutableListOf<ContactRef>()
                    val rawContacts: List<Any?> = snapshot.get("contacts") as? List<*> ?: emptyList()

                    for (raw in rawContacts) {
                        val map = raw as? Map<*, *> ?: continue
                        val ref = map["reference"] as? DocumentReference ?: continue
                        val isResponder = map["isResponder"] as? Boolean ?: false
                        val isDependent = map["isDependent"] as? Boolean ?: false
                        contactsRefs.add(ContactRef(ref, isResponder, isDependent))
                    }

                    val profile = UserProfile(
                        name = name,
                        phoneNumber = phoneNumber,
                        phoneRegion = phoneRegion,
                        note = note,
                        checkInInterval = intervalMillis,
                        lastCheckedIn = lastCheckedIn,
                        checkInExpiration = checkInExpiration,
                        contacts = contactsRefs,
                        notify30MinBefore = notify30,
                        notify2HoursBefore = notify2hr,
                        qrCodeId = qrCodeId,
                        sessionId = sessionId,
                        fcmToken = fcmToken
                    )

                    Log.d("UserViewModel", "Profile parsed: $profile")
                    _profile.value = profile
                }
            } catch (e: Exception) {
                Log.e("UserViewModel", "Failed to load user profile", e)
            }
        }
    }

    fun updateNote(newNote: String) {
        updateProfile { it.copy(note = newNote) }
    }

    fun updateName(newName: String) {
        updateProfile { it.copy(name = newName) }
    }

    fun updatePhoneNumber(newNumber: String) {
        updateProfile { it.copy(phoneNumber = newNumber) }
    }

    fun updatePhoneRegion(newRegion: String) {
        updateProfile { it.copy(phoneRegion = newRegion) }
    }

    fun updateCheckInInterval(intervalMillis: Long) {
        updateProfile { profile ->
            val newExpiration = Timestamp(Date(profile.lastCheckedIn.toDate().time + intervalMillis))
            profile.copy(
                checkInInterval = intervalMillis,
                checkInExpiration = newExpiration
            )
        }
    }

    fun updateLastCheckedIn(now: Timestamp = Timestamp.now()) {
        updateProfile { profile ->
            val newExpiration = Timestamp(Date(now.toDate().time + profile.checkInInterval))
            profile.copy(
                lastCheckedIn = now,
                checkInExpiration = newExpiration
            )
        }
    }

    fun updateContacts(newContacts: List<ContactRef>) {
        updateProfile { it.copy(contacts = newContacts) }
    }

    fun updateNotificationPreference(key: String, value: Boolean) {
        updateProfile { profile ->
            when (key) {
                "notify30MinBefore" -> profile.copy(notify30MinBefore = value)
                "notify2HoursBefore" -> profile.copy(notify2HoursBefore = value)
                else -> profile
            }
        }
    }

    fun deleteContactReferencesFromUserAndContact(contactReference: DocumentReference) {
        val uid = auth.currentUser?.uid ?: return
        val currentUserRef = db.collection("users").document(uid)
        val functions = FirebaseFunctions.getInstance("us-central1")

        viewModelScope.launch {
            try {
                val data = mapOf(
                    "userARefPath" to currentUserRef.path,
                    "userBRefPath" to contactReference.path
                )

                functions
                    .getHttpsCallable("deleteContactRelation")
                    .call(data)
                    .await()

                val profile = _profile.value
                _profile.value = profile?.copy(
                    contacts = profile.contacts.filterNot { it.reference.path == contactReference.path }
                )

            } catch (e: Exception) {
                Log.e("UserViewModel", "Failed to delete contact via function", e)
            }
        }
    }


    fun generateAndSaveQRCodeId() {
        updateProfile { profile ->
            profile.copy(qrCodeId = UUID.randomUUID().toString())
        }
    }

    fun addQrContact(
        qrCodeId: String,
        isResponder: Boolean,
        isDependent: Boolean,
        context: Context,
        onSuccess: () -> Unit = {},
        onError: (Exception) -> Unit = {}
    ) {
        val user = auth.currentUser ?: return
        val userRef = db.collection("users").document(user.uid)

        viewModelScope.launch {
            try {
                val contactRef = db.collection("users")
                    .whereEqualTo("qrCodeId", qrCodeId)
                    .limit(1)
                    .get()
                    .await()
                    .documents
                    .firstOrNull()
                    ?.reference ?: return@launch

                val alreadyExists = _profile.value?.contacts?.any {
                    it.reference.path == contactRef.path
                } == true

                if (alreadyExists) {
                    Toast.makeText(context, "Contact already exists", Toast.LENGTH_SHORT).show()
                    return@launch
                }

                FirebaseFunctions.getInstance("us-central1")
                    .getHttpsCallable("addContactRelation")
                    .call(
                        mapOf(
                            "userRefPath" to userRef.path,
                            "contactRefPath" to contactRef.path,
                            "isResponder" to isResponder,
                            "isDependent" to isDependent
                        )
                    ).await()

                _profile.value = _profile.value?.copy(
                    contacts = _profile.value?.contacts?.plus(
                        ContactRef(contactRef, isResponder, isDependent)
                    ) ?: listOf(ContactRef(contactRef, isResponder, isDependent))
                )

                onSuccess()
            } catch (e: Exception) {
                Log.e("UserViewModel", "Failed to add contact via QR", e)
                onError(e)
            }
        }
    }

    private fun updateProfile(transform: (UserProfile) -> UserProfile) {
        val current = _profile.value ?: return
        val updated = transform(current)
        _profile.value = updated
        viewModelScope.launch {
            saveUserProfile(updated)
        }
    }

    suspend fun saveUserProfile(profile: UserProfile) {
        val uid = auth.currentUser?.uid ?: return

        val contactsData = profile.contacts.map {
            mapOf(
                "reference" to it.reference,
                "isResponder" to it.isResponder,
                "isDependent" to it.isDependent
            )
        }

        val data = mapOf(
            "name" to profile.name,
            "phoneNumber" to profile.phoneNumber,
            "phoneRegion" to profile.phoneRegion,
            "note" to profile.note,
            "checkInInterval" to profile.checkInInterval,
            "lastCheckedIn" to profile.lastCheckedIn,
            "checkInExpiration" to profile.checkInExpiration,
            "contacts" to contactsData,
            "notify30MinBefore" to profile.notify30MinBefore,
            "notify2HoursBefore" to profile.notify2HoursBefore,
            "qrCodeId" to profile.qrCodeId,
            "fcmToken" to profile.fcmToken,
            "sessionId" to profile.sessionId
        )

        db.collection("users")
            .document(uid)
            .set(data, SetOptions.merge())
            .await()
    }

    suspend fun resolveContact(contactRef: ContactRef): ResolvedContact? {
        return try {
            val snapshot = contactRef.reference.get().await()
            if (snapshot.exists()) {
                val name = snapshot.getString("name") ?: ""
                val phoneStr = snapshot.getString("phone") ?: ""
                val note = snapshot.getString("note") ?: ""
                val checkInInterval = snapshot.getLong("checkInInterval") ?: 86400000L
                val lastCheckedIn = snapshot.getTimestamp("lastCheckedIn") ?: Timestamp.now()

                ResolvedContact(
                    reference = contactRef.reference,
                    name = name,
                    phone = Phone(phoneStr),
                    note = note,
                    checkInInterval = checkInInterval,
                    lastCheckedIn = lastCheckedIn,
                    isResponder = contactRef.isResponder,
                    isDependent = contactRef.isDependent
                )
            } else null
        } catch (e: Exception) {
            Log.e("UserViewModel", "Failed to resolve contact", e)
            null
        }
    }
}

data class ContactRef(
    val reference: DocumentReference,
    val isResponder: Boolean,
    val isDependent: Boolean
)

class ResolvedContactsViewModel : ViewModel() {
    private val auth = FirebaseAuth.getInstance()
    private val db = FirebaseFirestore.getInstance()

    private val _resolvedContacts = MutableStateFlow<List<ResolvedContact>>(emptyList())
    val resolvedContacts: StateFlow<List<ResolvedContact>> = _resolvedContacts

    private val _selectedResolvedContact = mutableStateOf<ResolvedContact?>(null)
    val selectedResolvedContact: State<ResolvedContact?> = _selectedResolvedContact

    var scannedQrContent by mutableStateOf<String?>(null)
        private set

    fun setScannedQr(content: String) {
        scannedQrContent = content
    }

    fun select(contact: ResolvedContact) {
        _selectedResolvedContact.value = contact
        Log.d("ContactViewModel", "Selected: ${contact.name}")
    }

    fun clear() {
        _selectedResolvedContact.value = null
    }

    fun toggleResponder() {
        val contact = _selectedResolvedContact.value ?: return
        val updated = contact.copy(isResponder = !contact.isResponder)
        _selectedResolvedContact.value = updated
        updateFlagsInFirestore(updated)
    }

    fun toggleDependent() {
        val contact = _selectedResolvedContact.value ?: return
        val updated = contact.copy(isDependent = !contact.isDependent)
        _selectedResolvedContact.value = updated
        updateFlagsInFirestore(updated)
    }

    private fun updateFlagsInFirestore(contact: ResolvedContact) {
        val uid = auth.currentUser?.uid ?: return

        viewModelScope.launch {
            try {
                val userDocRef = db.collection("users").document(uid)
                val userSnap = userDocRef.get().await()
                val rawContacts = userSnap.get("contacts") as? List<*> ?: return@launch

                val updatedContacts = rawContacts.mapNotNull { map ->
                    if (map is Map<*, *>) {
                        val ref = map["reference"] as? DocumentReference
                        if (ref?.path == contact.reference.path) {
                            mapOf(
                                "reference" to ref,
                                "isResponder" to contact.isResponder,
                                "isDependent" to contact.isDependent
                            )
                        } else map
                    } else null
                }

                userDocRef.update("contacts", updatedContacts).await()
                Log.d("ContactViewModel", "Updated contact flags in Firestore")
            } catch (e: Exception) {
                Log.e("ContactViewModel", "Failed to update contact flags", e)
            }
        }
    }

    suspend fun loadAllResolvedContacts(contactRefs: List<ContactRef>) {
        val resolvedList = contactRefs.mapNotNull { ref ->
            try {
                val snapshot = ref.reference.get().await()
                if (!snapshot.exists()) return@mapNotNull null

                ResolvedContact(
                    reference = ref.reference,
                    name = snapshot.getString("name") ?: "",
                    phone = Phone(snapshot.getString("phone") ?: ""),
                    note = snapshot.getString("note") ?: "",
                    checkInInterval = snapshot.getLong("checkInInterval") ?: 86400000L,
                    lastCheckedIn = snapshot.getTimestamp("lastCheckedIn") ?: Timestamp.now(),
                    isResponder = ref.isResponder,
                    isDependent = ref.isDependent
                )
            } catch (e: Exception) {
                Log.e("ContactViewModel", "Failed to resolve contact ${ref.reference.path}", e)
                null
            }
        }

        _resolvedContacts.value = resolvedList
    }

    suspend fun refreshSelectedContact() {
        val current = _selectedResolvedContact.value ?: return

        try {
            val snap = current.reference.get().await()
            if (snap.exists()) {
                val refreshed = ResolvedContact(
                    reference = current.reference,
                    name = snap.getString("name") ?: "",
                    phone = Phone(snap.getString("phone") ?: ""),
                    note = snap.getString("note") ?: "",
                    checkInInterval = snap.getLong("checkInInterval") ?: 86400000L,
                    lastCheckedIn = snap.getTimestamp("lastCheckedIn") ?: Timestamp.now(),
                    isResponder = current.isResponder,
                    isDependent = current.isDependent
                )
                _selectedResolvedContact.value = refreshed
                Log.d("ContactViewModel", "Contact refreshed from Firestore")
            }
        } catch (e: Exception) {
            Log.e("ContactViewModel", "Failed to refresh contact", e)
        }
    }
}


data class ResolvedContact(
    val reference: DocumentReference,
    val name: String,
    val phone: Phone,
    val note: String,
    val checkInInterval: Long,
    val lastCheckedIn: Timestamp,
    val isResponder: Boolean,
    val isDependent: Boolean
) {
    val checkInExpiry: Timestamp
        get() = Timestamp(Date(lastCheckedIn.toDate().time + checkInInterval))
}



fun Context.findActivity(): Activity? {
    var ctx = this
    while (ctx is ContextWrapper) {
        if (ctx is Activity) return ctx
        ctx = ctx.baseContext
    }
    return null
}

class AuthViewModel : ViewModel() {

    private val firebaseAuth = FirebaseAuth.getInstance()

    var isLoading by mutableStateOf(false)
        private set

    var errorMessage by mutableStateOf<String?>(null)

    fun signInWithCredential(
        context: Context,
        credential: PhoneAuthCredential,
        onSuccess: () -> Unit
    ) {
        isLoading = true
        firebaseAuth.signInWithCredential(credential)
            .addOnCompleteListener { task ->
                isLoading = false
                if (task.isSuccessful) {
                    val user = firebaseAuth.currentUser
                    if (user != null) {
                        val sessionId = UUID.randomUUID().toString()
                        SessionManager.saveSessionId(context, sessionId)

                        Firebase.firestore.collection("users")
                            .document(user.uid)
                            .update(
                                mapOf(
                                    "sessionId" to sessionId,
                                    "lastLoginAt" to FieldValue.serverTimestamp()
                                )
                            )
                            .addOnSuccessListener {
                                Log.d("AUTH", "Session ID updated")
                            }
                            .addOnFailureListener {
                                Log.w("AUTH", "Failed to update session ID", it)
                            }
                    }

                    onSuccess()
                } else {
                    errorMessage = task.exception?.message ?: "Sign-in failed"
                }
            }
    }


    fun clearError() {
        errorMessage = null
    }
}

object SessionManager {

    private const val PREF_NAME = "user_session"

    fun saveSessionId(context: Context, sessionId: String) {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        prefs.edit() { putString("sessionId", sessionId) }
    }

    fun getSessionId(context: Context): String? {
        val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        return prefs.getString("sessionId", null)
    }

    fun validateSession(context: Context, onInvalid: () -> Unit) {
        val currentUser = FirebaseAuth.getInstance().currentUser ?: return
        val localSession = SessionManager.getSessionId(context)

        Firebase.firestore.collection("users")
            .document(currentUser.uid)
            .get()
            .addOnSuccessListener { doc ->
                val remoteSession = doc.getString("sessionId")
                if (remoteSession != localSession) {
                    FirebaseAuth.getInstance().signOut()
                    onInvalid()
                }
            }
    }

}



interface NavigationBarDestination {
    val icon: ImageVector
    val route: String
}

@Serializable
object HomeRoute : NavigationBarDestination {
    override val icon = Icons.Filled.Home
    override val route = "Home"
}

@Serializable
object RespondersRoute : NavigationBarDestination {
    override val icon = Icons.Filled.Groups
    override val route = "Responders"
}

@Serializable
object DependentsRoute : NavigationBarDestination {
    override val icon = Icons.Filled.Groups
    override val route = "Dependents"
}

@Serializable
object UserProfileRoute : NavigationBarDestination {
    override val icon = Icons.Filled.AccountCircle
    override val route = "Profile"
}

val navigationBarScreens = listOf(HomeRoute, RespondersRoute, DependentsRoute, UserProfileRoute)

class MainActivity : ComponentActivity() {
    var showLogin by mutableStateOf(FirebaseAuth.getInstance().currentUser == null)
        private set

    companion object {
        const val CHANNEL_ID = "lifesignal_timer_channel"
    }

    private var millisecondsLeft by mutableStateOf(24 * 60 * 60 * 1000L)
    var resetTrigger by mutableStateOf(0)

    private var storedVerificationId: String? = null
    private var resendToken: PhoneAuthProvider.ForceResendingToken? = null

    private var verificationInProgress = false
    private var lastPhoneNumber: String? = null

    private lateinit var verificationCallbacks: PhoneAuthProvider.OnVerificationStateChangedCallbacks

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = getString(R.string.channel_name)
            val descriptionText = getString(R.string.channel_description)
            val importance = NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager =
                getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    100
                )
            }
        }
    }

    private fun sendNotification(context: Context, textTitle: String, textContent: String) {
        val notificationId = (System.currentTimeMillis() % Int.MAX_VALUE).toInt()

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        if (ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) return

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.baseline_notifications_24)
            .setContentTitle(textTitle)
            .setContentText(textContent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        NotificationManagerCompat.from(context).notify(notificationId, builder.build())
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putBoolean("verification_in_progress", verificationInProgress)
        outState.putString("phone_number", lastPhoneNumber)
    }

    override fun onRestoreInstanceState(savedInstanceState: Bundle) {
        super.onRestoreInstanceState(savedInstanceState)
        verificationInProgress = savedInstanceState.getBoolean("verification_in_progress", false)
        lastPhoneNumber = savedInstanceState.getString("phone_number")
    }

    override fun onStart() {
        super.onStart()
        if (verificationInProgress && !lastPhoneNumber.isNullOrBlank()) {
            startPhoneVerification(
                phoneNumber = lastPhoneNumber!!,
                activity = this,
                onCodeSent = {},
                onError = {}
            )
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        verificationCallbacks = object : PhoneAuthProvider.OnVerificationStateChangedCallbacks() {

            override fun onVerificationCompleted(credential: PhoneAuthCredential) {
                verificationInProgress = false
                Log.d("PhoneAuth", "onVerificationCompleted:$credential")
                FirebaseAuth.getInstance().signInWithCredential(credential)
            }

            override fun onVerificationFailed(e: FirebaseException) {
                verificationInProgress = false
                Log.w("PhoneAuth", "onVerificationFailed", e)

                when (e) {
                    is FirebaseAuthInvalidCredentialsException -> {
                        Log.e("PhoneAuth", "Invalid request: ${e.message}")
                    }
                    is FirebaseTooManyRequestsException -> {
                        Log.e("PhoneAuth", "SMS quota exceeded: ${e.message}")
                    }
                    is FirebaseAuthMissingActivityForRecaptchaException -> {
                        Log.e("PhoneAuth", "Missing activity for reCAPTCHA flow: ${e.message}")
                    }
                    else -> {
                        Log.e("PhoneAuth", "Unknown error: ${e.message}")
                    }
                }
            }

            override fun onCodeSent(
                verificationId: String,
                token: PhoneAuthProvider.ForceResendingToken
            ) {
                Log.d("PhoneAuth", "onCodeSent:$verificationId")
                storedVerificationId = verificationId
                resendToken = token
            }

            override fun onCodeAutoRetrievalTimeOut(verificationId: String) {
                Log.d("PhoneAuth", "onCodeAutoRetrievalTimeOut:$verificationId")
                storedVerificationId = verificationId
            }
        }

        createNotificationChannel()
        requestNotificationPermission()
        enableEdgeToEdge()

        val user = FirebaseAuth.getInstance().currentUser

        if (user != null) {
            SessionManager.validateSession(this@MainActivity) {
                Log.w("AUTH", "Session invalid — logging out")
                FirebaseAuth.getInstance().signOut()
                showLogin = true
            }

            watchSession(user.uid)

            FirebaseMessaging.getInstance().token.addOnSuccessListener { token ->
                Firebase.firestore.collection("users")
                    .document(user.uid)
                    .update("fcmToken", token)
                    .addOnSuccessListener {
                        Log.d("FCM", "FCM token updated in Firestore")
                    }
                    .addOnFailureListener {
                        Log.w("FCM", "Failed to update FCM token", it)
                    }
            }
        } else {
            showLogin = true
        }

        setContent {
            val userViewModel: UserViewModel = viewModel()
            val userProfile by userViewModel.profile.collectAsState()
            var millisLeft by remember { mutableStateOf(0L) }

            LaunchedEffect(userProfile?.checkInExpiration, resetTrigger) {
                userProfile?.let { profile ->
                    while (true) {
                        val remaining = profile.checkInExpiration.toDate().time - System.currentTimeMillis()
                        millisLeft = remaining.coerceAtLeast(0)
                        if (millisLeft == 0L) {
                            sendNotification(
                                context = this@MainActivity,
                                textTitle = "Timer Expired",
                                textContent = "Please check in."
                            )
                            break
                        }
                        delay(1000L)
                    }
                }
            }

            LifeSignalApp(
                millisecondsLeft = millisLeft,
                userViewModel = userViewModel,
                showLogin = showLogin,
                onSignedIn = { showLogin = false }
            )
        }
    }

    private fun watchSession(uid: String) {
        Firebase.firestore.collection("users")
            .document(uid)
            .addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null || !snapshot.exists()) return@addSnapshotListener

                val remoteSession = snapshot.getString("sessionId")
                val localSession = SessionManager.getSessionId(this)

                if (remoteSession != localSession) {
                    FirebaseAuth.getInstance().signOut()
                    Toast.makeText(this, "You were signed out (session expired).", Toast.LENGTH_LONG).show()
                    showLogin = true
                    setContent {
                        LifeSignalApp(
                            millisecondsLeft = millisecondsLeft,
                            userViewModel = UserViewModel(),
                            showLogin = true,
                            onSignedIn = { showLogin = false }
                        )
                    }
                }
            }
    }

    fun startPhoneVerification(
        phoneNumber: String,
        activity: Activity,
        onCodeSent: (String) -> Unit,
        onError: (FirebaseException) -> Unit
    ) {
        lastPhoneNumber = phoneNumber
        verificationInProgress = true

        val options = PhoneAuthOptions.newBuilder(FirebaseAuth.getInstance())
            .setPhoneNumber(phoneNumber)
            .setTimeout(60L, TimeUnit.SECONDS)
            .setActivity(activity)
            .setCallbacks(verificationCallbacks)
            .build()

        PhoneAuthProvider.verifyPhoneNumber(options)
    }
}

@Composable
fun LifeSignalApp(
    millisecondsLeft: Long,
    userViewModel: UserViewModel,
    showLogin: Boolean,
    onSignedIn: () -> Unit,
    modifier: Modifier = Modifier
)
 {
    val navController = rememberNavController()
    val resolvedContactsViewModel: ResolvedContactsViewModel = viewModel()
    val userViewModel: UserViewModel = viewModel()
    val profile by userViewModel.profile.collectAsState()
    val isSignedIn = FirebaseAuth.getInstance().currentUser != null
    val activity = LocalContext.current.findActivity()
    val authState = FirebaseAuth.getInstance().currentUser

     LaunchedEffect(authState) {
         if (authState != null) {
             userViewModel.loadUserProfile()
         }
     }

     LifeSignalTheme {
        when {
            showLogin || authState == null -> {
                AuthNavHost(
                    onSignedIn = onSignedIn,
                    activity = activity!!,
                    signInWithCredential = { credential, onSuccess, onFailure ->
                        FirebaseAuth.getInstance().signInWithCredential(credential)
                            .addOnCompleteListener(activity) { task ->
                                if (task.isSuccessful) onSuccess()
                                else onFailure(task.exception?.message ?: "Sign-in failed")
                            }
                    }
                )
            }

            profile == null -> { }


            else -> {
                val user = profile
                if (user?.name.isNullOrBlank()) {
                    NameEntryScreen(
                        onSubmit = { name ->
                            userViewModel.updateName(name)
                        }
                    )
                } else {
                    Scaffold(
                        bottomBar = {
                            val currentBackStackEntry by navController.currentBackStackEntryAsState()
                            val currentRoute = currentBackStackEntry?.destination?.route

                            Surface(
                                tonalElevation = 0.dp,
                                color = MaterialTheme.colorScheme.surfaceVariant,
                                border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
                            ) {
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .background(MaterialTheme.colorScheme.surfaceVariant),
                                    verticalArrangement = Arrangement.Center,
                                    horizontalAlignment = Alignment.CenterHorizontally
                                ) {
                                    Spacer(Modifier.height(16.dp))

                                    Text("Check-in Time Left", style = MaterialTheme.typography.titleMedium)
                                    Text(formatCountdown(millisecondsLeft), style = MaterialTheme.typography.titleLarge)

                                    Spacer(Modifier.height(8.dp))

                                    NavigationBar(containerColor = MaterialTheme.colorScheme.surfaceVariant) {
                                        val total = navigationBarScreens.size
                                        val middleIndex = total / 2

                                        navigationBarScreens.forEachIndexed { index, screen ->
                                            if (index == middleIndex) {
                                                NavigationBarItem(
                                                    icon = { Icon(Icons.Default.MobileFriendly, contentDescription = "Check-In") },
                                                    label = {
                                                        Text(
                                                            "Check-in",
                                                            style = MaterialTheme.typography.labelSmall,
                                                            maxLines = 1,
                                                            overflow = TextOverflow.Ellipsis
                                                        )
                                                    },
                                                    selected = false,
                                                    onClick = {
                                                        userViewModel.updateLastCheckedIn()
                                                    }
                                                )
                                            }

                                            NavigationBarItem(
                                                icon = { Icon(screen.icon, contentDescription = screen.route) },
                                                label = {
                                                    Text(
                                                        screen.route,
                                                        style = MaterialTheme.typography.labelSmall,
                                                        maxLines = 1,
                                                        overflow = TextOverflow.Ellipsis
                                                    )
                                                },
                                                selected = currentRoute == screen.route,
                                                onClick = {
                                                    navController.navigate(screen.route) {
                                                        launchSingleTop = true
                                                        restoreState = true
                                                        popUpTo(screen.route) { inclusive = true }
                                                    }
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    ) { innerPadding ->
                        Box(modifier = Modifier.padding(innerPadding)) {
                            NavHost(navController = navController, startDestination = HomeRoute.route) {
                                composable(HomeRoute.route) {
                                    HomeScreen(
                                        onAddContactViaQrCode = {
                                            navController.navigate("qrScanner")
                                        },
                                        userViewModel = userViewModel
                                    )
                                }

                                composable(RespondersRoute.route) {
                                    LaunchedEffect(Unit) {
                                        userViewModel.loadUserProfile()
                                    }

                                    RespondersScreen(
                                        userViewModel = userViewModel,
                                        onContactClick = { contact ->
                                            resolvedContactsViewModel.select(contact)
                                            navController.navigate("contactDetail")
                                        }
                                    )
                                }

                                composable(DependentsRoute.route) {
                                    LaunchedEffect(Unit) {
                                        userViewModel.loadUserProfile()
                                    }

                                    DependentsScreen(
                                        userViewModel = userViewModel,
                                        onContactClick = { contact ->
                                            resolvedContactsViewModel.select(contact)
                                            navController.navigate("contactDetail")
                                        }
                                    )
                                }


                                composable("contactDetail") {
                                    val scope = rememberCoroutineScope()

                                    LaunchedEffect(Unit) {
                                        scope.launch {
                                            resolvedContactsViewModel.refreshSelectedContact()
                                        }
                                    }

                                    if (resolvedContactsViewModel.selectedResolvedContact.value != null) {
                                        ContactDetailScreen(
                                            userViewModel = userViewModel,
                                            resolvedContactsViewModel = resolvedContactsViewModel,
                                            onBack = { navController.popBackStack() }
                                        )
                                    }
                                }

                                composable(UserProfileRoute.route) {
                                    UserProfileScreen()
                                }


                                composable("qrScanner") {
                                    QRCodeScannerScreen(
                                        resolvedContactsViewModel = resolvedContactsViewModel,
                                        onBack = { navController.popBackStack() },
                                        onNavigateToAddContact = {
                                            navController.navigate("addContactViaQr") {
                                                popUpTo("qrScanner") { inclusive = true }
                                            }
                                        }
                                    )
                                }

                                composable("addContactViaQr") {
                                    val qrCodeId = resolvedContactsViewModel.scannedQrContent ?: ""

                                    AddContactViaQRCodeScreen(
                                        qrCodeId = qrCodeId,
                                        onBack = { navController.popBackStack() }
                                    )
                                }

                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun AuthNavHost(
    onSignedIn: () -> Unit,
    activity: Activity,
    signInWithCredential: (PhoneAuthCredential, () -> Unit, (String) -> Unit) -> Unit
) {
    val navController = rememberNavController()
    val viewModel: SignInViewModel = viewModel()

    NavHost(navController = navController, startDestination = AuthRoutes.Phone) {
        composable(AuthRoutes.Phone) {
            PhoneEntryScreen(
                viewModel = viewModel,
                activity = activity,
                onCodeSent = { navController.navigate(AuthRoutes.Code) }
            )
        }
        composable(AuthRoutes.Code) {
            CodeEntryScreen(
                viewModel = viewModel,
                onBack = { navController.popBackStack() },
                onSignedIn = onSignedIn,
                signInWithCredential = signInWithCredential
            )
        }
    }
}

object AuthRoutes {
    const val Phone = "auth/phone"
    const val Code = "auth/code"
}

class SignInViewModel : ViewModel() {
    var phone by mutableStateOf(Phone(""))
    var phoneText by mutableStateOf("")
    var region by mutableStateOf("US")
    var smsCode by mutableStateOf("")
    var verificationId by mutableStateOf<String?>(null)
    var errorMessage by mutableStateOf<String?>(null)
}

@Composable
fun PhoneEntryScreen(
    viewModel: SignInViewModel,
    activity: Activity,
    onCodeSent: () -> Unit
) {
    val fullPhoneNumber = "+${getAllRegions().first { it.code == viewModel.region }.dialCode.filter(Char::isDigit)}${viewModel.phoneText}"

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(Modifier.height(48.dp))

        Image(
            painter = painterResource(id = R.drawable.life_signal_logo),
            contentDescription = "App Logo",
            modifier = Modifier.size(100.dp)
        )

        Spacer(Modifier.height(24.dp))

        Text(
            text = "Welcome to LifeSignal",
            style = MaterialTheme.typography.headlineMedium,
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(32.dp))

        PhoneInput(
            phoneText = viewModel.phoneText,
            regionCode = viewModel.region,
            onValueChange = { digits, newPhone, newRegion ->
                viewModel.phoneText = digits
                viewModel.phone = newPhone
                viewModel.region = newRegion
            }
        )

        Spacer(Modifier.height(24.dp))

        val isValidNumber = viewModel.phone.isValid(viewModel.region) ||
                viewModel.phone.number == "+11234567890"

        Button(
            onClick = {
                startPhoneVerification(
                    phoneNumber = fullPhoneNumber,
                    activity = activity,
                    onCodeSent = { id ->
                        viewModel.verificationId = id
                        viewModel.smsCode = ""
                        viewModel.errorMessage = null
                        onCodeSent()
                    },
                    onError = { error ->
                        viewModel.errorMessage = error.message
                    }
                )
            },
            enabled = isValidNumber,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Send Code")
        }

        Spacer(Modifier.height(16.dp))

        viewModel.errorMessage?.let {
            Text(it, color = MaterialTheme.colorScheme.error)
        }

        Text(
            "You may receive an SMS for verification. Standard rates apply.",
            style = MaterialTheme.typography.bodySmall
        )
    }
}

data class Region(
    val code: String,
    val dialCode: String,
    val name: String,
    val flag: String
)


fun getAllRegions(): List<Region> {
    val util = PhoneNumberUtil.getInstance()

    return util.supportedRegions.mapNotNull { regionCode ->
        try {
            val dialCode = "+${util.getCountryCodeForRegion(regionCode)}"
            val name = Locale("", regionCode).displayCountry
            val flag = regionCode
                .uppercase()
                .map { it.code - 0x41 + 0x1F1E6 }
                .joinToString("") { Character.toChars(it).concatToString() }

            Region(
                code = regionCode,
                dialCode = dialCode,
                name = name,
                flag = flag
            )
        } catch (e: Exception) {
            null
        }
    }.sortedBy { it.name }
}


@OptIn(ExperimentalFoundationApi::class)
@Composable
fun PhoneInput(
    phoneText: String,
    regionCode: String,
    onValueChange: (String, Phone, regionCode: String) -> Unit
) {
    val regions = remember { getAllRegions() }
    var region by remember { mutableStateOf(regions.first { it.code == regionCode }) }
    var showDialog by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }
    var isPressed by remember { mutableStateOf(false) }

    val filteredRegions = regions.filter {
        it.name.contains(searchQuery, ignoreCase = true) ||
                it.code.contains(searchQuery, ignoreCase = true) ||
                it.dialCode.contains(searchQuery)
    }

    val e164 = "+${region.dialCode.filter(Char::isDigit)}$phoneText"
    val phone = Phone(e164)
    val isValid = phone.isValid(region.code)

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth()
    ) {
        OutlinedTextField(
            value = "${region.flag} ${region.dialCode}",
            onValueChange = {},
            readOnly = true,
            trailingIcon = {
                Icon(Icons.Default.ArrowDropDown, contentDescription = "Select Region")
            },
            modifier = Modifier
                .width(120.dp)
                .combinedClickable(
                    onClick = {
                        isPressed = true
                        showDialog = true
                    },
                    onClickLabel = "Open Region Picker",
                    onLongClick = null,
                ),
            shape = MaterialTheme.shapes.extraSmall,
            singleLine = true,
            enabled = false,
            label = { Text("Region") },
            colors = TextFieldDefaults.colors(
                disabledTextColor = LocalContentColor.current,
                disabledContainerColor = Color.Transparent,
                disabledIndicatorColor = if (isPressed)
                    MaterialTheme.colorScheme.primary
                else
                    MaterialTheme.colorScheme.outline,
                disabledTrailingIconColor = LocalContentColor.current,
                disabledLabelColor = LocalContentColor.current
            )
        )

        Spacer(Modifier.width(8.dp))

        var fieldValue by remember { mutableStateOf(TextFieldValue(text = phoneText)) }

        val phoneUtil = remember { PhoneNumberUtil.getInstance() }
        val maxLength = remember(region.code) {
            try {
                val example = phoneUtil.getExampleNumber(region.code)
                phoneUtil.getNationalSignificantNumber(example).length
            } catch (e: Exception) {
                15
            }
        }

        OutlinedTextField(
            value = fieldValue,
            onValueChange = { newValue ->
                val rawDigits = newValue.text.filter(Char::isDigit).take(maxLength)

                val formatted = try {
                    val formatter = PhoneNumberUtil.getInstance().getAsYouTypeFormatter(region.code)
                    formatter.clear()
                    rawDigits.fold("") { acc, c -> formatter.inputDigit(c) }
                } catch (_: Exception) {
                    rawDigits
                }

                fieldValue = TextFieldValue(
                    text = formatted,
                    selection = TextRange(formatted.length)
                )

                val fullNumber = "+${region.dialCode.filter(Char::isDigit)}$rawDigits"
                onValueChange(rawDigits, Phone(fullNumber), region.code)
            },
            label = { Text("Phone Number") },
            isError = phoneText.isNotBlank() && !isValid,
            trailingIcon = {
                if (phoneText.isNotBlank() && isValid) {
                    Icon(
                        Icons.Default.Check,
                        contentDescription = null,
                        tint = Color.Green
                    )
                }
            },
            keyboardOptions = KeyboardOptions.Default.copy(keyboardType = KeyboardType.Phone),
            singleLine = true,
            modifier = Modifier.weight(1f),
            colors = TextFieldDefaults.colors(
                focusedIndicatorColor = if (phoneText.isNotBlank() && !isValid) Color.Red else MaterialTheme.colorScheme.primary,
                unfocusedIndicatorColor = if (phoneText.isNotBlank() && !isValid) Color.Red else MaterialTheme.colorScheme.outline,
                cursorColor = MaterialTheme.colorScheme.primary
            )
        )
    }

    if (showDialog) {
        AlertDialog(
            onDismissRequest = { showDialog = false },
            title = { Text("Select Region") },
            text = {
                Column {
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        label = { Text("Search") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    Spacer(Modifier.height(8.dp))
                    LazyColumn(modifier = Modifier.heightIn(max = 300.dp)) {
                        items(filteredRegions) { r ->
                            Text(
                                text = "${r.flag} ${r.name} (${r.dialCode})",
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        region = r
                                        showDialog = false
                                        searchQuery = ""
                                        val fullNumber = "+${r.dialCode.filter(Char::isDigit)}$phoneText"
                                        onValueChange(phoneText, Phone(fullNumber), r.code)
                                    }
                                    .padding(8.dp)
                            )
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showDialog = false }) { Text("Cancel") }
            }
        )
    }
}

fun phoneVisualTransformation(regionCode: String): VisualTransformation {
    return VisualTransformation { text ->
        val nationalDigits = text.text.filter { it.isDigit() }

        val formatted = try {
            val formatter = PhoneNumberUtil.getInstance().getAsYouTypeFormatter(regionCode)
            nationalDigits.fold("") { acc, c -> formatter.inputDigit(c) }
        } catch (_: Exception) {
            nationalDigits
        }

        TransformedText(
            AnnotatedString(formatted),
            OffsetMapping.Identity
        )
    }
}


@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CodeEntryScreen(
    viewModel: SignInViewModel,
    onBack: () -> Unit,
    onSignedIn: () -> Unit,
    signInWithCredential: (PhoneAuthCredential, () -> Unit, (String) -> Unit) -> Unit
) {
    val CodeVisualTransformation = VisualTransformation { text ->
        val trimmed = text.text.take(6)
        val formatted = trimmed.chunked(3).joinToString(" ")
        val offsetMapping = object : OffsetMapping {
            override fun originalToTransformed(offset: Int): Int =
                if (offset <= 3) offset else offset + 1
            override fun transformedToOriginal(offset: Int): Int =
                if (offset <= 3) offset else offset - 1
        }
        TransformedText(AnnotatedString(formatted), offsetMapping)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {},
                navigationIcon = {
                    IconButton(onClick = {
                        viewModel.smsCode = ""
                        viewModel.errorMessage = null
                        onBack()
                    }) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(48.dp))

            Image(
                painter = painterResource(id = R.drawable.life_signal_logo),
                contentDescription = "App Logo",
                modifier = Modifier.size(100.dp)
            )

            Spacer(Modifier.height(24.dp))

            Text(
                text = "Enter SMS Code",
                style = MaterialTheme.typography.headlineMedium,
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(32.dp))

            val formattedCode = remember(viewModel.smsCode) {
                viewModel.smsCode.chunked(3).joinToString(" ")
            }

            OutlinedTextField(
                value = viewModel.smsCode,
                onValueChange = {
                    viewModel.smsCode = it.filter(Char::isDigit).take(6)
                },
                visualTransformation = CodeVisualTransformation,
                isError = viewModel.smsCode.length != 6 && viewModel.smsCode.isNotBlank(),
                textStyle = LocalTextStyle.current.copy(
                    textAlign = TextAlign.Center,
                    fontSize = MaterialTheme.typography.headlineSmall.fontSize
                ),
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions.Default.copy(keyboardType = KeyboardType.NumberPassword),
                singleLine = true
            )

            Spacer(Modifier.height(24.dp))

            Button(
                onClick = {
                    val id = viewModel.verificationId
                    if (viewModel.smsCode.length == 6 && id != null) {
                        val credential = PhoneAuthProvider.getCredential(id, viewModel.smsCode)
                        signInWithCredential(credential, onSignedIn) {
                            viewModel.errorMessage = it
                        }
                    } else {
                        viewModel.errorMessage = "Enter a valid 6-digit code"
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = viewModel.smsCode.length == 6
            ) {
                Text("Sign In")
            }

            Spacer(Modifier.height(16.dp))

            viewModel.errorMessage?.let {
                Text(it, color = MaterialTheme.colorScheme.error)
            }
        }
    }
}


fun startPhoneVerification(
    phoneNumber: String,
    activity: Activity,
    onCodeSent: (String) -> Unit,
    onError: (FirebaseException) -> Unit
) {
    val options = PhoneAuthOptions.newBuilder(FirebaseAuth.getInstance())
        .setPhoneNumber(phoneNumber)
        .setTimeout(60L, TimeUnit.SECONDS)
        .setActivity(activity)
        .setCallbacks(object : PhoneAuthProvider.OnVerificationStateChangedCallbacks() {
            override fun onVerificationCompleted(credential: PhoneAuthCredential) {
                FirebaseAuth.getInstance().signInWithCredential(credential)
            }

            override fun onVerificationFailed(e: FirebaseException) {
                onError(e)
            }

            override fun onCodeSent(verificationId: String, token: PhoneAuthProvider.ForceResendingToken) {
                onCodeSent(verificationId)
            }
        })
        .build()

    PhoneAuthProvider.verifyPhoneNumber(options)
}

@Composable
fun PhoneInputScreen(
    initialRegionCode: String = "US",
    onPhoneChanged: (Phone, regionCode: String) -> Unit
) {
    val regions = remember { getAllRegions() }
    var region by remember { mutableStateOf(regions.first { it.code == initialRegionCode }) }
    var rawPhone by remember { mutableStateOf("") }
    var showDialog by remember { mutableStateOf(false) }
    var searchQuery by remember { mutableStateOf("") }

    val filteredRegions = regions.filter {
        it.name.contains(searchQuery, ignoreCase = true) ||
                it.code.contains(searchQuery, ignoreCase = true) ||
                it.dialCode.contains(searchQuery)
    }

    val e164 = "+${region.dialCode.filter(Char::isDigit)}$rawPhone"
    val phone = Phone(e164)
    val isValid = phone.isValid(region.code)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Image(
            painter = painterResource(id = R.drawable.life_signal_logo),
            contentDescription = "App Logo",
            modifier = Modifier.size(100.dp)
        )

        Spacer(Modifier.height(24.dp))

        Text(
            "Welcome to LifeSignal",
            style = MaterialTheme.typography.headlineMedium,
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(32.dp))

        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            OutlinedButton(
                onClick = { showDialog = true },
                shape = MaterialTheme.shapes.medium,
                modifier = Modifier
                    .width(120.dp)
                    .height(56.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Text(region.flag, fontSize = 20.sp)
                    Spacer(Modifier.width(4.dp))
                    Text(region.dialCode, fontSize = 16.sp)
                }
            }

            Spacer(Modifier.width(8.dp))

            OutlinedTextField(
                value = rawPhone,
                onValueChange = {
                    rawPhone = it.filter(Char::isDigit)
                    onPhoneChanged(Phone(e164), region.code)
                },
                label = { Text("Phone Number") },
                isError = rawPhone.isNotBlank() && !isValid,
                trailingIcon = {
                    if (rawPhone.isNotBlank()) {
                        Icon(
                            if (isValid) Icons.Default.Check else Icons.Default.Close,
                            contentDescription = null,
                            tint = if (isValid) Color.Green else Color.Red
                        )
                    }
                },
                keyboardOptions = KeyboardOptions.Default.copy(keyboardType = KeyboardType.Phone),
                modifier = Modifier.weight(1f)
            )
        }
    }

    if (showDialog) {
        AlertDialog(
            onDismissRequest = { showDialog = false },
            title = { Text("Select Region") },
            text = {
                Column {
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        label = { Text("Search") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Spacer(Modifier.height(8.dp))

                    LazyColumn(modifier = Modifier.heightIn(max = 300.dp)) {
                        items(filteredRegions) { r ->
                            Text(
                                text = "${r.flag} ${r.name} (${r.dialCode})",
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        region = r
                                        showDialog = false
                                        searchQuery = ""
                                    }
                                    .padding(8.dp)
                            )
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
fun NameEntryScreen(
    onSubmit: (String) -> Unit
) {
    var name by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Enter your name", style = MaterialTheme.typography.titleLarge)

        Spacer(Modifier.height(16.dp))

        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            label = { Text("Name") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(24.dp))

        Button(
            onClick = { if (name.isNotBlank()) onSubmit(name.trim()) },
            enabled = name.isNotBlank(),
            shape = RoundedCornerShape(24.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Continue")
        }
    }
}

@Preview(showBackground = true, name = "Name Entry Screen")
@Composable
fun NameEntryScreenPreview() {
    MaterialTheme {
        NameEntryScreen(onSubmit = {})
    }
}


//@Preview(showBackground = true)
//@Composable
//fun LifeSignalAppPreview() {
//    LifeSignalTheme {
//        LifeSignalApp(
//            secondsLeft = 123456,
//            onReset = {}
//        )
//    }
//}

fun formatCountdown(millis: Long): String {
    if (millis <= 0) return "Timed Out"

    val totalMinutes = (millis + 30_000L) / (1000 * 60)
    val days = totalMinutes / (60 * 24)
    val hours = (totalMinutes / 60) % 24
    val minutes = totalMinutes % 60

    return buildString {
        if (days > 0) append("$days ${if (days == 1L) "day" else "days"} ")
        if (hours > 0) append("$hours ${if (hours == 1L) "hour" else "hours"} ")
        if (minutes > 0) append("$minutes ${if (minutes == 1L) "minute" else "minutes"} ")
    }.trim()
}


@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    userViewModel: UserViewModel,
    onAddContactViaQrCode: () -> Unit = {},
    onReviewInstructionsClick: () -> Unit = {}
) {
    val profile by userViewModel.profile.collectAsState()
    val scrollState = rememberScrollState()

    LaunchedEffect(Unit) {
        userViewModel.loadUserProfile()
    }

    LaunchedEffect(profile?.qrCodeId) {
        if (profile?.qrCodeId.isNullOrBlank()) {
            userViewModel.generateAndSaveQRCodeId()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        TopAppBar(title = { Text("Home") })

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(scrollState)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(24.dp))

            Surface(
                shape = RoundedCornerShape(16.dp),
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.4f),
                tonalElevation = 1.dp,
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(1f)
            ) {
                Box(modifier = Modifier.fillMaxSize()) {
                    val context = LocalContext.current
                    val qrCodeId = profile?.qrCodeId.orEmpty()

                    IconButton(
                        onClick = { shareQrCode(context, qrCodeId) },
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .padding(16.dp)
                            .size(40.dp)
                    ) {
                        Icon(
                            modifier = Modifier.fillMaxSize(),
                            imageVector = Icons.Default.Share,
                            contentDescription = "Share",
                            tint = MaterialTheme.colorScheme.onSurface
                        )
                    }


                    Column(
                        verticalArrangement = Arrangement.Top,
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        val middleSpace = 56.dp

                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(middleSpace),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = profile?.name ?: "First Last",
                                style = MaterialTheme.typography.titleLarge,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                        }

                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(horizontal = middleSpace)
                                .padding(bottom = middleSpace)
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color.White)
                        ) {
                            val qrCodeId = profile?.qrCodeId
                            if (!qrCodeId.isNullOrBlank()) {
                                QrCodeView(
                                    content = qrCodeId,
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .align(Alignment.Center)
                                )
                            }
                        }
                    }
                }
            }

            Spacer(Modifier.height(16.dp))

            Text(
                text = "Your QR code is unique. If you share it with someone, they can scan it and add you as a contact",
                modifier = Modifier.fillMaxWidth(0.9f),
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(Modifier.height(8.dp))

            TextButton(onClick = { userViewModel.generateAndSaveQRCodeId() }) {
                Text("Reset QR Code")
            }

            Spacer(Modifier.height(8.dp))

            Button(
                onClick = onAddContactViaQrCode,
                shape = RoundedCornerShape(24.dp)
            ) {
                Text("Add Contact Via QR Code")
            }

            Spacer(Modifier.height(32.dp))

            Text(
                text = "Settings",
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(12.dp))

            var dialogOpen by remember { mutableStateOf(false) }

            val unitOptions = listOf("Days", "Hours")
            val minDays = 1
            val minHours = 8

            SettingCard(
                icon = Icons.Default.AlarmOn,
                title = "Check-in time interval",
                subtitle = profile?.checkInInterval?.let(::formatCountdown) ?: "—",
                onClick = { dialogOpen = true }
            )

            val currentProfile = profile

            if (dialogOpen && currentProfile != null) {
                var selectedIndex by remember {
                    mutableIntStateOf(if ((currentProfile.checkInInterval / 1000 / 60 / 60) % 24 == 0L) 0 else 1)
                }

                var selectedAmount by remember {
                    mutableStateOf(
                        if (selectedIndex == 0)
                            (currentProfile.checkInInterval / 1000 / 60 / 60 / 24).toString()
                        else
                            (currentProfile.checkInInterval / 1000 / 60 / 60).toString()
                    )
                }

                val amountOptions = remember(selectedIndex) {
                    if (unitOptions[selectedIndex] == "Hours") {
                        (minHours..56 step 8).map { it.toString() }
                    } else {
                        (minDays..14).map { it.toString() }
                    }
                }

                AlertDialog(
                    onDismissRequest = { dialogOpen = false },
                    confirmButton = {
                        TextButton(onClick = {
                            val amount = selectedAmount.toLongOrNull() ?: 1
                            val millis = if (unitOptions[selectedIndex] == "Days") {
                                amount * 24 * 60 * 60 * 1000L
                            } else {
                                amount * 60 * 60 * 1000L
                            }
                            userViewModel.updateCheckInInterval(millis)
                            dialogOpen = false
                        }) {
                            Text("OK")
                        }
                    },
                    dismissButton = {
                        TextButton(onClick = { dialogOpen = false }) {
                            Text("Cancel")
                        }
                    },
                    title = { Text("Select interval") },
                    text = {
                        Box(
                            modifier = Modifier.fillMaxWidth(),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                SingleChoiceSegmentedButtonRow {
                                    unitOptions.forEachIndexed { index, label ->
                                        SegmentedButton(
                                            shape = SegmentedButtonDefaults.itemShape(index, unitOptions.size),
                                            onClick = {
                                                selectedIndex = index
                                                selectedAmount = if (unitOptions[index] == "Hours") minHours.toString() else minDays.toString()
                                            },
                                            selected = index == selectedIndex,
                                            label = { Text(label) }
                                        )
                                    }
                                }

                                Spacer(Modifier.height(8.dp))

                                DropdownSelector(
                                    label = "Amount",
                                    options = amountOptions,
                                    selected = selectedAmount,
                                    onSelectedChange = { selectedAmount = it }
                                )
                            }
                        }
                    }
                )
            }

            Spacer(Modifier.height(24.dp))

            Text(
                text = "Notifications",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(12.dp))

            SettingToggleCard(
                icon = Icons.Default.Notifications,
                title = "30 minutes before timeout",
                checked = profile?.notify30MinBefore == true,
                onCheckedChange = { isChecked ->
                    userViewModel.updateNotificationPreference("notify30MinBefore", isChecked)
                }
            )

            Spacer(Modifier.height(12.dp))

            SettingToggleCard(
                icon = Icons.Default.Notifications,
                title = "2 hours before timeout",
                checked = profile?.notify2HoursBefore == true,
                onCheckedChange = { isChecked ->
                    userViewModel.updateNotificationPreference("notify2HoursBefore", isChecked)
                }
            )

            Spacer(Modifier.height(24.dp))

            Text(
                text = "Learn More",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(12.dp))

            SettingCard(
                icon = Icons.Default.Info,
                title = "Review instructions",
                onClick = onReviewInstructionsClick
            )

            Spacer(Modifier.height(32.dp))
        }
    }
}

fun shareQrCode(context: Context, qrCodeId: String) {
    val qrBitmap = generateQrCodeBitmap(qrCodeId)

    val file = File(context.cacheDir, "qr_code.png")
    FileOutputStream(file).use { out ->
        qrBitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
    }

    val uri = FileProvider.getUriForFile(context, "${context.packageName}.provider", file)

    val shareIntent = Intent(Intent.ACTION_SEND).apply {
        type = "image/png"
        putExtra(Intent.EXTRA_STREAM, uri)
        flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
    }

    context.startActivity(Intent.createChooser(shareIntent, "Share QR Code"))
}


@Composable
fun QrCodeView(content: String, modifier: Modifier = Modifier) {
    val qrBitmap = remember(content) { generateQrCodeBitmap(content) }
    Image(
        bitmap = qrBitmap.asImageBitmap(),
        contentDescription = "QR Code",
        modifier = modifier
            .fillMaxSize()
    )
}

fun generateQrCodeBitmap(text: String, size: Int = 512): Bitmap {
    val hints = mapOf(
        EncodeHintType.MARGIN to 1,
        EncodeHintType.CHARACTER_SET to "UTF-8",
        EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.L
    )

    val bitMatrix = MultiFormatWriter().encode(text, BarcodeFormat.QR_CODE, size, size, hints)

    val bmp = createBitmap(size, size, Bitmap.Config.RGB_565)

    for (x in 0 until size) {
        for (y in 0 until size) {
            bmp[x, y] =
                if (bitMatrix[x, y]) android.graphics.Color.BLACK else android.graphics.Color.WHITE
        }
    }
    return bmp
}



@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DropdownSelector(
    label: String,
    options: List<String>,
    selected: String,
    onSelectedChange: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    val screenHeight = LocalConfiguration.current.screenHeightDp.dp
    val maxHeight = screenHeight * 0.3f

    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = !expanded }
    ) {
        TextField(
            value = selected,
            onValueChange = {},
            readOnly = true,
            label = { Text(label) },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
            modifier = Modifier.menuAnchor()
        )
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.heightIn(max = maxHeight)
        ) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option) },
                    onClick = {
                        onSelectedChange(option)
                        expanded = false
                    }
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RespondersScreen(
    userViewModel: UserViewModel,
    contactViewModel: ResolvedContactsViewModel = viewModel(),
    onContactClick: (ResolvedContact) -> Unit
) {
    val profile by userViewModel.profile.collectAsState()
    val resolvedContacts by contactViewModel.resolvedContacts.collectAsState()

    LaunchedEffect(profile?.contacts) {
        if (profile != null) {
            contactViewModel.loadAllResolvedContacts(profile!!.contacts)
        }
    }

    val responders = resolvedContacts.filter { it.isResponder }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Responders") })
        }
    ) { innerPadding ->
        LazyColumn(
            contentPadding = innerPadding,
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(responders) { contact ->
                ContactCard(
                    name = contact.name,
                    contactType = ContactType.Responder,
                    modifier = Modifier.clickable {
                        onContactClick(contact)
                    }
                )
            }
        }
    }
}

//@Preview(showBackground = true)
//@Composable
//fun RespondersScreenPreview() {
//    LifeSignalTheme {
//        RespondersScreen()
//    }
//}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DependentsScreen(
    onContactClick: (ResolvedContact) -> Unit,
    userViewModel: UserViewModel,
    contactViewModel: ResolvedContactsViewModel = viewModel()
) {
    val profile by userViewModel.profile.collectAsState()
    val resolvedContacts by contactViewModel.resolvedContacts.collectAsState()

    LaunchedEffect(profile?.contacts) {
        if (profile != null) {
            contactViewModel.loadAllResolvedContacts(profile!!.contacts)
        }
    }

    val dependents = resolvedContacts.filter { it.isDependent }

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Dependents") })
        }
    ) { innerPadding ->
        LazyColumn(
            contentPadding = innerPadding,
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(dependents) { contact ->
                var millisecondsLeft by remember(contact) {
                    mutableStateOf(
                        (contact.checkInExpiry.toDate().time - System.currentTimeMillis())
                            .coerceAtLeast(0)
                    )
                }

                LaunchedEffect(contact) {
                    while (millisecondsLeft > 0) {
                        delay(1000)
                        millisecondsLeft = (contact.checkInExpiry.toDate().time - System.currentTimeMillis())
                            .coerceAtLeast(0)
                    }
                }

                ContactCard(
                    name = contact.name,
                    millisecondsLeft = millisecondsLeft,
                    contactType = ContactType.Dependent,
                    modifier = Modifier.clickable { onContactClick(contact) }
                )
            }
        }
    }
}


//@Preview(showBackground = true)
//@Composable
//fun DependentsScreenPreview() {
//    LifeSignalTheme {
//        DependentsScreen()
//    }
//}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserProfileScreen(
    userViewModel: UserViewModel = viewModel(),
    onUpdatePhoneClick: () -> Unit = {}
) {
    val screenScroll = rememberScrollState()
    val noteScroll = rememberScrollState()
    val userProfile by userViewModel.profile.collectAsState()

    var note by remember(userProfile?.note) {
        mutableStateOf(userProfile?.note.orEmpty())
    }

    LaunchedEffect(Unit) {
        userViewModel.loadUserProfile()
    }

    Column(modifier = Modifier.fillMaxSize()) {
        TopAppBar(title = { Text("Profile") })

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(screenScroll)
                .background(MaterialTheme.colorScheme.background)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(24.dp))

            Avatar(name = userProfile?.name ?: "", size = AvatarSize.Large)

            Spacer(Modifier.height(8.dp))

            var showDialog by remember { mutableStateOf(false) }
            var nameText by remember { mutableStateOf(userProfile?.name.orEmpty()) }

            Text(
                text = userProfile?.name ?: "First Last",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.clickable { showDialog = true }
            )

            if (showDialog) {
                val context = LocalContext.current

                AlertDialog(
                    onDismissRequest = { showDialog = false },
                    confirmButton = {
                        TextButton(onClick = {
                            userViewModel.updateName(nameText)
                            showDialog = false

                            Toast.makeText(context, "Updated Name", Toast.LENGTH_SHORT).show()
                        }) { Text("Save") }
                    },
                    dismissButton = {
                        TextButton(onClick = { showDialog = false }) { Text("Cancel") }
                    },
                    title = { Text("Edit Name") },
                    text = {
                        OutlinedTextField(
                            value = nameText,
                            onValueChange = { nameText = it },
                            singleLine = true
                        )
                    }
                )
            }

            val formattedPhone = userProfile?.let {
                formatPhoneNumber(it.phone.number, it.phoneRegion)
            } ?: "+1 (123) 456-7890"


            Text(
                text = formattedPhone,
                style = MaterialTheme.typography.bodyMedium
            )

            Spacer(Modifier.height(24.dp))

            Text(
                text = "Contact Note",
                style = MaterialTheme.typography.labelLarge,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp)
            )

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .background(
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        shape = RoundedCornerShape(12.dp)
                    )
                    .verticalScroll(noteScroll)
                    .padding(12.dp)
            ) {
                val displayNote = if (note.isNotBlank()) note else userProfile?.note.orEmpty()

                if (displayNote.isEmpty()) {
                    Text(
                        text = "This is sample text the contacts will see when they open this profile",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                    )
                }

                BasicTextField(
                    value = note,
                    onValueChange = {
                        note = it
                        userViewModel.updateNote(it)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    textStyle = MaterialTheme.typography.bodySmall.copy(
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    ),
                    maxLines = 150
                )
            }

            Spacer(Modifier.height(32.dp))

            Button(
                onClick = onUpdatePhoneClick,
                shape = RoundedCornerShape(24.dp)
            ) {
                Text("Update Phone Number")
            }

            Spacer(Modifier.height(16.dp))

            var showSignOutDialog by remember { mutableStateOf(false) }

            Button(
                onClick = { showSignOutDialog = true },
                shape = RoundedCornerShape(24.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer,
                    contentColor = MaterialTheme.colorScheme.onErrorContainer
                )
            ) {
                Text("Sign Out")
            }

            val context = LocalContext.current

            if (showSignOutDialog) {
                AlertDialog(
                    onDismissRequest = { showSignOutDialog = false },
                    title = { Text("Sign Out") },
                    text = { Text("Are you sure you want to sign out?") },
                    confirmButton = {
                        TextButton(onClick = {
                            showSignOutDialog = false
                            FirebaseAuth.getInstance().signOut()

                            Toast.makeText(context, "Signed Out", Toast.LENGTH_SHORT).show()
                        }) {
                            Text("Yes")
                        }
                    },
                    dismissButton = {
                        TextButton(onClick = { showSignOutDialog = false }) {
                            Text("Cancel")
                        }
                    }
                )
            }

            Spacer(Modifier.height(24.dp))
        }
    }
}

fun formatPhoneNumber(number: String, regionCode: String): String {
    val nationalDigits = number.filter { it.isDigit() }

    return try {
        val formatter = PhoneNumberUtil.getInstance().getAsYouTypeFormatter(regionCode)
        nationalDigits.fold("") { acc, c -> formatter.inputDigit(c) }
    } catch (_: Exception) {
        nationalDigits
    }
}

//@Preview(showBackground = true)
//@Composable
//fun ProfileScreenPreview() {
//    LifeSignalTheme {
//        UserProfileScreen()
//    }
//}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContactDetailScreen(
    userViewModel: UserViewModel,
    resolvedContactsViewModel: ResolvedContactsViewModel,
    onBack: () -> Unit
) {
    val context = LocalContext.current

    val contact = resolvedContactsViewModel.selectedResolvedContact.value ?: return
    val screenScroll = rememberScrollState()
    val noteScroll = rememberScrollState()

    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()

    var localResponder by remember { mutableStateOf(contact.isResponder) }
    var localDependent by remember { mutableStateOf(contact.isDependent) }

    fun enforceToggleState(type: String, newValue: Boolean) {
        val newResponder = if (type == "responder") newValue else localResponder
        val newDependent = if (type == "dependent") newValue else localDependent

        if (!newResponder && !newDependent) {
            coroutineScope.launch {
                snackbarHostState.showSnackbar("At least one role must remain enabled.")
            }
            return
        }

        if (type == "responder") {
            localResponder = newValue
            resolvedContactsViewModel.toggleResponder()
        } else {
            localDependent = newValue
            resolvedContactsViewModel.toggleDependent()
        }
    }

    Scaffold(
        snackbarHost = {
            SnackbarHost(hostState = snackbarHostState)
        },
        topBar = {
            TopAppBar(
                title = { Text("Contact") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBackIosNew, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .fillMaxSize()
                .verticalScroll(screenScroll)
                .background(MaterialTheme.colorScheme.background)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(24.dp))

            Avatar(name = contact.name, size = AvatarSize.Large)

            Spacer(Modifier.height(8.dp))

            Text(text = contact.name, style = MaterialTheme.typography.titleMedium)

            val roleText = when {
                contact.isResponder && contact.isDependent -> "Responder and Dependent"
                contact.isResponder -> "Responder"
                contact.isDependent -> "Dependent"
                else -> ""
            }

            Text(
                text = roleText,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(Modifier.height(24.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterHorizontally)
            ) {
                ActionButton(
                    icon = Icons.Default.PriorityHigh,
                    label = "Call",
                    onClick = {
                        val intent = Intent(Intent.ACTION_DIAL).apply {
                            data = "tel:${contact.phone.number}".toUri()
                        }
                        context.startActivity(intent)
                    }
                )

                ActionButton(
                    icon = Icons.Outlined.Sms,
                    label = "Message",
                    onClick = {
                        val phone = contact.phone.number

                        val smsIntent = Intent(Intent.ACTION_SENDTO).apply {
                            data = "smsto:$phone".toUri()
                        }

                        val whatsappIntent = Intent(Intent.ACTION_SENDTO).apply {
                            data = "smsto:$phone".toUri()
                            `package` = "com.whatsapp"
                        }

                        val chooserIntent = Intent.createChooser(smsIntent, "Choose app to message")

                        if (whatsappIntent.resolveActivity(context.packageManager) != null) {
                            chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf(whatsappIntent))
                        }

                        context.startActivity(chooserIntent)
                    }
                )
            }

            Spacer(Modifier.height(24.dp))

            Text(
                text = "Contact Note",
                style = MaterialTheme.typography.labelLarge,
                modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp)
            )

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .background(
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        shape = RoundedCornerShape(12.dp)
                    )
                    .verticalScroll(noteScroll)
                    .padding(12.dp)
            ) {
                Text(
                    text = if (contact.note.isNotBlank()) contact.note else "This is sample text the contacts will see when they open this profile",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(Modifier.height(32.dp))

            Text(
                text = "Settings",
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.height(16.dp))

            SettingToggleCard(
                icon = Icons.Default.PlayArrow,
                title = "Responder",
                checked = localResponder,
                onCheckedChange = { enforceToggleState("responder", it) }
            )

            Spacer(Modifier.height(12.dp))

            SettingToggleCard(
                icon = Icons.Default.Groups,
                title = "Dependent",
                checked = localDependent,
                onCheckedChange = { enforceToggleState("dependent", it) }
            )

            Spacer(Modifier.height(32.dp))

            var showDeleteDialog by remember { mutableStateOf(false) }

            Button(
                onClick = { showDeleteDialog = true },
                shape = RoundedCornerShape(24.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer,
                    contentColor = MaterialTheme.colorScheme.onErrorContainer
                )
            ) {
                Text("Delete Contact")
            }

            if (showDeleteDialog) {
                AlertDialog(
                    onDismissRequest = { showDeleteDialog = false },
                    title = { Text("Delete Contact") },
                    text = { Text("Are you sure you want to delete this contact?") },
                    confirmButton = {
                        TextButton(onClick = {
                            Toast.makeText(context, "Deleted Contact", Toast.LENGTH_SHORT).show()

                            showDeleteDialog = false
                            userViewModel.deleteContactReferencesFromUserAndContact(contact.reference)
                            onBack()
                        }) {
                            Text("Yes")
                        }
                    },
                    dismissButton = {
                        TextButton(onClick = { showDeleteDialog = false }) {
                            Text("Cancel")
                        }
                    }
                )
            }

            Spacer(Modifier.height(24.dp))

            SnackbarHost(
                hostState = snackbarHostState,
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
        }
    }
}


//@Preview(showBackground = true)
//@Composable
//fun ContactDetailScreenPreview() {
//    LifeSignalTheme {
//        ContactDetailScreen(
//            name = "",
//            phone = "",
//            note = "",
//            isResponder = true,
//            isDependent = true,
//            onBack = {},
//            onCallClick = {},
//            onMessageClick = {},
//            onResponderToggle = {},
//            onDependentToggle = {},
//            onDeleteClick = {},
//        )
//    }
//}

@androidx.annotation.OptIn(ExperimentalGetImage::class)
@Composable
fun QRCodeScannerScreen(
    onBack: () -> Unit,
    onNavigateToAddContact: () -> Unit,
    resolvedContactsViewModel: ResolvedContactsViewModel = viewModel()
) {
    val context = LocalContext.current
    val activity = context as? Activity
    val lifecycleOwner = LocalLifecycleOwner.current

    val cameraPermission = Manifest.permission.CAMERA
    var hasRequested by remember { mutableStateOf(false) }
    val permissionGranted = remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, cameraPermission) == PackageManager.PERMISSION_GRANTED
        )
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted -> permissionGranted.value = granted }

    LaunchedEffect(Unit) {
        if (!permissionGranted.value && !hasRequested) {
            hasRequested = true
            permissionLauncher.launch(cameraPermission)
        }
    }

    val imagePickerLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        val bitmap = if (Build.VERSION.SDK_INT < 28) {
            MediaStore.Images.Media.getBitmap(context.contentResolver, uri)
        } else {
            val source = ImageDecoder.createSource(context.contentResolver, uri)
            ImageDecoder.decodeBitmap(source)
        }
        val inputImage = InputImage.fromBitmap(bitmap, 0)
        BarcodeScanning.getClient().process(inputImage)
            .addOnSuccessListener { barcodes ->
                barcodes.firstOrNull()?.rawValue?.let { qrContent ->
                    resolvedContactsViewModel.setScannedQr(qrContent)
                    onNavigateToAddContact()
                }
            }
            .addOnFailureListener {
                Log.e("QR", "Image scan failed", it)
            }
    }

    val recentImages = remember { loadRecentImages(context) }

    if (permissionGranted.value) {
        val cameraProviderFuture = remember { ProcessCameraProvider.getInstance(context) }
        val previewView = remember { PreviewView(context) }

        LaunchedEffect(Unit) {
            val cameraProvider = cameraProviderFuture.get()
            val preview = CameraPreview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            val analyzer = ImageAnalysis.Builder().build().apply {
                setAnalyzer(ContextCompat.getMainExecutor(context)) { imageProxy ->
                    val mediaImage = imageProxy.image
                    if (mediaImage != null) {
                        val inputImage = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
                        BarcodeScanning.getClient().process(inputImage)
                            .addOnSuccessListener { barcodes ->
                                barcodes.firstOrNull()?.rawValue?.let { qrContent ->
                                    resolvedContactsViewModel.setScannedQr(qrContent)
                                    onNavigateToAddContact()
                                }
                            }
                            .addOnFailureListener {
                                Log.e("QR", "Scan failed", it)
                            }
                            .addOnCompleteListener {
                                imageProxy.close()
                            }
                    } else {
                        imageProxy.close()
                    }
                }
            }

            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

            try {
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(
                    lifecycleOwner,
                    cameraSelector,
                    preview,
                    analyzer
                )
            } catch (e: Exception) {
                Log.e("QR", "Camera binding failed", e)
            }
        }

        Box(modifier = Modifier.fillMaxSize()) {
            AndroidView(
                factory = { previewView },
                modifier = Modifier.fillMaxSize()
            )

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(top = 16.dp),
                verticalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBackIosNew, contentDescription = "Back", tint = Color.White)
                    }
                    IconButton(onClick = {
                        imagePickerLauncher.launch("image/*")
                    }) {
                        Icon(Icons.Default.UploadFile, contentDescription = "Upload QR", tint = Color.White)
                    }
                }

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0xAA000000))
                        .padding(vertical = 8.dp)
                ) {
                    ImageGalleryPreview(
                        imageUris = recentImages,
                        onImageClick = { uri ->
                            val bitmap = if (Build.VERSION.SDK_INT < 28) {
                                MediaStore.Images.Media.getBitmap(context.contentResolver, uri)
                            } else {
                                val source = ImageDecoder.createSource(context.contentResolver, uri)
                                ImageDecoder.decodeBitmap(source)
                            }
                            val inputImage = InputImage.fromBitmap(bitmap, 0)
                            BarcodeScanning.getClient().process(inputImage)
                                .addOnSuccessListener { barcodes ->
                                    barcodes.firstOrNull()?.rawValue?.let { qrContent ->
                                        resolvedContactsViewModel.setScannedQr(qrContent)
                                        onNavigateToAddContact()
                                    }
                                }
                                .addOnFailureListener {
                                    Log.e("QR", "Recent image scan failed", it)
                                }
                        }
                    )
                }
            }
        }

    } else {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("Camera permission required to scan QR codes.")
        }
    }
}

@Composable
fun ImageGalleryPreview(
    imageUris: List<Uri>,
    onImageClick: (Uri) -> Unit
) {
    LazyRow(
        modifier = Modifier
            .fillMaxWidth()
            .height(100.dp),
        contentPadding = PaddingValues(horizontal = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    )
    {
        items(imageUris) { uri ->
            Image(
                painter = rememberAsyncImagePainter(uri),
                contentDescription = null,
                modifier = Modifier
                    .size(80.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .clickable { onImageClick(uri) }
            )
        }
    }
}

fun loadRecentImages(context: Context, maxResults: Int = 6): List<Uri> {
    val images = mutableListOf<Uri>()
    val projection = arrayOf(
        MediaStore.Images.Media._ID
    )

    val sortOrder = "${MediaStore.Images.Media.DATE_ADDED} DESC"

    val query = context.contentResolver.query(
        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
        projection,
        null,
        null,
        sortOrder
    )

    query?.use { cursor ->
        val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
        var count = 0
        while (cursor.moveToNext() && count < maxResults) {
            val id = cursor.getLong(idColumn)
            val contentUri = ContentUris.withAppendedId(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id
            )
            images.add(contentUri)
            count++
        }
    }

    return images
}




@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddContactViaQRCodeScreen(
    qrCodeId: String,
    onBack: () -> Unit
) {
    val scrollState = rememberScrollState()
    val context = LocalContext.current
    val user = FirebaseAuth.getInstance().currentUser
    val db = FirebaseFirestore.getInstance()

    var contactName by remember { mutableStateOf("") }
    var contactPhone by remember { mutableStateOf("") }
    var contactNote by remember { mutableStateOf("") }

    LaunchedEffect(qrCodeId) {
        val snapshot = db.collection("users")
            .whereEqualTo("qrCodeId", qrCodeId)
            .limit(1)
            .get()
            .await()

        val doc = snapshot.documents.firstOrNull()
        if (doc != null) {
            contactName = doc.getString("name") ?: ""
            contactPhone = doc.getString("phone") ?: ""
            contactNote = doc.getString("note") ?: ""
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Add Contact") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBackIosNew, contentDescription = "Back")
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(innerPadding)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(24.dp))

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 24.dp),
                contentAlignment = Alignment.TopCenter
            ) {
                Surface(
                    shape = RoundedCornerShape(16.dp),
                    color = MaterialTheme.colorScheme.surfaceVariant,
                    tonalElevation = 1.dp,
                    modifier = Modifier
                        .fillMaxWidth()
                        .offset(y = 38.dp)
                ) {
                    Column(
                        verticalArrangement = Arrangement.Top,
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Spacer(Modifier.height(48.dp))

                        val middleSpace = 56.dp

                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(middleSpace),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(
                                    text = contactName,
                                    style = MaterialTheme.typography.titleLarge,
                                    color = MaterialTheme.colorScheme.onSurface
                                )

                                Text(
                                    text = contactPhone,
                                    style = MaterialTheme.typography.bodyMedium
                                )
                            }
                        }

                        Box(
                            modifier = Modifier
                                .padding(horizontal = middleSpace)
                                .padding(bottom = middleSpace)
                                .background(Color.White, shape = RoundedCornerShape(8.dp))
                                .aspectRatio(1f)
                        ) {
                            QrCodeView(
                                content = qrCodeId,
                                modifier = Modifier
                                    .fillMaxSize(0.95f)
                                    .align(Alignment.Center)
                            )
                        }
                    }
                }

                Avatar(
                    name = contactName,
                    size = AvatarSize.Large,
                    color = MaterialTheme.colorScheme.surfaceVariant
                )
            }

            Spacer(Modifier.height(64.dp))

            val context = LocalContext.current
            val userViewModel: UserViewModel = viewModel()

            Button(
                onClick = {
                    userViewModel.addQrContact(
                        qrCodeId = qrCodeId,
                        isResponder = true,
                        isDependent = false,
                        context = context,
                        onSuccess = {
                            Toast.makeText(context, "Added as Responder", Toast.LENGTH_SHORT).show()
                            onBack()
                        },
                        onError = {
                            Toast.makeText(context, "Failed to add contact", Toast.LENGTH_SHORT).show()
                        }
                    )
                },
                shape = RoundedCornerShape(24.dp)
            ) {
                Text("Add as Responder")
            }

            Spacer(Modifier.height(12.dp))

            Button(
                onClick = {
                    userViewModel.addQrContact(
                        qrCodeId = qrCodeId,
                        isResponder = false,
                        isDependent = true,
                        context = context,
                        onSuccess = {
                            Toast.makeText(context, "Added as Dependent", Toast.LENGTH_SHORT).show()
                            onBack()
                        },
                        onError = {
                            Toast.makeText(context, "Failed to add contact", Toast.LENGTH_SHORT).show()
                        }
                    )
                },
                shape = RoundedCornerShape(24.dp)
            ) {
                Text("Add as Dependent")
            }

            Spacer(Modifier.height(12.dp))

            Button(
                onClick = {
                    userViewModel.addQrContact(
                        qrCodeId = qrCodeId,
                        isResponder = true,
                        isDependent = true,
                        context = context,
                        onSuccess = {
                            Toast.makeText(context, "Added as Both", Toast.LENGTH_SHORT).show()
                            onBack()
                        },
                        onError = {
                            Toast.makeText(context, "Failed to add contact", Toast.LENGTH_SHORT).show()
                        }
                    )
                },
                shape = RoundedCornerShape(24.dp)
            ) {
                Text("Add as Both")
            }

            Spacer(Modifier.height(32.dp))
        }
    }
}



//@Preview(showBackground = true)
//@Composable
//fun AddContactViaQRCodeScreenPreview() {
//    LifeSignalTheme {
//        AddContactViaQRCodeScreen(
//            name = "First Last",
//            onAddAsResponder = {},
//            onAddAsDependent = {},
//            onAddAsBoth = {},
//            onBack = {},
//        )
//    }
//}

enum class AvatarSize {
    Small, Large
}

@Composable
fun Avatar(
    modifier: Modifier = Modifier,
    name: String,
    size: AvatarSize = AvatarSize.Small,
    color: Color = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f)
) {
    val dimension = when (size) {
        AvatarSize.Small -> 40.dp
        AvatarSize.Large -> 72.dp
    }

    val textStyle = when (size) {
        AvatarSize.Small -> MaterialTheme.typography.labelLarge
        AvatarSize.Large -> MaterialTheme.typography.headlineSmall
    }

    Box(
        modifier = Modifier
            .size(dimension)
            .background(
                color = color,
                shape = CircleShape
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = name.firstOrNull()?.uppercase() ?: "",
            style = textStyle,
            color = MaterialTheme.colorScheme.primary,
            textAlign = TextAlign.Center
        )
    }
}

enum class ContactType {
    Responder,
    Dependent
}

@Composable
fun ContactCard(
    modifier: Modifier = Modifier,
    name: String,
    millisecondsLeft: Long = 1,
    contactType: ContactType = ContactType.Responder
) {
    val isAlert = contactType == ContactType.Dependent && millisecondsLeft <= 0

    val cardColor = if (isAlert) {
        MaterialTheme.colorScheme.errorContainer
    } else {
        MaterialTheme.colorScheme.surfaceVariant
    }

    val subtitleColor = if (isAlert) {
        MaterialTheme.colorScheme.onErrorContainer
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }

    val subtitle = if (isAlert) {
        "Not Responsive"
    } else {
        formatCountdown(millisecondsLeft)
    }

    Surface(
        shape = RoundedCornerShape(12.dp),
        color = cardColor,
        tonalElevation = 1.dp,
        modifier = modifier.fillMaxWidth(),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 80.dp)
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Avatar(name = name)

            Spacer(modifier = Modifier.width(16.dp))

            Column(
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    text = name,
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface
                )

                if (contactType == ContactType.Dependent){
                    Spacer(Modifier.height(4.dp))

                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodyMedium,
                        color = subtitleColor
                    )
                }
            }
        }
    }
}

@Composable
fun SettingCard(
    icon: ImageVector,
    title: String,
    subtitle: String? = null,
    onClick: (() -> Unit)? = null
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 1.dp,
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable { onClick() } else Modifier),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(72.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(icon, contentDescription = null)
                Spacer(Modifier.width(16.dp))
                Column {
                    Text(text = title, style = MaterialTheme.typography.bodyLarge)
                    if (subtitle != null) {
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = subtitle,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun SettingToggleCard(
    icon: ImageVector,
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 1.dp,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onCheckedChange(!checked) },
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(icon, contentDescription = null)
            Spacer(Modifier.width(16.dp))
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                modifier = Modifier.weight(1f)
            )
            Switch(
                checked = checked,
                onCheckedChange = null
            )
        }
    }
}

@Composable
fun ActionButton(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val buttonSize = 64.dp

    OutlinedButton(
        onClick = onClick,
        shape = RoundedCornerShape(12.dp),
        modifier = modifier
            .size(buttonSize),
        contentPadding = PaddingValues(8.dp)
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.fillMaxSize()
        ) {
            Icon(
                icon,
                contentDescription = label,
                modifier = Modifier.size(24.dp)
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                textAlign = TextAlign.Center
            )
        }
    }
}

