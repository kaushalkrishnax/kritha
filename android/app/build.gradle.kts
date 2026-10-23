plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kritha.app"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kritha.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Supported Android ABIs: physical devices (arm64-v8a) and emulators /
        // x86_64 hosts. This also keeps plugin AARs (notably sherpa-onnx) from
        // contributing 32-bit libraries we do not ship.
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
        versionCode = 100
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Flutter 3.47 adds every supported ABI to plugin AARs regardless of
    // --target-platform, so exclude the 32-bit ABIs we do not support.
    packaging {
        jniLibs {
            excludes += listOf(
                "lib/armeabi-v7a/**",
                "lib/x86/**",
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
