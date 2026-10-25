import 'package:flutter/material.dart';

import 'core/services.dart';
import 'core/settings.dart';
import 'features/auth/api_credentials_screen.dart';
import 'features/auth/auth_screen.dart';
import 'features/chats/home_screen.dart';
import 'features/theme/app_theme.dart';

typedef ServicesStarter = Future<Services> Function(AppSettings settings);

class PhantomApp extends StatelessWidget {
  const PhantomApp({super.key, required this.settings, this.startServices = Services.start, this.navigatorKey});

  final AppSettings settings;
  final ServicesStarter startServices;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final t = settings.theme;
        return MaterialApp(
          title: 'Phantomgram',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(t, Brightness.light),
          darkTheme: buildTheme(t, Brightness.dark),
          themeMode: themeModeOf(t),
          // The builder wraps the Navigator, so pushed routes see AppScope too.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(t.fontScale)),
            child: ServicesHost(settings: settings, start: startServices, child: child!),
          ),
          home: RootScreen(settings: settings),
        );
      },
    );
  }
}

/// Owns the TDLib client; recreates it after log-out (TDLib closes itself).
class ServicesHost extends StatefulWidget {
  const ServicesHost({super.key, required this.settings, required this.start, required this.child});

  final AppSettings settings;
  final ServicesStarter start;
  final Widget child;

  @override
  State<ServicesHost> createState() => _ServicesHostState();
}

class _ServicesHostState extends State<ServicesHost> {
  Services? _services;
  Object? _error;
  bool _starting = false;

  Future<void> _start() async {
    _starting = true;
    try {
      final services = await widget.start(widget.settings);
      services.auth.addListener(() => _onAuth(services));
      if (!mounted) return;
      setState(() => _services = services);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      _starting = false;
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
    if (widget.settings.hasApiCredentials && _services == null && _error == null && !_starting) {
      _start();
    }
    return AppScope(services: _services, error: _error, child: widget.child);
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    if (!settings.hasApiCredentials) return ApiCredentialsScreen(settings: settings);
    final error = AppScope.errorOf(context);
    if (error != null) return StartupErrorScreen(error: error);
    final services = AppScope.maybeOf(context);
    if (services == null) return const SplashScreen();
    return ListenableBuilder(
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
