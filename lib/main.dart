import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/app_settings.dart';
import 'core/local_db.dart';
import 'core/theme.dart';
import 'models/models.dart';
import 'screens/daftar_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/game_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/register_screen.dart';
import 'screens/saran_kesan_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/sukses_screen.dart';
import 'screens/tutor_ai_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/notifikasi_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDb.init(); // Hive: database lokal
  await ApiClient.init(); // Supabase: database online
  await NotifikasiService.init();
  await AppSettings.i.muatLokal(); // mata uang & zona dari Hive
  runApp(const LesGoApp());
}

class LesGoApp extends StatelessWidget {
  const LesGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LesGo',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: navigatorKey,
      initialRoute: '/',
      onGenerateRoute: _route,
    );
  }

  Route<dynamic> _route(RouteSettings s) {
    Widget page;
    switch (s.name) {
      case '/welcome':
        page = const WelcomeScreen();
        break;
      case '/login':
        page = const LoginScreen();
        break;
      case '/register':
        page = const RegisterScreen();
        break;
      case '/home':
        page = const MainShell();
        break;
      case '/detail':
        page = DetailScreen(bimbelId: s.arguments as int);
        break;
      case '/daftar':
        final a = s.arguments as DaftarArgs;
        page = DaftarScreen(detail: a.detail, program: a.program);
        break;
      case '/sukses':
        page = SuksesScreen(pendaftaran: s.arguments as Pendaftaran);
        break;
      case '/saran':
        page = const SaranKesanScreen();
        break;
      case '/tutor':
        page = const TutorAiScreen();
        break;
      case '/game':
        page = const GameScreen();
        break;
      default:
        page = const SplashScreen();
    }
    return MaterialPageRoute(builder: (_) => page, settings: s);
  }
}
