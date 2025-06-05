// Flutter web plugin registrant file.
//
// Generated file. Do not edit.
//

// @dart = 2.13
// ignore_for_file: type=lint

import 'package:audioplayers_web/audioplayers_web.dart';
import 'package:cloud_firestore_web/cloud_firestore_web.dart';
import 'package:firebase_auth_web/firebase_auth_web.dart';
import 'package:firebase_core_web/firebase_core_web.dart';
import 'package:flutter_facebook_auth_web/flutter_facebook_auth_web.dart';
import 'package:flutter_secure_storage_web/flutter_secure_storage_web.dart';
import 'package:flutter_tts/flutter_tts_web.dart';
import 'package:flutter_web_auth_2/src/web.dart';
import 'package:geolocator_web/geolocator_web.dart';
import 'package:google_maps_flutter_web/google_maps_flutter_web.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:sign_in_with_apple_web/sign_in_with_apple_web.dart';
import 'package:speech_to_text/speech_to_text_web.dart';
import 'package:url_launcher_web/url_launcher_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void registerPlugins([final Registrar? pluginRegistrar]) {
  final Registrar registrar = pluginRegistrar ?? webPluginRegistrar;
  AudioplayersPlugin.registerWith(registrar);
  FirebaseFirestoreWeb.registerWith(registrar);
  FirebaseAuthWeb.registerWith(registrar);
  FirebaseCoreWeb.registerWith(registrar);
  FlutterFacebookAuthPlugin.registerWith(registrar);
  FlutterSecureStorageWeb.registerWith(registrar);
  FlutterTtsPlugin.registerWith(registrar);
  FlutterWebAuth2WebPlugin.registerWith(registrar);
  GeolocatorPlugin.registerWith(registrar);
  GoogleMapsPlugin.registerWith(registrar);
  GoogleSignInPlugin.registerWith(registrar);
  SharedPreferencesPlugin.registerWith(registrar);
  SignInWithApplePlugin.registerWith(registrar);
  SpeechToTextPlugin.registerWith(registrar);
  UrlLauncherPlugin.registerWith(registrar);
  registrar.registerMessageHandler();
}
