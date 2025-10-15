# Mapbox Maps - Suppress ImageReader warnings
-dontwarn android.media.ImageReader

# Keep Mapbox classes
-keep class com.mapbox.** { *; }
-dontnote com.mapbox.**
