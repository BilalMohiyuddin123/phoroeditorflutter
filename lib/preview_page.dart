import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Import Ads
import 'ad_config.dart'; // Import Config
import 'permissions_handler.dart';

class PreviewPage extends StatefulWidget {
  final Uint8List imageData;

  const PreviewPage({super.key, required this.imageData});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  double _glitchIntensity = 0;
  bool _glitchEnabled = false;
  bool _isSaving = false;
  ui.Image? _decodedImage;
  double _lastRenderedWidth = 1.0;

  // --- AD VARIABLES ---
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  @override
  void initState() {
    super.initState();
    _loadUiImage(widget.imageData);
    _loadBannerAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  // --- BANNER AD LOGIC ---
  void _loadBannerAd() {
    if (AdConfig.bannerAdUnit.isEmpty || !AdConfig.bPreview) return;

    _bannerAd = BannerAd(
      adUnitId: AdConfig.bannerAdUnit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isAdLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Preview Page Banner failed: $err');
          ad.dispose();
        },
      ),
    )..load();
  }
  // ----------------

  // --- SAVE BUTTON HANDLER ---
  void _handleSaveButton() {
    if (_isSaving) return;

    // 1. CONFLICT CHECK: If iSave=true AND rsave=true -> SHOW NO AD
    if (AdConfig.iSave && AdConfig.rSave) {
      _processSaveWithoutAd();
      return;
    }

    // 2. REWARD CHECK: rsave=true -> Show Reward Ad -> Then Save
    if (AdConfig.rSave && AdConfig.rewardAdUnit.isNotEmpty) {
      _loadAndShowRewardedAd();
      return;
    }

    // 3. INTERSTITIAL CHECK: isave=true -> Save -> Then Show Interstitial
    if (AdConfig.iSave && AdConfig.interstitialAdUnit.isNotEmpty) {
      _processSaveWithInterstitial();
      return;
    }

    // 4. DEFAULT: Just Save
    _processSaveWithoutAd();
  }

  // --- SCENARIO 1 & 4: Just Save ---
  void _processSaveWithoutAd() async {
    bool success = await _performSave();
    if (success && mounted) {
      _showCenteredSuccessDialog();
    }
  }

  // --- SCENARIO 2: Reward Ad (Safe Flow) ---
  void _loadAndShowRewardedAd() {
    setState(() => _isSaving = true); // Show Loading...

    RewardedAd.load(
      adUnitId: AdConfig.rewardAdUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;

          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            // A. If Ad fails to show (e.g. connection drop), SAVE IMMEDIATELY
              onAdFailedToShowFullScreenContent: (ad, err) {
                ad.dispose();
                _processSaveWithoutAd();
              },

              // B. When Ad is closed (Crossed OR Finished) -> SAVE
              // We use this single callback for both cases to prevent double-saving
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                // Add a tiny delay so the UI doesn't jump instantly
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (mounted) _processSaveWithoutAd();
                });
              }
          );

          if (mounted) {
            _rewardedAd!.show(
                onUserEarnedReward: (ad, reward) {
                  // We don't trigger save here anymore.
                  // We wait for the user to actually CLOSE the ad (onAdDismissedFullScreenContent)
                  // This is cleaner UX.
                }
            );
          }
        },
        onAdFailedToLoad: (err) {
          debugPrint('Reward Ad failed to load: $err');
          // Ad failed? Don't punish user. Just save.
          _processSaveWithoutAd();
        },
      ),
    );
  }

  // --- SCENARIO 3: Interstitial Ad (Save First, Ad Later) ---
  void _processSaveWithInterstitial() async {
    // A. Save Image First
    bool success = await _performSave();

    if (!success) return; // Failed to save, stop here

    // B. Show Success Dialog
    if (mounted) {
      await _showCenteredSuccessDialog(autoDismiss: true);
    }

    // C. Load and Show Interstitial
    if (mounted) {
      setState(() => _isSaving = true); // Show Spinner while fetching ad
    }

    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (mounted) setState(() => _isSaving = false);
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              if (mounted) setState(() => _isSaving = false);
            },
          );
          if (mounted) _interstitialAd!.show();
        },
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial failed: $err');
          if (mounted) setState(() => _isSaving = false);
        },
      ),
    );
  }

  // --- HELPER: ACTUAL SAVE LOGIC ---
  Future<bool> _performSave() async {
    if (_decodedImage == null) return false;
    // Don't set _isSaving = true here, it's already set by the caller

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(
          _decodedImage!.width.toDouble(), _decodedImage!.height.toDouble());

      double scaleFactor = _decodedImage!.width / _lastRenderedWidth;
      if (scaleFactor.isNaN || scaleFactor.isInfinite || scaleFactor == 0) {
        scaleFactor = 1.0;
      }

      final double savedIntensity = _glitchIntensity * scaleFactor;

      GlitchPainter(
          image: _decodedImage!,
          intensity: _glitchEnabled ? savedIntensity : 0)
          .paint(canvas, size);

      final picture = recorder.endRecording();
      final img =
      await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        bool success = await AppUtils.saveImageToGallery(bytes);
        // Don't turn off isSaving yet if we are going to show success dialog
        if (!success) setState(() => _isSaving = false);
        return success;
      }
    } catch (e) {
      debugPrint("Save error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
    setState(() => _isSaving = false);
    return false;
  }

  // --- HELPER: CENTERED SUCCESS DIALOG ---
  Future<void> _showCenteredSuccessDialog({bool autoDismiss = true}) async {
    // Ensure loading spinner is off before showing dialog
    setState(() => _isSaving = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black.withOpacity(0.8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
                SizedBox(height: 20),
                Text(
                  "Image Saved Successfully!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Auto dismiss after 1.5 seconds
    if (autoDismiss) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close dialog
      }
    }
  }

  Future<void> _loadUiImage(Uint8List data) async {
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    setState(() {
      _decodedImage = frame.image;
    });
  }

  void _editMore() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
            'PREVIEW',
            style: TextStyle(
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18
            )
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: _editMore,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _decodedImage == null
                  ? const CircularProgressIndicator()
                  : LayoutBuilder(
                builder: (context, constraints) {
                  final scaleX =
                      constraints.maxWidth / _decodedImage!.width;
                  final scaleY =
                      constraints.maxHeight / _decodedImage!.height;
                  final scale = scaleX < scaleY ? scaleX : scaleY;

                  final displayWidth = _decodedImage!.width * scale;
                  final displayHeight = _decodedImage!.height * scale;

                  _lastRenderedWidth = displayWidth;

                  return SizedBox(
                    width: displayWidth,
                    height: displayHeight,
                    child: CustomPaint(
                      size: Size(displayWidth, displayHeight),
                      painter: GlitchPainter(
                        image: _decodedImage!,
                        intensity: _glitchEnabled ? _glitchIntensity : 0,
                        previewSize: Size(displayWidth, displayHeight),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Enable Glitch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,      // Increase size (adjust as needed)
                      fontWeight: FontWeight.bold, // Make text bold
                    ),
                  ),

                  value: _glitchEnabled,
                  // UPDATED: Active color set to blue
                  activeColor: Colors.blueAccent,
                  onChanged: (val) => setState(() => _glitchEnabled = val),
                ),
                Row(
                  children: [
                    const Text('Intensity:',
                        style: TextStyle(color: Colors.white)),
                    Expanded(
                      // UPDATED: Slider Theme and removed divisions (dots)
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.blueAccent,
                          inactiveTrackColor: Colors.blueAccent.withOpacity(0.3),
                          thumbColor: Colors.blueAccent,
                          overlayColor: Colors.blueAccent.withOpacity(0.2),
                          trackHeight: 3.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                        ),
                        child: Slider(
                          min: 0,
                          max: 10,
                          // divisions: 20, // Removed dots
                          value: _glitchIntensity,
                          onChanged: _glitchEnabled
                              ? (val) => setState(() => _glitchIntensity = val)
                              : null,
                        ),
                      ),
                    ),
                    Text(_glitchIntensity.round().toString(),
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
// --- BUTTON ROW ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black, // Ensure background is black
            child: Row(
              children: [

                // --- 1. EDIT MORE (Glass + Glow like "Change") ---
                Expanded(
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.blueAccent,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.25),
                          blurRadius: 12,
                          spreadRadius: 0,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: _isSaving ? null : _editMore,
                      borderRadius: BorderRadius.circular(30),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.edit, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Edit More',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16), // spacing

                // --- 2. SAVE IMAGE (Gradient + Glow like "Next") ---
                Expanded(
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2979FF),
                          Color(0xFF448AFF),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.45),
                          blurRadius: 14,
                          spreadRadius: 5,
                          offset: Offset(0, 0),
                        ),
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.20),
                          blurRadius: 35,
                          spreadRadius: 12,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _isSaving ? null : _handleSaveButton,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _isSaving
                            ? [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Processing...',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ]
                            : const [
                          Text(
                            'Save',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.download, color: Colors.white, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),


          // --- BANNER AD SECTION ---
          if (_isAdLoaded && _bannerAd != null)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              color: Colors.black, // Matches background
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}

class GlitchPainter extends CustomPainter {
  final ui.Image image;
  final double intensity;
  final Size? previewSize;

  GlitchPainter({
    required this.image,
    required this.intensity,
    this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    final srcRect =
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

    final dstRect = previewSize != null
        ? Rect.fromLTWH(0, 0, previewSize!.width, previewSize!.height)
        : Rect.fromLTWH(0, 0, size.width, size.height);

    if (intensity == 0) {
      final basePaint = Paint()..filterQuality = FilterQuality.high;
      canvas.drawImageRect(image, srcRect, dstRect, basePaint);
      return;
    }

    // Red channel offset right
    paint.colorFilter = const ui.ColorFilter.matrix([
      1, 0, 0, 0, 0,
      0, 0, 0, 0, 0,
      0, 0, 0, 0, 0,
      0, 0, 0, 1, 0,
    ]);
    canvas.drawImageRect(
        image, srcRect, dstRect.shift(Offset(intensity, 0)), paint);

    // Green channel center
    paint.colorFilter = const ui.ColorFilter.matrix([
      0, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 0, 0, 0,
      0, 0, 0, 1, 0,
    ]);
    canvas.drawImageRect(image, srcRect, dstRect, paint);

    // Blue channel offset left
    paint.colorFilter = const ui.ColorFilter.matrix([
      0, 0, 0, 0, 0,
      0, 0, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ]);
    canvas.drawImageRect(
        image, srcRect, dstRect.shift(Offset(-intensity, 0)), paint);
  }

  @override
  bool shouldRepaint(covariant GlitchPainter oldDelegate) =>
      oldDelegate.intensity != intensity || oldDelegate.image != image;
}