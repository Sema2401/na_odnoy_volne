plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.na_odnoy_volne" 
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.na_odnoy_volne"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true // Часто нужно для Firebase
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

tasks.whenTaskAdded {
    if (name == "assembleRelease" || name == "assembleDebug") {
        doLast {
            val buildType = if (name.contains("Release")) "release" else "debug"
            val apkName = "app-$buildType.apk"

            val sourceDir = file("$buildDir/outputs/apk/$buildType")
            val sourceFile = file("$sourceDir/$apkName")

            val targetDir = file("${rootProject.projectDir.parentFile}/build/app/outputs/flutter-apk")
            val targetFile = file("$targetDir/$apkName")
            
            if (sourceFile.exists()) {
                targetDir.mkdirs()
                sourceFile.copyTo(targetFile, overwrite = true)
                println("✅ APK успешно скопирован в: $targetFile")
            } else {
                println("⚠️ Не удалось найти APK в: $sourceFile")
            }
        }
    }
}