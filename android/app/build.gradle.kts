plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Import library untuk membaca file properti
import java.util.Properties
import java.io.FileInputStream

// --- 1. MEMUAT KEY.PROPERTIES ---
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
// ...
android {
    namespace = "com.fauzan.matriksapk"
    compileSdk = flutter.compileSdkVersion

    // --- UBAH JADI INI (VERSI BARU) ---
    // ndkVersion = "27.0.12077973" // Comment out to use the default NDK version
    // ...

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.fauzan.matriksapk"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --- 2. KONFIGURASI SIGNING (Rilis) ---
    signingConfigs {
        create("release") {
            if (keystoreProperties["storeFile"] != null) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Menggunakan konfigurasi signing di atas
            if (keystoreProperties["storeFile"] != null) {
                signingConfig = signingConfigs.getByName("release")
            }

            // Karena kita pakai NDK 26, biasanya tidak butuh kode 'debugSymbolLevel' lagi.
            // Kode ini sudah bersih dan standar.
        }
    }
}

flutter {
    source = "../.."
}