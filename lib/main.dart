import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/settings.dart';

/// api_id / api_hash can be baked in at build time:
///   flutter build linux --dart-define=TG_API_ID=123 --dart-define=TG_API_HASH=abc
/// Otherwise the app asks for them on first launch.
const _apiId = int.fromEnvironment('TG_API_ID');
const _apiHash = String.fromEnvironment('TG_API_HASH');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  if (!settings.hasApiCredentials && _apiId != 0 && _apiHash.isNotEmpty) {
    settings.update((s) {
      s.apiId = _apiId;
      s.apiHash = _apiHash;
    });
  }
  runApp(PhantomApp(settings: settings));
}
