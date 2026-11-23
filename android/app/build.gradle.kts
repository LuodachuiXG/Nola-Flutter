import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 发布签名信息存放在 android/key.properties（已被 gitignore，勿提交）。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "cc.loac.nola"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "cc.loac.nola"
        // 仅支持 Android 7.0+（去掉旧机型兼容）
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 仅保留 64 位 ARM（去掉 x86 / x86_64 模拟器与 armeabi-v7a 旧机型）。
        // 注意：Flutter 引擎库（libflutter/libapp）不受 abiFilters 约束，
        // release 构建需配合 --target-platform android-arm64 才能真正只打 arm64。
        ndk {
            abiFilters += listOf("arm64-v8a")
        }

        // 只保留中英文资源，去除 AndroidX 库携带的其他语言资源以减小包体
        resourceConfigurations += listOf("zh", "en")
    }

    buildTypes {
        release {
            // 启用 R8 代码收缩与资源收缩以减小包体
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )

            // 使用 key.properties 中的正式密钥签名；
            // 缺少该文件时回退到 debug 签名（便于本地调试构建）。
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.create("release") {
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                    storePassword = keystoreProperties["storePassword"] as String
                }
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    packaging {
        jniLibs {
            // 压缩存储 .so（AGP 9 的 useLegacyPackaging=true 即“压缩 .so 并安装时解包”），
            // 引擎库压缩后约为原来的一半，APK 下载体积显著减小；代价是安装时解包、磁盘占用略增。
            // 注意语义：false/不设置 = 不压缩+页对齐（配合 extractNativeLibs="false" 免解包），
            // 两者互斥，本项目优先小体积，故用 true。
            useLegacyPackaging = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
