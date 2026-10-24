import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties().apply {
    if (signingPropertiesFile.exists()) {
        FileInputStream(signingPropertiesFile).use { load(it) }
    }
}

val verifyReleaseSigning = tasks.register("verifyReleaseSigning") {
    doLast {
        if (!signingPropertiesFile.exists()) {
            throw GradleException(
                "Missing android/key.properties. Copy android/key.example.properties " +
                    "to android/key.properties and configure your release keystore."
            )
        }

        val requiredProperties = listOf(
            "storePassword",
            "keyPassword",
            "keyAlias",
            "storeFile",
        )
        val missingProperties = requiredProperties.filter {
            signingProperties.getProperty(it).isNullOrBlank()
        }
        if (missingProperties.isNotEmpty()) {
            throw GradleException(
                "Missing required values in android/key.properties: " +
                    missingProperties.joinToString(", ")
            )
        }

        // Match Android's standard key.properties convention: storeFile is
        // resolved relative to this app module (android/app/).
        val keystore = project.file(signingProperties.getProperty("storeFile"))
        if (!keystore.isFile) {
            throw GradleException("Release keystore does not exist: ${keystore.path}")
        }
    }
}

tasks.configureEach {
    if (
        name.contains("Release") &&
        (name.startsWith("assemble") || name.startsWith("bundle") || name.startsWith("package"))
    ) {
        dependsOn(verifyReleaseSigning)
    }
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
        minSdk = maxOf(flutter.minSdkVersion, 26)
        targetSdk = flutter.targetSdkVersion
        // Flutter selects arm64-v8a and x86_64 at build time. Keep ABI
        // selection out of ndk.abiFilters because Flutter's --split-per-abi
        // uses Gradle ABI splits, which conflict with that filter.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++14"
            }
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = signingProperties.getProperty("keyAlias", "")
            keyPassword = signingProperties.getProperty("keyPassword", "")
            storeFile = signingProperties.getProperty("storeFile")
                ?.let { project.file(it) }
            storePassword = signingProperties.getProperty("storePassword", "")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
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
