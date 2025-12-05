import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties from android/key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("android/key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    // Package / namespace for your app
    namespace = "no.gisle.vaner"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // This is the applicationId Google Play uses. Must stay the same for all future updates.
        applicationId = "no.gisle.vaner"

        // Use a safe minSdk for Firebase etc.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion

        // These are taken from your pubspec.yaml (version: 1.0.0+1)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            // Use the real release keystore (NOT debug)
            signingConfig = signingConfigs.getByName("release")

            // Optional optimizations:
            // isMinifyEnabled = true
            // isShrinkResources = true
        }
    }
}

flutter {
    source = "../.."
}
