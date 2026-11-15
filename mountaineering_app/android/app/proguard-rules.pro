# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Firebase (SDK'lar kendi consumer ProGuard kurallarini icerir)
-dontwarn com.google.firebase.**

# AdMob (SDK kendi consumer ProGuard kurallarini icerir)
-dontwarn com.google.android.gms.ads.**

# Google Play Core (Fixes R8 missing class errors)
-dontwarn com.google.android.play.core.**

# Prevent obfuscation of some model classes if needed
# -keep class com.yourpackage.models.** { *; }
