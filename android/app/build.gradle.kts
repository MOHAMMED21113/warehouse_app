plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.smartwarehouse.app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"
    lint {
        disable.add("NullSafeMutableLiveData")
        checkReleaseBuilds = false
        abortOnError = false
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // 🔴 إصلاح: تغيير applicationId من القيمة الافتراضية إلى معرّف فريد
        applicationId = "com.smartwarehouse.app"
        minSdk = 23
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // 🟠 إصلاح: تقليل حجم APK بالاقتصار على المعماريات المستخدمة فعلياً
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a")
            isUniversalApk = false
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}


flutter {
    source = "../.."
}

dependencies {
    // هذه المكتبة مهمة جداً لـ SQLite لكي تعمل مع compileOptions أعلاه
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}