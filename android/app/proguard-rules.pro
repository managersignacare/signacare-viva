# Viva (patient mobile) — R8 / ProGuard rules (S8.2).
# Same keep rules as apps/mobile with namespace change.

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

-keep class com.signacare.viva.** { *; }
-keep class androidx.security.crypto.** { *; }

# flutter_local_notifications uses reflection for timezone data.
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**
