plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

dependencies {
    testImplementation("junit:junit:4.12")
}

// Flutter generates one plugin registrant for all Android variants. The
// integration_test plugin is a dev dependency, so it is absent from release
// compile classpaths on AGP 9; direct generated references then break release
// builds. Keep debug registration for device tests and make release tolerant
// when that class is not packaged.
val makeReleasePluginRegistrantVariantSafe by tasks.registering {
    doLast {
        val registrant = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
        if (!registrant.isFile) return@doLast
        val generated = registrant.readText()
        val directRegistration =
            "      flutterEngine.getPlugins().add(new dev.flutter.plugins.integration_test.IntegrationTestPlugin());"
        if (generated.contains(directRegistration)) {
            val reflectiveRegistration = """      Class<?> pluginClass = Class.forName("dev.flutter.plugins.integration_test.IntegrationTestPlugin");
      io.flutter.embedding.engine.plugins.FlutterPlugin plugin =
          (io.flutter.embedding.engine.plugins.FlutterPlugin) pluginClass.getDeclaredConstructor().newInstance();
      flutterEngine.getPlugins().add(plugin);"""
            val withReflection = generated.replace(directRegistration, reflectiveRegistration)
                .replace(
                    "    } catch (Exception e) {",
                    "    } catch (ClassNotFoundException e) {\n" +
                        "      // Expected for release variants without integration_test.\n" +
                        "    } catch (Exception e) {",
                )
            registrant.writeText(withReflection)
        }
    }
}

tasks.configureEach {
    if (name == "compileReleaseJavaWithJavac") {
        dependsOn(makeReleasePluginRegistrantVariantSafe)
    }
}

android {
    namespace = "dev.codexis.codexis"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.codexis"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
