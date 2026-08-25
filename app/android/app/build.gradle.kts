plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Le greffon Google Services n'est appliqué que si google-services.json est présent.
//
// Le fichier est hors dépôt (NF-SEC-02, règle 5) : un clone frais doit compiler et
// tourner sans compte Firebase. Appliquer le greffon inconditionnellement ferait échouer
// la compilation avec « File google-services.json is missing », ce qui rendrait le dépôt
// inutilisable pour quiconque n'a pas le projet Firebase.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    // Avertissement et non information : « lifecycle » est filtré par la sortie de
    // flutter build, et une clé absente désactive silencieusement les notifications.
    logger.warn(
        "google-services.json absent : compilation sans notifications poussées. " +
            "Voir docs/comptes-externes.md."
    )
}

android {
    namespace = "fr.maxencecoeur.partyplan"
    // Fixé explicitement : la plateforme android-37 n'est distribuée que sous le nom
    // « android-37.0 », que Gradle ne sait pas résoudre. android-36 est installé et
    // suffit à toutes les dépendances du projet.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.maxencecoeur.partyplan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
