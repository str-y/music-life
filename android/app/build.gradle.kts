plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val testAdmobApplicationId = "ca-app-pub-3940256099942544~3347511713"
val prodAdmobApplicationId =
    providers.gradleProperty("PROD_ADMOB_APPLICATION_ID").orNull
        ?: "ca-app-pub-0000000000000000~0000000000"

android {
    namespace = "com.example.music_life"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    flavorDimensions += "environment"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.music_life"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Music Life Dev")
            manifestPlaceholders["admobApplicationId"] = testAdmobApplicationId
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            resValue("string", "app_name", "Music Life Staging")
            manifestPlaceholders["admobApplicationId"] = testAdmobApplicationId
        }
        create("prod") {
            dimension = "environment"
            resValue("string", "app_name", "Music Life")
            manifestPlaceholders["admobApplicationId"] = prodAdmobApplicationId
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
