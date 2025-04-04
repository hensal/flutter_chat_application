// Flutter web plugin registrant file.
//
// Generated file. Do not edit.
//

// @dart = 2.13
// ignore_for_file: type=lint

import 'package:emoji_picker_flutter/emoji_picker_flutter_web.dart';
import 'package:file_picker/_internal/file_picker_web.dart';
import 'package:google_sign_in_all_platforms_mobile/google_sign_in_all_platforms_mobile_web.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';
import 'package:record_web/record_web.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:url_launcher_web/url_launcher_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void registerPlugins([final Registrar? pluginRegistrar]) {
  final Registrar registrar = pluginRegistrar ?? webPluginRegistrar;
  EmojiPickerFlutterPluginWeb.registerWith(registrar);
  FilePickerWeb.registerWith(registrar);
  GoogleSignInAllPlatformsMobileWeb.registerWith(registrar);
  GoogleSignInPlugin.registerWith(registrar);
  RecordPluginWeb.registerWith(registrar);
  SharedPreferencesPlugin.registerWith(registrar);
  UrlLauncherPlugin.registerWith(registrar);
  registrar.registerMessageHandler();
}
