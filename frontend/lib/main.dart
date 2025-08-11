// main.dart
import 'package:flutter/material.dart';
import 'ui/service_dashboard.dart';

void main() {
  runApp(const ServerwatcherApp());
}

class ServerwatcherApp extends StatelessWidget {
  const ServerwatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    const purpleDark = Color.fromRGBO(18, 4, 34, 1);
    const bg = Color.fromRGBO(11, 1, 24, 1);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color.fromARGB(255, 70, 22, 204),
      brightness: Brightness.dark,
      primary: const Color.fromARGB(255, 108, 7, 224),
      onPrimary: const Color.fromARGB(255, 219, 206, 255),
      secondary: const Color.fromARGB(255, 236, 204, 60),
      onSecondary: const Color.fromARGB(255, 255, 254, 249),
      surface: purpleDark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: bg,

        appBarTheme: AppBarTheme(
          centerTitle: false,
          backgroundColor: purpleDark,
          elevation: 0,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: colorScheme.secondary),
        ),

        cardTheme: CardThemeData(
          color: colorScheme.surface,
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF201B3D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          labelStyle: const TextStyle(color: Colors.white70),
        ),

        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.secondary,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ),

        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: colorScheme.surface,
        ),
      ),
      home: const ServiceDashboard(),
    );
  }
}
