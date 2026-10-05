group = "com.xuehua.xue_hua_audio_android"
version = "1.0.0"

buildscript {
    val kotlinVersion = "2.4.0"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.xuehua.xue_hua_audio_android"

    compileSdk = 37

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Pigeon 29 generates suspend host APIs, which need coroutines.
    // Pigeon 29 生成 suspend Host API，需要协程库。
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    // Media3 ExoPlayer drives all audio playback (file/URL/asset).
    // Media3 ExoPlayer 负责全部音频播放（本地文件/网络/Asset）。
    implementation("androidx.media3:media3-exoplayer:1.11.1")
    implementation("androidx.media3:media3-datasource:1.11.1")
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.24.0")
}
