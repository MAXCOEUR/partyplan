import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Clé de publication, lue depuis `android/key.properties`, hors dépôt.
//
// Absente, la compilation retombe sur la clé de débogage : un clone frais doit pouvoir
// produire un release installable sans détenir la clé du magasin (règle 5). Ce repli est
// le comportement voulu en développement, et interdit en publication — d'où
// l'avertissement, et non le silence.
val proprietesCle = Properties().apply {
    val fichier = rootProject.file("key.properties")
    if (fichier.exists()) {
        fichier.inputStream().use { load(it) }
    }
}

val cleDePublication = proprietesCle.getProperty("storeFile") != null

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
        applicationId = "fr.maxencecoeur.partyplan"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Tirés de `version:` dans pubspec.yaml. Google Play refuse un versionCode déjà
        // publié : il s'incrémente à chaque dépôt, y compris pour une correction.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (cleDePublication) {
            create("publication") {
                storeFile = file(proprietesCle.getProperty("storeFile"))
                storePassword = proprietesCle.getProperty("storePassword")
                keyAlias = proprietesCle.getProperty("keyAlias")
                keyPassword = proprietesCle.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (cleDePublication) {
                signingConfigs.getByName("publication")
            } else {
                // Avertissement et non information : « lifecycle » est filtré par la
                // sortie de flutter build, et un bundle signé en débogage est refusé par
                // Google Play — sans que rien ne l'ait annoncé à la compilation.
                logger.warn(
                    "key.properties absent : release signé avec la clé de DÉBOGAGE. " +
                        "Installable en direct, refusé par Google Play. " +
                        "Voir docs/publication-play-store.md."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
