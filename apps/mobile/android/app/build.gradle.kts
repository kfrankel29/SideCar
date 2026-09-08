plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kaileefrankel.sidecar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.kaileefrankel.sidecar"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] =
            providers.gradleProperty("MAPS_API_KEY")
                .orElse(providers.environmentVariable("MAPS_API_KEY"))
                .orElse("")
                .get()
    }

    signingConfigs {
        create("release") {
            val keyStorePath = providers.environmentVariable("SIDECAR_UPLOAD_KEYSTORE").orNull
            val keyStorePassword = providers.environmentVariable("SIDECAR_UPLOAD_STORE_PASSWORD").orNull
            val uploadKeyAlias = providers.environmentVariable("SIDECAR_UPLOAD_KEY_ALIAS").orNull
            val uploadKeyPassword = providers.environmentVariable("SIDECAR_UPLOAD_KEY_PASSWORD").orNull
            if (
                keyStorePath != null &&
                keyStorePassword != null &&
                uploadKeyAlias != null &&
                uploadKeyPassword != null
            ) {
                storeFile = file(keyStorePath)
                storePassword = keyStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")
    implementation("androidx.appcompat:appcompat:1.7.1")
}
