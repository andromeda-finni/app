import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releasePropertiesFile = rootProject.file("key.properties")
val releaseProperties = Properties()
if (releasePropertiesFile.exists()) {
    FileInputStream(releasePropertiesFile).use(releaseProperties::load)
}

/**
 * Demo and test builds may opt into Android's public debug key by setting
 * ALLOW_DEBUG_SIGNING=1. Such an APK installs and runs, but Google Play
 * rejects it, so the opt-in is explicit and never the default: a plain
 * `flutter build apk --release` still fails until a real keystore exists.
 */
val allowDebugSigning = System.getenv("ALLOW_DEBUG_SIGNING") == "1"

android {
    namespace = "com.andromedafinni.andromeda_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.andromedafinni.andromeda_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releasePropertiesFile.exists()) {
            create("release") {
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
                storeFile = file(releaseProperties.getProperty("storeFile"))
                storePassword = releaseProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Never ship a release carrying Android's public debug key by
            // accident. A release build fails below until an untracked
            // key.properties is provided by the developer or CI secret setup,
            // or the debug key is opted into explicitly.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.findByName("debug").takeIf { allowDebugSigning }
        }
    }
}

val validateReleaseSigning by tasks.registering {
    doLast {
        val required = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        val missing = required.filter { releaseProperties.getProperty(it).isNullOrBlank() }
        if (releasePropertiesFile.exists() && missing.isEmpty()) return@doLast
        if (allowDebugSigning) {
            logger.warn(
                "ALLOW_DEBUG_SIGNING=1: this release APK is signed with Android's " +
                    "public debug key. It installs and runs, but Google Play will " +
                    "reject it. Provide android/key.properties for a publishable build.",
            )
            return@doLast
        }
        throw GradleException(
            "Release signing is not configured. Copy android/key.properties.example " +
                "to android/key.properties and provide the private keystore values, " +
                "or set ALLOW_DEBUG_SIGNING=1 for a demo build.",
        )
    }
}

tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseSigning)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
