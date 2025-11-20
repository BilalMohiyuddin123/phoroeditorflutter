import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // 1. Import Ads
import 'home_page.dart';
import 'splash_screen.dart';

void main() async {
  // 2. Ensure bindings are initialized before using plugins
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Initialize the Google Mobile Ads SDK
  await MobileAds.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nox Edit',
      // Keeps your existing theme exactly as you requested
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}