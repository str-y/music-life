import 'config/app_config.dart';
import 'main.dart' as app;

Future<void> main() async {
  await app.runMusicLifeApp(AppConfig.prod());
}
