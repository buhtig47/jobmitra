# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# AdMob
-keep class com.google.android.gms.ads.** { *; }

# Hive
-keep class com.hive.** { *; }

# Play Core (Flutter deferred components — referenced but not used in our build)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Crashlytics — preserve line numbers for crash reports
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Keep model classes
-keepattributes *Annotation*
-keepattributes Signature
