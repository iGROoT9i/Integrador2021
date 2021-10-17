# pruebita001

A new flutter module project.

## Getting Started

CONFIGURACIÓN

*Obtén una clave API en https://cloud.google.com/maps-platform/

*Habilite el SDK de Maps para Android, para iOS, y la API de indicaciones

*Agregue su clave de API a los archivos especificados

android/app/src/main/AndroidManifest.xml

<manifest ...
  <application ...
    <meta-data android:name="com.google.android.geo.API_KEY"
               android:value="YOUR KEY HERE"/>


ios/Runner/AppDelegate.swift

import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR KEY HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}