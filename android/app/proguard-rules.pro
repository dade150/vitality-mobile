# =============================================================================
# ProGuard / R8 Rules for vitality_assist
# =============================================================================

# Preserve generic type signatures for Gson TypeToken used by flutter_local_notifications
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# flutter_local_notifications plugin
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Gson & TypeToken
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# AndroidX Core NotificationCompat
-keep class androidx.core.app.NotificationCompat** { *; }
