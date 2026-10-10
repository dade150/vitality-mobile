import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart';

import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/user_provider.dart';
import 'providers/health_provider.dart';
import 'providers/appointments_provider.dart';
import 'providers/reports_provider.dart';
import 'providers/clinical_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/auth_provider.dart';

import 'services/error_handler.dart';
import 'services/supabase_client.dart';

import 'theme/app_theme.dart';

import 'screens/auth/login_screen.dart';
import 'screens/diary/diary_screen.dart';
import 'screens/diary/add_activity_screen.dart';
import 'screens/diary/add_meal_screen.dart';
import 'screens/error/error_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/reports/clinical_screen.dart';
import 'screens/reports/add_report_screen.dart';
import 'screens/appointments/appointments_screen.dart';
import 'screens/appointments/add_visit_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/therapy_config_screen.dart';
import 'utils/navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  await initializeDateFormatting('it_IT', null);

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('FlutterError: ${details.exceptionAsString()}\n${details.stack}');
    }
    // Solo log: navigare qui dentro (errore di rendering/layout) può
    // innescare un loop di rebuild. La schermata di errore la mostra
    // solo ErrorHandler.handle per gli errori classificati come imprevisti.
    ErrorHandler.logOnly(details.exception, details.stack, 'FlutterError.onError');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      // In debug NON sopprimiamo l'errore: altrimenti un'eccezione asincrona
      // (es. durante una rebuild subito dopo il login) sparisce senza lasciare
      // traccia, e dall'esterno sembra solo che l'app "si blocchi" senza un
      // perché. Restituiamo false e Flutter stampa l'errore con lo stack.
      ErrorHandler.logOnly(error, stack, 'PlatformDispatcher.onError');
      return false;
    }
    // In release l'app non deve crashare: ErrorHandler classifica l'errore e,
    // se è imprevisto, mostra la schermata di errore invece di lasciare l'app
    // in uno stato rotto. Ritorna true => l'errore è considerato gestito.
    ErrorHandler.handle(error, stack, 'PlatformDispatcher.onError');
    return true;
  };

  runApp(const VitalityAssistApp());
}

class VitalityAssistApp extends StatelessWidget {
  const VitalityAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => HealthProvider()),
        ChangeNotifierProvider(create: (_) => AppointmentsProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => ClinicalProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const _AuthRedirector(
        child: _AppWithTheme(),
      ),
    );
  }
}

/// Ascolta [AuthProvider] a livello globale ed è l'UNICA fonte di
/// navigazione legata all'autenticazione: login, logout, e sessione già
/// valida trovata a un avvio a freddo (token persistito).
///
/// `MaterialApp` qui sotto ha sempre `initialRoute: '/login'` fisso: un
/// `initialRoute` "reattivo" non esiste in Flutter, viene letto una sola
/// volta alla creazione del Navigator — riassegnarlo in una rebuild
/// successiva non lo fa saltare da nessuna parte, è un no-op silenzioso.
class _AuthRedirector extends StatefulWidget {
  final Widget child;
  const _AuthRedirector({required this.child});

  @override
  State<_AuthRedirector> createState() => _AuthRedirectorState();
}

class _AuthRedirectorState extends State<_AuthRedirector> {
  bool _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();

      // Avvio a freddo con sessione già valida: si parte comunque da
      // /login per un frame, poi si salta subito a /diary.
      if (auth.isAuthenticated) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/diary', (route) => false);
      }

      _wasAuthenticated = auth.isAuthenticated;
      auth.addListener(_onAuthChanged);
    });
  }

  void _onAuthChanged() {
    final auth = context.read<AuthProvider>();
    final isAuthenticated = auth.isAuthenticated;

    if (isAuthenticated && !_wasAuthenticated) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/diary', (route) => false);
    } else if (!isAuthenticated && _wasAuthenticated) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
    }

    _wasAuthenticated = isAuthenticated;
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _AppWithTheme extends StatelessWidget {
  const _AppWithTheme();

  @override
  Widget build(BuildContext context) {
    // Solo ThemeProvider qui: AuthProvider non deve più far ricostruire
    // MaterialApp a ogni cambio di stato (loading, errore, ecc.) — ci pensa
    // interamente _AuthRedirector alla navigazione legata all'autenticazione.
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Vitality Assist',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginScreen(),
            '/diary': (context) => const DiaryScreen(),
            '/history': (context) => const HistoryScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/chat': (context) => const ChatScreen(),
            '/reports': (context) => const ClinicalParametersScreen(),
            '/reports/add': (context) => const AddReportScreen(),
            '/appointments': (context) => const AppointmentsScreen(),
            '/appointments/add': (context) => const AddVisitScreen(),
            '/diary/add-activity': (context) => const AddActivityScreen(),
            '/diary/add-meal': (context) => const AddMealScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/settings/therapy': (context) => const TherapyConfigScreen(),
            // Spinta da ErrorHandler (errori imprevisti) via navigatorKey.
            '/error': (context) => const ErrorScreen(),
          },
        );
      },
    );
  }
}