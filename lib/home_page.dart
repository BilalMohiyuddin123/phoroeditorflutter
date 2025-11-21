import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Import Ads

import 'ad_config.dart'; // Import Config
import 'bottom_bar.dart';
import 'effects_panel.dart';
import 'filters_panel.dart';
import 'permissions_handler.dart';
import 'text_panel.dart';
import 'photo_editor_screen.dart';
import 'preview_page.dart';
import 'adjust_panel.dart';

enum EditMode { none, filters, adjust, effects, text }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;
  bool _isImageConfirmed = false;

  EditMode _editMode = EditMode.none;
  bool _isLoading = false;

  final GlobalKey _imagePreviewKey = GlobalKey();

  // Filter state
  ColorMatrix _currentFilter = FilterMatrix.none;
  double _currentFilterIntensity = 1.0;

  // Effect state
  double _blur = 0.0;
  bool _vignette = false;
  double _vignetteIntensity = 0.4; // NEW: Vignette Intensity Variable
  String _selectedOverlayUrl = '';
  double _overlayIntensity = 0.5;

  // Text Engine State
  List<TextLayer> textLayers = [];
  String? selectedLayerId;

  TextLayer? get activeLayer {
    try {
      return textLayers.firstWhere((e) => e.id == selectedLayerId);
    } catch (e) {
      return null;
    }
  }

  // Adjustment state
  double _adjBrightness = 100.0;
  double _adjContrast = 100.0;
  double _adjSaturation = 100.0;
  double _adjSepia = 0.0;

  final Map<String, String> _overlayOptions = {
    'None': '',
    'Dust': 'assets/textures/dust.png',
    'Grain': 'assets/textures/bedge-grunge.png',
    'Gray': 'assets/textures/gray-paper.png',
    'Snow': 'assets/textures/nice-snow.png',
    'Midnight2': 'assets/textures/mid2.png',
    'T5': 'assets/textures/t5.png',
    'T4': 'assets/textures/t4.png',
    'T10': 'assets/textures/t10.png',
    'T11': 'assets/textures/t11.png'
  };

  // --- AD VARIABLES ---
  BannerAd? _selectBannerAd;
  bool _isSelectAdLoaded = false;

  BannerAd? _editorBannerAd;
  bool _isEditorAdLoaded = false;

  // Interstitial Ad
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _loadSelectBanner();
  }

  @override
  void dispose() {
    _selectBannerAd?.dispose();
    _editorBannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  // --- BANNER AD LOGIC ---
  void _loadSelectBanner() {
    if (AdConfig.bannerAdUnit.isEmpty || !AdConfig.bSelectP) return;
    _selectBannerAd = BannerAd(
      adUnitId: AdConfig.bannerAdUnit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isSelectAdLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Select Screen Banner failed: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  void _loadEditorBanner() {
    if (AdConfig.bannerAdUnit.isEmpty || !AdConfig.bHome) return;
    _editorBannerAd = BannerAd(
      adUnitId: AdConfig.bannerAdUnit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isEditorAdLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Editor Screen Banner failed: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  // --- NAVIGATION LOGIC ---
  void _handleNextButton() {
    if (!AdConfig.bInterstitial || AdConfig.interstitialAdUnit.isEmpty) {
      _goToEditor();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) async {
              ad.dispose();
              // Added 1.5s Delay here for smoothness
              await Future.delayed(const Duration(milliseconds: 1500));
              _goToEditor();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _goToEditor();
            },
          );

          if (mounted) {
            // _isLoading stays true here so the spinner/blur persists until we switch screens
            _interstitialAd!.show();
          }
        },
        onAdFailedToLoad: (err) {
          debugPrint('Interstitial failed to load: $err');
          if (mounted) {
            // If fail, stop loading and go
            setState(() => _isLoading = false);
            _goToEditor();
          }
        },
      ),
    );
  }

  void _goToEditor() {
    if (!mounted) return;
    setState(() {
      _isImageConfirmed = true;
      _isLoading = false;
    });

    _selectBannerAd?.dispose();
    _selectBannerAd = null;
    _isSelectAdLoaded = false;

    _loadEditorBanner();
  }

  void _handleBackFromEditor() {
    setState(() {
      _isImageConfirmed = false;
    });

    _editorBannerAd?.dispose();
    _editorBannerAd = null;
    _isEditorAdLoaded = false;

    _loadSelectBanner();
  }
  // ------------------------

  // --- OPTIMIZED PREVIEW LOGIC ---

  // 1. Helper to generate image data (Parallel Task)
  Future<Uint8List?> _generateImageBytes() async {
    try {
      RenderRepaintBoundary boundary = _imagePreviewKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error generating preview: $e");
      return null;
    }
  }

  // 2. Final Navigation Step
  void _finalizePreview(Uint8List? bytes) async {
    if (!mounted) return;

    if (bytes != null) {
      // Navigate to Preview Page
      // We keep _isLoading = true so the blur stays during transition
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewPage(imageData: bytes),
        ),
      );

      // Turn off loading ONLY when we come back to this screen (pop)
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate preview image')),
      );
    }
  }

  // 3. Main Handler
  void _handlePreviewTap() async {
    // A. ENABLE LOADING SCREEN IMMEDIATELY (Blur Background)
    setState(() {
      _isLoading = true;
    });

    // B. Prepare UI (Deselect text borders)
    setState(() {
      for (var layer in textLayers) layer.isSelected = false;
      selectedLayerId = null;
    });

    // C. Wait briefly for UI repaint to remove borders
    await Future.delayed(const Duration(milliseconds: 100));

    // D. START IMAGE GENERATION (Background)
    Future<Uint8List?> imageFuture = _generateImageBytes();

    // E. Check Ad Logic
    if (!AdConfig.iPreview || AdConfig.interstitialAdUnit.isEmpty) {
      // No Ad? Wait for image and go.
      final bytes = await imageFuture;
      _finalizePreview(bytes);
      return;
    }

    // F. Load Ad (While image generates in background)
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;

          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) async {
              ad.dispose();

              // UX IMPROVEMENT: Deliberate 1.5 second delay
              await Future.delayed(const Duration(milliseconds: 1500));

              // Ad Closed & Wait Over: Get Image
              final bytes = await imageFuture;
              _finalizePreview(bytes);
            },
            onAdFailedToShowFullScreenContent: (ad, err) async {
              ad.dispose();
              // If ad failed to show, just proceed normally
              final bytes = await imageFuture;
              _finalizePreview(bytes);
            },
          );

          if (mounted) {
            _interstitialAd!.show();
          }
        },
        onAdFailedToLoad: (err) async {
          debugPrint('Preview Interstitial failed: $err');
          // Ad Failed Load: Wait for image and go
          final bytes = await imageFuture;
          _finalizePreview(bytes);
        },
      ),
    );
  }
  // -------------------------------

  Future<void> _checkPermission() async {
    bool granted = await AppUtils.requestPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permission denied. Please grant permission.'),
        ),
      );
    }
  }

  Future<void> _selectPhoto() async {
    File? image = await AppUtils.pickImageFromGallery();
    if (image != null) {
      setState(() {
        _image = image;
        _isImageConfirmed = false;
        _resetEdits();
      });
    }
  }

  void _resetEdits() {
    setState(() {
      _currentFilter = FilterMatrix.none;
      _currentFilterIntensity = 1.0;
      _blur = 0.0;
      _vignette = false;
      _vignetteIntensity = 0.4; // NEW: Reset intensity
      textLayers.clear();
      selectedLayerId = null;
      _editMode = EditMode.none;
      _selectedOverlayUrl = '';
      _overlayIntensity = 0.3;
      _adjBrightness = 100.0;
      _adjContrast = 100.0;
      _adjSaturation = 100.0;
      _adjSepia = 0.0;
    });
  }

  void _addTextLayer({bool isDate = false}) {
    final existingIndex =
    textLayers.indexWhere((layer) => layer.isDateElement == isDate);

    if (existingIndex != -1) {
      setState(() {
        for (var layer in textLayers) layer.isSelected = false;
        textLayers[existingIndex].isSelected = true;
        selectedLayerId = textLayers[existingIndex].id;
      });
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      for (var layer in textLayers) layer.isSelected = false;

      textLayers.add(TextLayer(
        id: id,
        text: isDate
            ? DateFormat('dd/MM/yy').format(DateTime.now())
            : "Tap",
        fontFamily: isDate ? 'Orbitron' : 'Roboto',
        position: isDate ? const Offset(20, 100) : const Offset(100, 200),
        isDateElement: isDate,
        color: isDate ? Colors.orangeAccent : Colors.white,
        fontSize: isDate ? 19.0 : 32.0,
        isSelected: true,
        isVertical: false,
      ));
      selectedLayerId = id;
    });
  }

  void _updateLayer(
      {Color? color,
        double? size,
        String? text,
        String? font,
        bool? isVertical}) {
    if (selectedLayerId == null) return;
    setState(() {
      final index = textLayers.indexWhere((e) => e.id == selectedLayerId);
      if (index != -1) {
        if (color != null) textLayers[index].color = color;
        if (size != null) textLayers[index].fontSize = size;
        if (text != null) textLayers[index].text = text;
        if (font != null) textLayers[index].fontFamily = font;
        if (isVertical != null) textLayers[index].isVertical = isVertical;
      }
    });
  }

  void _onBottomBarTapped(EditMode mode) {
    setState(() {
      _editMode = (_editMode == mode) ? EditMode.none : mode;
      if (_editMode != EditMode.text) {
        for (var layer in textLayers) layer.isSelected = false;
        selectedLayerId = null;
      }
    });
  }

  Widget _buildEditorPanel() {
    switch (_editMode) {
      case EditMode.filters:
        return FiltersPanel(
          activeFilter: _currentFilter,
          onFilterSelected: (matrix) => setState(() {
            _currentFilter = matrix;
            _currentFilterIntensity = 1.0;
          }),
          intensity: _currentFilterIntensity,
          onIntensityChanged: (val) =>
              setState(() => _currentFilterIntensity = val),
          imagePreviewProvider: FileImage(_image!),
        );

      case EditMode.adjust:
        return AdjustPanel(
          blur: _blur,
          onBlurChanged: (v) => setState(() => _blur = v),
          brightness: _adjBrightness,
          onBrightnessChanged: (v) => setState(() => _adjBrightness = v),
          contrast: _adjContrast,
          onContrastChanged: (v) => setState(() => _adjContrast = v),
          sepia: _adjSepia,
          onSepiaChanged: (v) => setState(() => _adjSepia = v),
        );

      case EditMode.effects:
        return EffectsPanel(
          vignette: _vignette,
          onVignetteChanged: (v) => setState(() => _vignette = v),
          // NEW: Pass the intensity values to the panel
          vignetteValue: _vignetteIntensity,
          onVignetteValueChanged: (v) => setState(() => _vignetteIntensity = v),

          overlayOptions: _overlayOptions,
          selectedOverlayUrl: _selectedOverlayUrl,
          overlayIntensity: _overlayIntensity,
          onOverlayChanged: (url) {
            setState(() {
              _selectedOverlayUrl = url;
              if (url.isNotEmpty && _overlayIntensity == 0.0) {
                _overlayIntensity = 0.5;
              }
            });
          },
          onOverlayIntensityChanged: (v) =>
              setState(() => _overlayIntensity = v),
        );

      case EditMode.text:
        return SmartTextPanel(
          selectedLayer: activeLayer,
          onAddNewText: () => _addTextLayer(isDate: false),
          onAddNewDate: () => _addTextLayer(isDate: true),
          onColorChanged: (color) => _updateLayer(color: color),
          onSizeChanged: (size) => _updateLayer(size: size),
          onTextChanged: (text) => _updateLayer(text: text),
          onFontChanged: (font) => _updateLayer(font: font),
          onVerticalChanged: (val) => _updateLayer(isVertical: val),
          onClose: () {
            setState(() {
              selectedLayerId = null;
              for (var layer in textLayers) layer.isSelected = false;
            });
          },
        );

      case EditMode.none:
      default:
        return const SizedBox.shrink();
    }
  }

  ColorMatrix _getInterpolatedMatrix() {
    ColorMatrix filterMatrix;
    if (_currentFilterIntensity == 1.0) {
      filterMatrix = _currentFilter;
    } else {
      final List<double> from = FilterMatrix.none;
      final List<double> to = _currentFilter;
      final List<double> result = List.filled(20, 0.0);
      for (int i = 0; i < 20; i++) {
        result[i] = from[i] + (to[i] - from[i]) * _currentFilterIntensity;
      }
      filterMatrix = result;
    }

    final adjMatrix = FilterMatrix.buildMatrix(
      brightness: _adjBrightness,
      contrast: _adjContrast,
      saturation: _adjSaturation,
      sepia: _adjSepia,
      hue: 0,
    );

    return FilterMatrix.multiply(adjMatrix, filterMatrix);
  }

  @override
  Widget build(BuildContext context) {
    double panelHeight = 0;
    if (_isImageConfirmed) {
      if (_editMode == EditMode.effects || _editMode == EditMode.adjust) {
        panelHeight = 200;
      } else if (_editMode == EditMode.filters) {
        panelHeight = 180;
      } else if (_editMode == EditMode.text) {
        panelHeight = 280;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        centerTitle: true,
        // 1. Back Button (Only shows when editing)
        leading: _isImageConfirmed
            ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: _handleBackFromEditor,
        )
            : null,

        // 2. Title Logic (Hidden when editing, Visible on Home)
        title: _isImageConfirmed
            ? null
            : RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 22, fontFamily: 'Roboto'),
            children: [
              const TextSpan(
                text: 'NOX',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              TextSpan(
                text: 'EDITOR',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w300,
                  letterSpacing: 3.5,
                ),
              ),
            ],
          ),
        ),

        // 3. Actions (The Sexy Preview Button)
        actions: [
          if (_isImageConfirmed && !_isLoading)
            Center(
      child: Container(
      height: 44, // Bigger & more clickable
      constraints: const BoxConstraints(minWidth: 110), // Wider for elegance
      margin: const EdgeInsets.only(right: 20), // More space from right
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),

        // Elegant Blue Gradient
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2979FF), // Darker Blue
            Color(0xFF448AFF), // Lighter Blue
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        // No outer glow
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: _handlePreviewTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15, // Slightly bigger text
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    ),
            ),
    ],
      ),
      body: Stack(
        children: [
          // 1. Main App Content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: _isImageConfirmed
                        ? _buildPhotoView()
                        : _buildSelectOrConfirmView(),
                  ),
                ),
                if (_isImageConfirmed) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: panelHeight,
                    child: _buildEditorPanel(),
                  ),
                  const SizedBox(height: 8),
                  BottomBar(onTap: _onBottomBarTapped, currentMode: _editMode),
                ],
                _buildDynamicAd(),
              ],
            ),
          ),

          // 2. LOADING OVERLAY (Blur + Spinner)
          if (_isLoading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 20),
                        Text(
                          "Loading...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectOrConfirmView() {
    if (_image == null) {
      return Container(
        width: double.infinity,
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),

// 1. HEADER WITH GRADIENT
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.blueAccent, Colors.purpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: const Text(
                "Edit\nLike a Pro",
                style: TextStyle(
                  color: Colors.white, // Required for ShaderMask to work
                  fontSize: 40,
                  fontWeight: FontWeight.w800, // Extra bold for impact
                  height: 1.1,
                  letterSpacing: -1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Import a photo to start editing.",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5), // Subtle transparency
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 40),

            // 2. THE SQUARE DROP ZONE
            GestureDetector(
              onTap: _selectPhoto,
              child: Container(
                // Fixed height makes it look like a square/card
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  // Subtle Glass Gradient
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.02)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  // Clean thin border
                  border: Border.all(color: Colors.white10, width: 1.5),
                  // Soft Glow behind the box
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.08),
                      blurRadius: 50,
                      spreadRadius: -10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The Glowing Add Button
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Colors.blueAccent, Color(0xFF2979FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withOpacity(0.5),
                            blurRadius: 25,
                            spreadRadius: 5,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 35),
                    ),
                    const SizedBox(height: 25),
                    const Text(
                      "Tap to Choose Image",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                  ],
                ),
              ),
            ),

            const Spacer(),

          ],
        ),
      );
    } else {
      // --- CONFIRMATION SCREEN (UNCHANGED) ---
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_image!, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Row(
              children: [

                // --- 1. THE "CHANGE" BUTTON (Glass + Subtle Glow) ---
                Expanded(
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.blueAccent,
                          width: 1.5
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
                      onTap: _isLoading ? null : _selectPhoto,
                      borderRadius: BorderRadius.circular(30),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Change',
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

                const SizedBox(width: 15), // Spacing

                // --- 2. THE "NEXT" BUTTON (Solid + OUTER GLOW FIXED) ---
// --- 2. THE "NEXT" BUTTON (Perfect 4-Sided Glow) ---
                Expanded(
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),

                      // Gradient background
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2979FF),
                          Color(0xFF448AFF),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),

                      // 🌟 Perfect 4-Side Glow (Outer Aura)
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.45),
                          blurRadius: 14,
                          spreadRadius: 5,      // KEY: pushes glow outwards on all sides
                          offset: const Offset(0, 0), // no direction → even 4-side glow
                        ),
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.20),
                          blurRadius: 35,        // bigger, softer outer glow
                          spreadRadius: 12,
                          offset: const Offset(0, 0),
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
                      onPressed: _isLoading ? null : _handleNextButton,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildDynamicAd() {
    BannerAd? adToShow;
    bool isLoaded = false;

    if (!_isImageConfirmed) {
      if (AdConfig.bSelectP && _isSelectAdLoaded) {
        adToShow = _selectBannerAd;
        isLoaded = true;
      }
    } else {
      if (AdConfig.bHome && _isEditorAdLoaded) {
        adToShow = _editorBannerAd;
        isLoaded = true;
      }
    }

    if (!isLoaded || adToShow == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: adToShow.size.width.toDouble(),
      height: adToShow.size.height.toDouble(),
      child: AdWidget(ad: adToShow),
    );
  }

  Widget _buildPhotoView() {
    return GestureDetector(
      onTap: () {
        if (selectedLayerId != null) {
          setState(() {
            for (var layer in textLayers) layer.isSelected = false;
            selectedLayerId = null;
          });
        }
      },
      child: RepaintBoundary(
        key: _imagePreviewKey,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              child: ImageFiltered(
                imageFilter:
                ui.ImageFilter.blur(sigmaX: _blur * 5, sigmaY: _blur * 5),
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(_getInterpolatedMatrix()),
                  child: Image.file(_image!, fit: BoxFit.cover),
                ),
              ),
            ),
            // NEW: VIGNETTE OVERLAY with Dynamic Intensity
            if (_vignette)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(_vignetteIntensity) // NEW
                      ],
                      stops: const [0.2, 1.0], // Tweaked for smoother gradient
                    ),
                  ),
                ),
              ),
            if (_selectedOverlayUrl.isNotEmpty && _overlayIntensity > 0.0)
              Positioned.fill(
                child: Opacity(
                  opacity: _overlayIntensity,
                  child: Image.asset(
                    _selectedOverlayUrl,
                    fit: BoxFit.cover,
                    repeat: ImageRepeat.repeat,
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),
            ...textLayers.map((layer) {
              return DraggableTextWidget(
                layer: layer,
                onTap: () {
                  if (_editMode != EditMode.text) {
                    setState(() => _editMode = EditMode.text);
                  }
                  setState(() {
                    for (var l in textLayers) l.isSelected = (l.id == layer.id);
                    selectedLayerId = layer.id;
                  });
                },
                onDrag: (offset) {
                  setState(() => layer.position += offset);
                },
                onDelete: () {
                  setState(() {
                    textLayers.removeWhere((e) => e.id == layer.id);
                    selectedLayerId = null;
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}