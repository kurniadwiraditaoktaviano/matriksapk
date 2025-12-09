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

android {
    namespace = "com.fauzan.matriksapk"
    compileSdk = flutter.compileSdkVersion
    
    // --- PENTING: KITA KUNCI KE VERSI NDK STABIL YANG SUDAH DIINSTALL ---
    ndkVersion = "26.1.10909125"
    // --------------------------------------------------------------------

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
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        getByName("release") {
            // Menggunakan konfigurasi signing di atas
            signingConfig = signingConfigs.getByName("release")
            
            // Karena kita pakai NDK 26, biasanya tidak butuh kode 'debugSymbolLevel' lagi.
            // Kode ini sudah bersih dan standar.
        }
    }
}

flutter {
    source = "../.."
}