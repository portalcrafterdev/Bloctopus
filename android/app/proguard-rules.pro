# Blocktopus ships almost no reflection of its own, but its plugins do: the ads
# SDK reaches WorkManager and Room, both of which resolve classes by name. The
# rules below are what keeps release builds from dying on launch.

# Flutter embedding.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# audioplayers uses ExoPlayer/Media3 on Android; keep its entry points.
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# -- Ads ---------------------------------------------------------------------
#
# The claim at the top of this file stopped being true when the ads SDK landed.
# google_mobile_ads pulls in WorkManager, which stores its state in a Room
# database, and Room finds the generated implementation of a database by
# reflection: `Class.forName(name + "_Impl")`. R8 sees no caller, strips the
# class, and the app dies on launch before Flutter starts, with
#
#   Unable to get provider androidx.startup.InitializationProvider:
#     Failed to create an instance of androidx.work.impl.WorkDatabase
#
# which names neither ads nor Room and so is easy to chase in the wrong
# direction. Keeping every RoomDatabase subclass and its no-argument
# constructor is the rule Room itself documents.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.startup.InitializationProvider { *; }
-dontwarn androidx.work.**

-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-keep class io.flutter.plugins.googlemobileads.** { *; }
-dontwarn io.flutter.plugins.googlemobileads.**

# The ads SDK renders some formats in a WebView and calls back into Dart
# through the webview plugin it depends on.
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**
