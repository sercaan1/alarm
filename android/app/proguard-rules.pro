# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-keep interface org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.support.** { *; }
-keep class org.tensorflow.lite.task.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options$GpuBackend

# AutoValue
-dontwarn com.google.auto.value.**
-keep class com.google.auto.value.** { *; }

# Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# AudioRecord
-keep class android.media.AudioRecord { *; }
-keep class android.media.AudioFormat { *; }
-keep class android.media.MediaRecorder { *; }

# WaterDetector - CALLBACK'LERİ KORU 👇
-keep class com.example.alarm.WaterDetector { *; }
-keepclassmembers class com.example.alarm.WaterDetector {
    public <methods>;
    *** onWaterDetected;
    *** onLogMessage;
}

# MainActivity
-keep class com.example.alarm.MainActivity { *; }