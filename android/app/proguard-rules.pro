# Blocktopus ships no reflection, no dynamic class loading and no JNI beyond
# what Flutter and its two plugins bring, so the default optimised rules plus
# the plugin rules below are enough.

# Flutter embedding.
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# audioplayers uses ExoPlayer/Media3 on Android; keep its entry points.
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
