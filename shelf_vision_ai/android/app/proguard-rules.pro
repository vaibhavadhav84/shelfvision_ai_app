# ShelfVision AI Proguard Rules
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

-keep class io.flutter.** { *; }
-keep class com.shelfvision.shelf_vision_ai.** { *; }

# Keep Camera and media dependencies
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Suppress Play Store deferred component warnings (app does not use dynamic feature delivery)
-dontwarn com.google.android.play.core.**

# Flutter and JNI wrappers
-keepclassmembers class * {
    native <methods>;
}
