import 'package:music_life/config/app_config.dart';
import 'main.dart' as app;

Future<void> main() async {
  await app.runMusicLifeApp(AppConfig.dev());
}
