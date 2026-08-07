# minifyRelease is already enabled (shrinkResources too). Keep rules are targeted:
# avoid blanket ae.kiddytube.app.** so library code can be shrunk/obfuscated while
# preserving catalog JSON enums, WebView JS bridge, and EncryptedSharedPreferences/Tink.

# Catalog JSON uses SourceType.valueOf — enum constant names must survive R8.
-keepclassmembers enum ae.kiddytube.app.catalog.SourceType {
    public static **[] values();
    public static ae.kiddytube.app.catalog.SourceType valueOf(java.lang.String);
    <fields>;
}

# Hand-rolled CatalogJson + models are referenced from DataStore persistence.
-keep class ae.kiddytube.app.catalog.CatalogJson { *; }
-keep class ae.kiddytube.app.catalog.ContentChannel { *; }
-keep class ae.kiddytube.app.catalog.VideoItem { *; }
-keep class ae.kiddytube.app.catalog.CatalogSettings { *; }

# YouTube iframe WebView bridge (anonymous @JavascriptInterface in PlayerActivity).
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# AndroidX Security Crypto / Tink (EncryptedSharedPreferences + MasterKeys).
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-dontwarn javax.annotation.**

# Media3 reflective / service loaders; suppress missing optional bits.
-dontwarn androidx.media3.**
-keep class androidx.media3.** { *; }
