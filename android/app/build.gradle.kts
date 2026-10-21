import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // Kotlin vem embutido no AGP 9 (android.builtInKotlin=true).
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.devia.gymmap"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.devia.gymmap"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // AdMob App ID: defina admobAppId em android/key.properties (ou a
        // variável de ambiente ADMOB_APP_ID_ANDROID) para o build de produção.
        // Sem isso usa o ID de teste do Google, que não gera receita.
        manifestPlaceholders["admobAppId"] =
            (keystoreProperties["admobAppId"] as String?)?.takeIf { it.isNotBlank() }
                ?: System.getenv("ADMOB_APP_ID_ANDROID")?.takeIf { it.isNotBlank() }
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        create("release") {
            val keyAliasValue = keystoreProperties["keyAlias"] as String?
            val keyPasswordValue = keystoreProperties["keyPassword"] as String?
            val storeFileValue = keystoreProperties["storeFile"] as String?
            val storePasswordValue = keystoreProperties["storePassword"] as String?

            if (!keyAliasValue.isNullOrBlank()) {
                keyAlias = keyAliasValue
            }
            if (!keyPasswordValue.isNullOrBlank()) {
                keyPassword = keyPasswordValue
            }
            if (!storePasswordValue.isNullOrBlank()) {
                storePassword = storePasswordValue
            }
            if (!storeFileValue.isNullOrBlank()) {
                storeFile = file(storeFileValue)
            }
        }
    }

    buildTypes {
        release {
            // Release artifacts must never silently use the debug certificate.
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
