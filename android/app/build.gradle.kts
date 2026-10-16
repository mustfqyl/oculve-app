plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val androidSigningEnv = mapOf(
    "storeFile" to System.getenv("OCULVE_ANDROID_KEYSTORE"),
    "storePassword" to System.getenv("OCULVE_ANDROID_STORE_PASSWORD"),
    "keyAlias" to System.getenv("OCULVE_ANDROID_KEY_ALIAS"),
    "keyPassword" to System.getenv("OCULVE_ANDROID_KEY_PASSWORD"),
)
val hasAndroidReleaseSigning = androidSigningEnv.values.all {
    !it.isNullOrBlank()
}

val releasePackagingTasks = setOf(
    "preReleaseBuild",
    "validateSigningRelease",
    "packageRelease",
    "packageReleaseBundle",
    "bundleRelease",
    "assembleRelease",
)
tasks.configureEach {
    if (name in releasePackagingTasks) {
        doFirst {
            if (!hasAndroidReleaseSigning) {
                throw GradleException(
                    "Android release signing is not configured. Set " +
                        "OCULVE_ANDROID_KEYSTORE, OCULVE_ANDROID_STORE_PASSWORD, " +
                        "OCULVE_ANDROID_KEY_ALIAS, and OCULVE_ANDROID_KEY_PASSWORD.",
                )
            }
        }
    }
}

android {
    namespace = "com.oculve.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    packaging { jniLibs { useLegacyPackaging = true } }

    if (hasAndroidReleaseSigning) {
        signingConfigs {
            create("release") {
                storeFile = file(androidSigningEnv.getValue("storeFile")!!)
                storePassword = androidSigningEnv.getValue("storePassword")
                keyAlias = androidSigningEnv.getValue("keyAlias")
                keyPassword = androidSigningEnv.getValue("keyPassword")
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.oculve.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            signingConfig = if (hasAndroidReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
