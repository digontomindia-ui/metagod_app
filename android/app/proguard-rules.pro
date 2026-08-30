# Razorpay – keep all Razorpay classes
-keep class com.razorpay.** { *; }
-keepclassmembers class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Proguard rules for flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep Flutter wrapper classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Gson / JSON serialization (used by some plugins)
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }

# flutter_inappwebview (transitive from youtube_player_flutter)
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-dontwarn com.pichillilorenzo.flutter_inappwebview.**

# General – prevent stripping of native method names
-keepclasseswithmembernames class * {
    native <methods>;
}
