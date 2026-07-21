# Flutter's default embedding + plugin classes must survive shrinking.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Supabase / gotrue / realtime rely on reflection for model (de)serialization.
-keep class io.supabase.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
