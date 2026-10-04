#!/usr/bin/env python3
"""Konfigurasi platform rilis BengkelKu (idempoten).

Jalankan dari folder bengkelku-mobile setelah `flutter create --platforms=ios .`:
    python3 tool/apply_platform_config.py

- Android: package com.bengkelkumotor.service, izin, deep link, queries, signing fallback.
- iOS: bundle id, iOS 14, Podfile, Info.plist (izin, URL scheme, Maps key), AppDelegate.
"""
import os
import re
import shutil

PKG = "com.bengkelkumotor.service"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def write(p, s):
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)


# ---------------------------------------------------------------- Android
gradle = "android/app/build.gradle.kts"
s = read(gradle)
s = re.sub(r'namespace = "[^"]+"', f'namespace = "{PKG}"', s)
s = re.sub(r'[ \t]*// TODO: Specify your own unique Application ID[^\n]*\n', '', s)
s = re.sub(r'applicationId = "[^"]+"', f'applicationId = "{PKG}"', s)
s = s.replace('defaultConfig {        applicationId', 'defaultConfig {\n        applicationId')
if "keystorePropertiesFile.exists()) {\n            create" not in s:
    s = s.replace('''    signingConfigs {
        create("release") {
            keyAlias = signingProperty("keyAlias")
            keyPassword = signingProperty("keyPassword")
            storeFile = file(signingProperty("storeFile"))
            storePassword = signingProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }''', '''    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = signingProperty("keyAlias")
                keyPassword = signingProperty("keyPassword")
                storeFile = file(signingProperty("storeFile"))
                storePassword = signingProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Tanpa android/key.properties (mis. build pratinjau di CI) APK
            // ditandatangani kunci debug — JANGAN unggah build itu ke Play Store.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }''')
write(gradle, s)

kt_dir = "android/app/src/main/kotlin/" + PKG.replace(".", "/")
os.makedirs(kt_dir, exist_ok=True)
write(f"{kt_dir}/MainActivity.kt",
      f"package {PKG}\n\nimport io.flutter.embedding.android.FlutterActivity\n\nclass MainActivity : FlutterActivity()\n")
old = "android/app/src/main/kotlin/com/example"
if os.path.isdir(old):
    shutil.rmtree(old)

man = "android/app/src/main/AndroidManifest.xml"
s = read(man)
if "android.permission.INTERNET" not in s:
    s = s.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Jaringan -->
    <uses-permission android:name="android.permission.INTERNET" />
    <!-- Lokasi: bengkel terdekat, SOS pengendara, siaga & rute mekanik (PRD 3.3) -->
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <!-- Kamera: selfie KTP, foto lokasi, foto masalah & bukti penawaran -->
    <uses-permission android:name="android.permission.CAMERA" />
    <!-- Notifikasi (Android 13+) & getar tawaran darurat -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.location.gps" android:required="false" />
''')
if "login-callback" not in s:
    s = s.replace('''                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>''', '''                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            <!-- Deep link OAuth / reset sandi Supabase: bengkelku://login-callback -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="bengkelku" android:host="login-callback" />
            </intent-filter>''')
if 'android:scheme="tel"' not in s:
    s = s.replace('''            <data android:mimeType="text/plain"/>
        </intent>''', '''            <data android:mimeType="text/plain"/>
        </intent>
        <!-- url_launcher: navigasi Google Maps/Waze, telepon 112, tautan web -->
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL" />
            <data android:scheme="tel" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="geo" />
        </intent>''')
write(man, s)

# ---------------------------------------------------------------- iOS
pbx = "ios/Runner.xcodeproj/project.pbxproj"
s = read(pbx)
s = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = com\.bengkelkumotor\.bengkelku", f"PRODUCT_BUNDLE_IDENTIFIER = {PKG}", s)
s = s.replace("IPHONEOS_DEPLOYMENT_TARGET = 13.0;", "IPHONEOS_DEPLOYMENT_TARGET = 14.0;")
write(pbx, s)

write("ios/Podfile", '''# google_maps_flutter & sentry membutuhkan iOS 14+.
platform :ios, '14.0'

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end
''')

for cfg in ("Debug", "Release"):
    write(f"ios/Flutter/{cfg}.xcconfig",
          f'#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.{cfg.lower()}.xcconfig"\n'
          '#include "Generated.xcconfig"\n#include? "Secrets.xcconfig"\n')
write("ios/Flutter/Secrets.xcconfig.example",
      "// Salin ke Flutter/Secrets.xcconfig (tidak di-commit) lalu isi.\n"
      "// CI membuat file ini dari secret GMAPS_API_KEY.\nGMAPS_API_KEY = isi_kunci_google_maps_ios\n")
gi = read("ios/.gitignore")
if "Flutter/Secrets.xcconfig" not in gi:
    write("ios/.gitignore", gi.rstrip("\n") + "\nFlutter/Secrets.xcconfig\n")

plist = "ios/Runner/Info.plist"
s = read(plist)
s = s.replace("<string>Bengkelku</string>", "<string>BengkelKu</string>", 1)
if "NSCameraUsageDescription" not in s:
    extra = '''	<key>GMSApiKey</key>
	<string>$(GMAPS_API_KEY)</string>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>BengkelKu memakai lokasimu untuk menampilkan bengkel terdekat, mengirim titik bantuan darurat, dan menunjukkan rute mekanik.</string>
	<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
	<string>Untuk bengkel yang siaga darurat, lokasi dipakai agar panggilan motor mogok di sekitar bengkel bisa diterima.</string>
	<key>NSCameraUsageDescription</key>
	<string>Kamera dipakai untuk foto KTP, selfie verifikasi, foto lokasi bengkel, foto masalah motor, dan bukti penawaran.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Galeri dipakai untuk memilih foto masalah motor, bukti penawaran, atau lampiran laporan.</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>com.bengkelkumotor.service</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>bengkelku</string>
			</array>
		</dict>
	</array>
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>comgooglemaps</string>
		<string>waze</string>
		<string>tel</string>
	</array>
	<key>ITSAppUsesNonExemptEncryption</key>
	<false/>
'''
    i = s.rindex("</dict>")
    s = s[:i] + extra + s[i:]
write(plist, s)

ad = "ios/Runner/AppDelegate.swift"
s = read(ad)
if "GoogleMaps" not in s:
    s = s.replace("import Flutter\nimport UIKit\n", "import Flutter\nimport GoogleMaps\nimport UIKit\n")
    s = s.replace("    GeneratedPluginRegistrant.register(with: self)", '''    // Kunci Google Maps dari Info.plist (GMSApiKey ← build setting GMAPS_API_KEY).
    if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !key.isEmpty, !key.hasPrefix("$(") {
      GMSServices.provideAPIKey(key)
    }
    GeneratedPluginRegistrant.register(with: self)''')
write(ad, s)

print("platform config applied")
