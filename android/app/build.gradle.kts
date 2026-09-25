import com.android.build.gradle.internal.api.BaseVariantOutputImpl
import java.nio.file.Files

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nuans.nuans"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nuans.nuans"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            // Telefonlar: arm64. x86/x86_64 yalnızca emülatör içindir.
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

@Suppress("DEPRECATION")
android.applicationVariants.configureEach {
    val variant = this
    if (variant.buildType.name != "release") return@configureEach

    outputs.configureEach {
        (this as BaseVariantOutputImpl).outputFileName = "Nuans.apk"
    }

    assembleProvider.configure {
        doLast {
            val apkDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
            val legacy = apkDir.resolve("app-release.apk")
            val branded = apkDir.resolve("Nuans.apk")
            if (!legacy.exists()) return@doLast

            if (branded.exists()) branded.delete()
            if (!legacy.renameTo(branded)) {
                legacy.copyTo(branded, overwrite = true)
                legacy.delete()
            }
            try {
                Files.createLink(legacy.toPath(), branded.toPath())
            } catch (_: Exception) {
                branded.copyTo(legacy, overwrite = true)
            }
        }
    }
}
