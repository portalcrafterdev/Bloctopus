import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is configured from android/key.properties, which is
// gitignored. Without it the release build falls back to the debug keys so
// `flutter run --release` still works locally; that build cannot be published.
// See android/key.properties.example.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // Set by the owner. This can never be changed once the app is published:
    // Google Play treats a different application id as a different app.
    namespace = "com.portalcrafter.blocktopus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.portalcrafter.blocktopus"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            // Installs beside the Play build rather than over it.
            //
            // A debug build is signed with the debug keystore and the store
            // build is not, so Android refuses to replace one with the other:
            // INSTALL_FAILED_UPDATE_INCOMPATIBLE. The only way to force it is
            // to uninstall first, which deletes the player's save.
            //
            // A different application id makes them different apps, so both
            // can sit on one phone with separate save data. The consequence
            // is that Play Games and AdMob do not recognise this id - neither
            // is registered against it - so sign in fails and only test ads
            // serve. Both are already true of a debug build.
            applicationIdSuffix = ".debug"
            // A manifest placeholder rather than a resValue: custom resource
            // values are a build feature that is off by default in AGP 8, and
            // a label does not need one turned on.
            manifestPlaceholders["appLabel"] = "Blocktopus debug"
        }
        release {
            manifestPlaceholders["appLabel"] = "Blocktopus"
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // The game has no reflection and no dynamic class loading, so the
            // default rules shrink it safely.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
