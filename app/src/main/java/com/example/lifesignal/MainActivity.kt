package com.example.lifesignal

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.example.lifesignal.ui.theme.LifeSignalTheme
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import kotlinx.serialization.Serializable
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import android.Manifest
import android.app.NotificationChannel
import android.app.PendingIntent
import android.content.Intent
import androidx.annotation.Size
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.requiredHeightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Button
import androidx.compose.material3.Surface
import androidx.compose.material3.TextField
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.delay
import java.time.format.TextStyle
import kotlin.math.min


interface NavigationBarDestination {
    val icon: ImageVector
    val route: String
    val screen: @Composable () -> Unit
}

@Serializable
object Home : NavigationBarDestination {
    override val icon = Icons.Filled.Home
    override val route = "Home"
    override val screen: @Composable () -> Unit = { HomeScreen() }
}

@Serializable
object Responders : NavigationBarDestination {
    override val icon = Icons.Filled.Home
    override val route = "Responders"
    override val screen: @Composable () -> Unit = { RespondersScreen() }
}

@Serializable
object Dependents : NavigationBarDestination {
    override val icon = Icons.Filled.Home
    override val route = "Dependents"
    override val screen: @Composable () -> Unit = { DependentsScreen() }
}

@Serializable
object UserProfile : NavigationBarDestination {
    override val icon = Icons.Filled.Home
    override val route = "Profile"
    override val screen: @Composable () -> Unit = { UserProfileScreen() }
}

val navigationBarScreens = listOf(Home, Responders, Dependents, UserProfile)

class MainActivity : ComponentActivity() {
    companion object {
        const val CHANNEL_ID = "lifesignal_timer_channel"
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = getString(R.string.channel_name)
            val descriptionText = getString(R.string.channel_description)
            val importance = NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 100)
            }
        }
    }

    fun sendNotification(context: Context, textTitle: String, textContent: String) {
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

        var builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.baseline_notifications_24)
            .setContentTitle(textTitle)
            .setContentText(textContent)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        if (ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) return

        NotificationManagerCompat.from(context).notify(notificationId, builder.build())
    }

    private var secondsLeft by mutableStateOf(10)
    var resetTrigger by mutableStateOf(0)

    fun resetTimer() {
        secondsLeft = 10
        resetTrigger++
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        createNotificationChannel()
        requestNotificationPermission()

        enableEdgeToEdge()

        setContent {

            LaunchedEffect(resetTrigger) {
                while (secondsLeft > 0) {
                    delay(1000L)
                    secondsLeft--
                }

                sendNotification(
                    context = this@MainActivity,
                    textTitle = "Timer Expired",
                    textContent = "Please check in."
                )
            }

            LifeSignalApp(
                secondsLeft = secondsLeft,
                onReset = { resetTimer() }
                )
        }
    }
}

fun formatCountdown(seconds: Int): String {
    val minutes = (seconds % 3600) / 60
    val hours = (seconds % 86400) / 3600
    val days = seconds / 86400
    return "${days}d ${hours}h ${minutes}m"
}

@Composable
fun LifeSignalApp(
    secondsLeft: Int,
    onReset: () -> Unit,
    modifier: Modifier = Modifier
) {
    var currentScreen: NavigationBarDestination by remember { mutableStateOf(UserProfile) }

    LifeSignalTheme {
        Scaffold(
            bottomBar = {
                Box(
                    modifier = modifier
                        .fillMaxWidth(),
                ) {
                    Column(
                        modifier = modifier
                            .fillMaxWidth()
                            .background(MaterialTheme.colorScheme.surfaceVariant),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Spacer(Modifier.height(16.dp))

                        Text(
                            text = "Check-in Time Left",
                            style = MaterialTheme.typography.titleMedium
                        )

                        Text(
                            text = formatCountdown(secondsLeft),
                            style = MaterialTheme.typography.titleLarge
                        )

                        Spacer(Modifier.height(8.dp))

                        NavigationBar(
                            modifier = modifier,
                            containerColor = MaterialTheme.colorScheme.surfaceVariant
                        ) {
                            val middleIndex = navigationBarScreens.size / 2

                            navigationBarScreens.forEachIndexed { index, screen ->
                                if (index == middleIndex) {
                                    NavigationBarItem(
                                        icon = { Icon(Icons.Filled.Check, contentDescription = "Check-In") },
                                        label = {
                                            Text(
                                                "Check-in",
                                                style = MaterialTheme.typography.labelSmall,
                                                maxLines = 1,
                                                overflow = TextOverflow.Ellipsis
                                            )
                                        },
                                        selected = false,
                                        onClick = onReset
                                    )
                                }

                                NavigationBarItem(
                                    icon = {
                                        Icon(
                                            imageVector = screen.icon,
                                            contentDescription = screen.route
                                        )
                                    },
                                    label = {
                                        Text(
                                            screen.route,
                                            style = MaterialTheme.typography.labelSmall,
                                            maxLines = 1,
                                            overflow = TextOverflow.Ellipsis
                                        )
                                    },
                                    selected = currentScreen.route == screen.route,
                                    onClick = { currentScreen = screen }
                                )
                            }
                        }
                    }
                }
            }
        ) { innerPadding ->
            Box(Modifier.padding(innerPadding)) {
                currentScreen.screen()
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun LifeSignalAppPreview() {
    LifeSignalTheme {
        LifeSignalApp(
            secondsLeft = 123456,
            onReset = {}
        )
    }
}

@Composable
fun HomeScreen(
    modifier: Modifier = Modifier
) {
    Text(
        text = "HomeScreen",
        modifier = modifier
    )
}

@Composable
fun RespondersScreen(
    responders: List<String> = listOf("First Last", "First Last", "First Last")
) {
    Column {
        Text(
            text = "Responders",
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(vertical = 16.dp),
            textAlign = TextAlign.Center
        )

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .padding(horizontal = 24.dp, vertical = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            items(responders) { name ->
                ResponderCard(name = name)
            }
        }
    }
}


@Preview(showBackground = true)
@Composable
fun RespondersScreenPreview() {
    LifeSignalTheme {
        RespondersScreen()
    }
}

@Composable
fun DependentsScreen(
    modifier: Modifier = Modifier
) {
    Text(
        text = "DependentsScreen",
        modifier = modifier
    )
}

@Composable
fun UserProfileScreen(
    name: String = "First Last",
    phone: String = "+1 (123) 456-7890",
    onUpdatePhoneClick: () -> Unit = {}
) {
    Column(
    ) {
        Text(
            text = "Profile",
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(vertical = 16.dp),
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(24.dp))

        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {

            Avatar(name = name, size = AvatarSize.Large)

            Spacer(Modifier.height(8.dp))

            Text(text = name, style = MaterialTheme.typography.titleMedium)
            Text(text = phone, style = MaterialTheme.typography.bodyMedium)

            Spacer(Modifier.height(24.dp))

            Text(
                text = "Contact Note",
                style = MaterialTheme.typography.labelLarge,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 8.dp)
            )

            var note by remember { mutableStateOf("") }

            BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
                val maxHeight = this.maxHeight * 0.6f

                BasicTextField(
                    value = note,
                    onValueChange = { note = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 120.dp, max = maxHeight)
                        .background(
                            color = MaterialTheme.colorScheme.surfaceVariant,
                            shape = RoundedCornerShape(12.dp)
                        )
                        .padding(12.dp),
                    textStyle = MaterialTheme.typography.bodySmall.copy(
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    ),
                    maxLines = 150,
                    decorationBox = { innerTextField ->
                        Box(modifier = Modifier.fillMaxWidth()) {
                            if (note.isEmpty()) {
                                Text(
                                    text = "This is sample text the contacts will see when they open this profile",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                                    modifier = Modifier.align(Alignment.TopStart)
                                )
                            }
                            innerTextField()
                        }
                    }
                )
            }

            Spacer(Modifier.height(32.dp))

            // TODO: update phone number feature
            Button(
                onClick = onUpdatePhoneClick,
                shape = RoundedCornerShape(24.dp)
            ) {
                Text("Update Phone Number")
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun ProfileScreenPreview() {
    LifeSignalTheme {
        UserProfileScreen()
    }
}

enum class AvatarSize {
    Small, Large
}

@Composable
fun Avatar(
    name: String,
    size: AvatarSize = AvatarSize.Small
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
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.2f),
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

@Composable
fun ResponderCard(
    name: String,
    modifier: Modifier = Modifier
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        tonalElevation = 1.dp,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
        modifier = modifier
            .fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Avatar(name = name, size = AvatarSize.Small)

            Spacer(modifier = Modifier.width(16.dp))

            Text(
                text = name,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
    }
}
