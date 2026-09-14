plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "nl.hiddebalestra.privacychat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "nl.hiddebalestra.privacychat"
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
        create("alpha") {
            // A committed, stable self-signed key — NOT the Android Gradle
            // Plugin's auto-generated debug keystore, which gets freshly
            // (re)generated on every clean CI machine. Signing every release
            // build with a *different* random key meant every APK update
            // was rejected by Android as a signature mismatch, forcing a
            // full uninstall before each new install.
            // TODO before any real/production distribution: replace this
            // with a securely stored release keystore (e.g. via GitHub
            // Actions secrets), not one committed to the repo.
            storeFile = file("keystore/alpha.jks")
            storePassword = "privacychat"
            keyAlias = "privacychatalpha"
            keyPassword = "privacychat"
            storeType = "PKCS12"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("alpha")
        }
    }

    // The tor-android artifact below ships its native tor binaries as plain
    // <abi>/libtor.so entries in a jar, not in the lib/<abi>/*.so layout the
    // Android Gradle Plugin auto-extracts from a normal dependency. Feeding
    // that extracted folder in as an extra jniLibs source dir (further down)
    // is what actually gets libtor.so packaged into the APK per-ABI.
    sourceSets {
        getByName("main").jniLibs.srcDir(layout.buildDirectory.dir("torBinaries"))
    }
}

// Isolated from the main `dependencies {}` block: this is a binary payload
// to unpack, not a library to compile/link against.
val torBinaries: Configuration by configurations.creating

dependencies {
    torBinaries("org.briarproject:tor-android:0.4.9.12")
}

val extractTorBinaries by tasks.registering(Copy::class) {
    from(torBinaries.map { zipTree(it) })
    include("**/libtor.so")
    into(layout.buildDirectory.dir("torBinaries"))
}

tasks.named("preBuild") {
    dependsOn(extractTorBinaries)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
