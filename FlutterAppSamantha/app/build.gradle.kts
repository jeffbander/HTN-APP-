import java.util.Properties
import java.io.FileNotFoundException // Import FileNotFoundException for throwing it when the file is not found
import java.io.File

// Load keystore properties from the keystore.properties file
val keystoreProperties = Properties()
val keystorePropertiesFile = File("/Users/maxturner/FlutterProjects/HypterTensionAppReal/TestTest/testtest/android/app/keystore.properties")

// Check if the keystore.properties file exists
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
} else {
    throw FileNotFoundException("Keystore properties file not found!")
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mswheart.fdhypertensionapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // Use the required NDK version

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.mswheart.fdhypertensionapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Use the keystore properties from the keystore.properties file
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = file(keystoreProperties["storeFile"] as String?)
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
