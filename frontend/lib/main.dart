import 'package:flutter/material.dart';
import 'ui/service_dashboard.dart';

void main() {
  runApp(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF8E24AA),
          primary: Color(0xFF8E24AA),
          secondary: Color(0xFFFFD700),
          background: Color(0xFF1B1433),
          brightness: Brightness.dark,
        ),
        cardTheme: CardTheme(
          color: Color(0xFF8E24AA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF4A148C),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFFFFD700)),
        ),
        iconTheme: IconThemeData(color: Color(0xFFFFD700)),
      ),

      home: Scaffold(
        appBar: AppBar(title: const Text('Serverwatcher')),
        body: const ServiceDashboard(),
      ),
    ),
  );
}
