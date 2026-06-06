import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}
android {
    namespace = "com.example.jobmitra"
    // Bumped from flutter.compileSdkVersion (30) — androidx.core 1.17.0
    // (transitively pulled in by the `printing` package) requires compileSdk
    // 36. Stays compatible with minSdk 21 via runtime checks.
    compileSdk = 36
    // Pinned to 27.0.12077973 because firebase_*, google_mobile_ads, and 11
    // other plugins now ship native libs built against NDK 27. The Flutter
    // default (flutter.ndkVersion = 26.x) made the release strip step fail
    // with "failed to strip debug symbols from native libraries".
    ndkVersion = "27.0.12077973"
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }
    signingConfigs {
        create("release") {
            // Place keystore-release.jks in flutter_app/android/ and
            // create keystore.properties there (copy from keystore.properties.example)
            val props = Properties()
            val propsFile = rootProject.file("keystore.properties")
            if (propsFile.exists()) {
                props.load(propsFile.inputStream())
                // Resolve storeFile relative to android/ (rootProject), not android/app/
                storeFile = rootProject.file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }
    defaultConfig {
        applicationId = "com.jobmitra.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes {
        release {
            val propsFile = rootProject.file("keystore.properties")
            signingConfig = if (propsFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Disable mapping file upload — upload manually via Firebase console if needed
            configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
                mappingFileUploadEnabled = false
            }
        }
    }
}
flutter {
    source = "../.."
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
