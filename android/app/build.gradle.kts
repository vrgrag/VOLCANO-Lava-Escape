import java.util.Properties
import java.io.FileInputStream

// ============================================================
// Lava Escape — Android app module
// ============================================================
// applicationId + namespace MUST match:
//   • lib/rift/identity.dart → EscapeIdentity.bundle
//   • android/app/google-services.json → package_name
//   • android/app/src/main/kotlin/**/MainActivity.kt package
// ============================================================

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin must be applied AFTER Android + Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Only attach the Google Services plugin once the real google-services.json
// has landed. Keeps the build green while credentials are pending.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("keystore/key.properties")
val keystoreProperties = Properties()
val keystoreReady = keystorePropertiesFile.exists()
if (keystoreReady) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.lavaescap.lavaescape"

    // Per TZ: targetSdk = 35, minSdk = 30, compileSdk = 36 (kept high so
    // transitive plugin dependencies like `flutter_plugin_android_lifecycle`
    // compile against 36+ — see `.cursor/rules/gray_part_pitfalls.md` §2).
    compileSdk = 36
    // NDK 27+ satisfies 16 KB page-size support (Android 15+, mandatory
    // from Nov 1 2025 — pitfalls §11). Bumped to 28.2.x because the
    // transitive `jni` plugin ships prebuilt .so libraries linked against
    // that toolchain and downgrading breaks Gradle's aar-metadata check.
    ndkVersion = "28.2.13676358"

    compileOptions {
        // flutter_local_notifications 18+ needs java.time — enable
        // core-library desugaring (pitfalls §5).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.lavaescap.lavaescape"
        minSdk = 30
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreReady) {
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (keystoreReady) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
