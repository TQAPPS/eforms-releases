import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EFormsApp());
}

class EFormsApp extends StatefulWidget {
  const EFormsApp({super.key});

  @override
  State<EFormsApp> createState() => _EFormsAppState();
}

class _EFormsAppState extends State<EFormsApp> {
  // Theme Mode Notifier for instant toggling between Light and Dark mode
  final ValueNotifier<ThemeMode> _themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  @override
  void dispose() {
    _themeModeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'النماذج الرقمية',
          debugShowCheckedModeBanner: false,

          // Theme configurations
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,

          // Arabic RTL and Localization setup
          locale: const Locale('ar', 'SA'),
          supportedLocales: const [
            Locale('ar', 'SA'),
            Locale('ar', ''),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // Main Home Screen
          home: HomeScreen(themeModeNotifier: _themeModeNotifier),
        );
      },
    );
  }
}
