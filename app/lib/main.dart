import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/localization.dart';
import 'core/session.dart';
import 'core/signalr_chat.dart';
import 'features/auth/login_screen.dart';
import 'features/rooms/dang_phong_screen.dart';
import 'shell/app_shell.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ngonNgu = await NgonNgu.khoiDong();
  final session = Session();
  await session.khoiDong();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: ngonNgu),
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider(
          create: (_) => SignalRChat(layToken: () => session.api.token),
        ),
      ],
      child: const RoomFinderApp(),
    ),
  );
}

class RoomFinderApp extends StatelessWidget {
  const RoomFinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ngonNgu = context.watch<NgonNgu>();

    return MaterialApp(
      title: 'RoomFinder',
      debugShowCheckedModeBanner: false,
      locale: ngonNgu.locale,
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: NhaCai.mauChuDao),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      home: const AuthGate(),
      routes: {
        '/dang-phong': (_) => const DangPhongScreen(),
      },
    );
  }
}

/// Quyết định màn hình gốc theo phiên đăng nhập và giữ kết nối SignalR đúng lúc.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.watch<Session>();
    final chat = context.read<SignalRChat>();
    if (session.daDangNhap) {
      chat.ketNoi();
    } else {
      chat.ngat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    if (session.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return session.daDangNhap ? const AppShell() : const LoginScreen();
  }
}
