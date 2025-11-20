import 'dart:async'; // Required for TimeoutException
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Import Ads Package
import 'ad_config.dart';
import 'home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isError = false;
  bool _isLoading = true;
  String _errorMessage = "";
  AppOpenAd? _appOpenAd;

  @override
  void initState() {
    super.initState();
    _fetchAdConfig();
  }

  Future<void> _fetchAdConfig() async {
    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = "";
    });

    const String url = "https://securepayments.live/bilal/adsphoto.json";

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // --- FILL VARIABLES ---
        AdConfig.bannerAdUnit = data['banneradunit'] ?? "";
        AdConfig.openAdUnit = data['openadunit'] ?? "";
        AdConfig.rewardAdUnit = data['rewardadunit'] ?? "";
        AdConfig.interstitialAdUnit = data['interstitialadunit'] ?? "";

        AdConfig.bHome = data['bhome'] ?? false;
        AdConfig.bInterstitial = data['binterstitial'] ?? false;
        AdConfig.appopen = data['appopen'] ?? false;

        AdConfig.bPreview = data['bpreview'] ?? false;
        AdConfig.iPreview = data['ipreview'] ?? false;
        AdConfig.iSave = data['isave'] ?? false;
        AdConfig.bSelectP = data['bselectp'] ?? false;
        AdConfig.rSave = data['rsave'] ?? false; // Added rsave
        // ---------------------

        debugPrint("Ads Config Loaded Successfully");

        if (mounted) {
          _decideNextStep();
        }
      } else {
        throw const HttpException("Invalid response from server");
      }
    } on TimeoutException catch (_) {
      _handleError("Connection timed out. Please check your internet.");
    } on SocketException catch (_) {
      _handleError("No internet connection.");
    } catch (e) {
      _handleError("Error loading resources. Please try again.");
      debugPrint("Config Error: $e");
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = message;
      });
    }
  }

  void _decideNextStep() {
    if (AdConfig.appopen && AdConfig.openAdUnit.isNotEmpty) {
      _loadAndShowAppOpenAd();
    } else {
      _navigateToHome();
    }
  }

  void _loadAndShowAppOpenAd() {
    AppOpenAd.load(
      adUnitId: AdConfig.openAdUnit,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _showAd();
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: $error');
          _navigateToHome();
        },
      ),
    );
  }

  void _showAd() {
    if (_appOpenAd == null) {
      _navigateToHome();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _navigateToHome();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _navigateToHome();
      },
    );

    _appOpenAd!.show();
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "NOx Edit",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontFamily: 'Orbitron',
                ),
              ),
              const SizedBox(height: 50),
              if (_isLoading) ...[
                const CircularProgressIndicator(color: Colors.blueAccent),
                const SizedBox(height: 20),
                const Text(
                  "Loading resources...",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ] else if (_isError) ...[
                const Icon(Icons.wifi_off, size: 50, color: Colors.redAccent),
                const SizedBox(height: 20),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _fetchAdConfig,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                  ),
                  child: const Text(
                    "RETRY",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}