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
            : "Double Tap",
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
        panelHeight = 220;
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
        leading: _isImageConfirmed
            ? IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _handleBackFromEditor,
        )
            : null,
        title: const Text('Photo Editor', style: TextStyle(color: Colors.white)),
        actions: [
          // Hide preview button if loading (so you can't double tap)
          if (_isImageConfirmed && !_isLoading)
            TextButton(
              onPressed: _handlePreviewTap,
              child: const Text('Preview',
                  style: TextStyle(
                      color: Colors.blueAccent, fontWeight: FontWeight.bold)),
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
                        CircularProgressIndicator(color: Colors.blueAccent),
                        SizedBox(height: 20),
                        Text(
                          "Loading...", // Simplified text for reuse
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
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, size: 80, color: Colors.grey[800]),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            onPressed: _selectPhoto,
            child: const Text('Select Photo',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      );
    } else {
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
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: _isLoading ? null : _selectPhoto,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Change Photo',
                      style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  onPressed: _isLoading ? null : _handleNextButton,
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Next',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            if (_vignette)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8)
                      ],
                      stops: const [0.4, 1.0],
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