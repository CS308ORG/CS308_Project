import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';

import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyBJWPpOC95imcMPN_wydMBuVR6PSnexh-c",
      authDomain: "cs308-store.firebaseapp.com",
      projectId: "cs308-store",
      storageBucket: "cs308-store.firebasestorage.app",
      messagingSenderId: "622183565730",
      appId: "1:622183565730:web:4cf4e26cb439ad2a364afb",
      measurementId: "G-D87PLC55D",
    ),
  );
  
  // Restore auth session before running app
  await AuthService().initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Modern orange color palette
    const primaryOrange = Color(0xFFFF7733);
    const lightOrange = Color(0xFFFFA366);
    const darkOrange = Color(0xFFFF5500);
    const creamBackground = Color(0xFFFFF8F0);
    const softWhite = Color(0xFFFFFFFF);
    
    return MaterialApp(
      title: 'CS308 Store',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: primaryOrange,
        scaffoldBackgroundColor: creamBackground,
        colorScheme: ColorScheme.light(
          primary: primaryOrange,
          secondary: lightOrange,
          tertiary: darkOrange,
          surface: softWhite,
          background: creamBackground,
          error: Color(0xFFFF4444),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF333333),
          onBackground: Color(0xFF333333),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: primaryOrange),
          titleTextStyle: TextStyle(
            color: primaryOrange,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryOrange,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryOrange,
            side: BorderSide(color: primaryOrange, width: 1.5),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: softWhite,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: softWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryOrange, width: 2),
          ),
        ),
      ),
      home: HomeScreen(),
    );
  }
}