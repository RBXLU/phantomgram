import 'package:flutter/material.dart';

import 'core/services.dart';
import 'core/settings.dart';
import 'features/auth/api_credentials_screen.dart';
import 'features/auth/auth_screen.dart';
import 'features/chats/home_screen.dart';
import 'features/theme/app_theme.dart';

class PhantomApp extends StatelessWidget {
  const PhantomApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final t = settings.theme;
        return MaterialApp(
          title: 'Phantomgram',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(t, Brightness.light),
          darkTheme: buildTheme(t, Brightness.dark),
          themeMode: themeModeOf(t),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(t.fontScale)),
            child: child!,
          ),
          home: settings.hasApiCredentials ? Bootstrap(settings: settings) : ApiCredentialsScreen(settings: settings),
        );
      },
    );
  }
}

/// Owns the TDLib client; recreates it after log-out (TDLib closes itself).
class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  Services? _services;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final services = await Services.start(widget.settings);
      services.auth.addListener(() => _onAuth(services));
      if (!mounted) return;
      setState(() => _services = services);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _onAuth(Services services) async {
    if (!services.auth.isClosed || _services != services) return;
    setState(() => _services = null);
    await services.dispose();
    await _start();
  }

  @override
  void dispose() {
    _services?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return StartupErrorScreen(error: _error!);
    final services = _services;
    if (services == null) return const SplashScreen();
    return AppScope(
      services: services,
      child: ListenableBuilder(
        listenable: services.auth,
        builder: (context, _) {
          final auth = services.auth;
          if (auth.isReady) return const HomeScreen();
          return switch (auth.stateType) {
            'authorizationStateWaitTdlibParameters' ||
            'authorizationStateLoggingOut' ||
            'authorizationStateClosing' ||
            'authorizationStateClosed' => SplashScreen(message: auth.error),
            _ => const AuthScreen(),
          };
        },
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.blur_on, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            if (message == null) const CircularProgressIndicator() else Text(message!),
          ],
        ),
      ),
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 12),
              const Text('Не удалось запустить TDLib', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              SelectableText(
                '$error\n\nПроверьте, что libtdjson собрана: scripts/build_tdlib_linux.sh '
                '(или scripts/build_tdlib_ios.sh для iOS).',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
