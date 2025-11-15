// home_page.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'bottom_bar.dart';
import 'effects_panel.dart';
import 'filters_panel.dart';
import 'permissions_handler.dart';
import 'text_panel.dart';
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
  // (Chroma state removed)

  // Text state
  String _textOnImage = "";
  TextStyle _textStyle = const TextStyle(
    color: Colors.white,
    fontSize: 40,
    fontWeight: FontWeight.bold,
    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
  );

  // --- Adjustment state ---
  double _adjBrightness = 100.0;
  double _adjContrast = 100.0;
  double _adjSaturation = 100.0; // This is for the color matrix
  double _adjSepia = 0.0;
  // -----------------------------

  final Map<String, String> _overlayOptions = {
    'None': '',
    'Dust': 'assets/textures/dust.png',
    'Grain': 'assets/textures/bedge-grunge.png',
    'Scratches': 'assets/textures/black-orchid.png',
    'Gray': 'assets/textures/gray-paper.png',
    'Snow': 'assets/textures/nice-snow.png',
    'Midnight': 'assets/textures/mid.png',
    'Midnight2': 'assets/textures/mid2.png'
  };

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    bool granted = await AppUtils.requestPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Permission denied. Please grant permission to select photos.'),
        ),
      );
    }
  }

  Future<void> _selectPhoto() async {
    File? image = await AppUtils.pickImageFromGallery();
    if (image != null) {
      setState(() {
        _image = image;
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
      _textOnImage = "";
      _editMode = EditMode.none;
      _selectedOverlayUrl = '';
      _overlayIntensity = 0.3;
      // (Chroma reset removed)
      _adjBrightness = 100.0;
      _adjContrast = 100.0;
      _adjSaturation = 100.0;
      _adjSepia = 0.0;
    });
  }

  Future<void> _goToPreview() async {
    setState(() {
      _isLoading = true;
    });
    try {
      RenderRepaintBoundary boundary = _imagePreviewKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewPage(imageData: pngBytes),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred generating preview: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onBottomBarTapped(EditMode mode) {
    setState(() {
      _editMode = (_editMode == mode) ? EditMode.none : mode;
    });
  }

  Widget _buildEditorPanel() {
    switch (_editMode) {
      case EditMode.filters:
        return FiltersPanel(
          onFilterSelected: (matrix) {
            setState(() {
              _currentFilter = matrix;
              _currentFilterIntensity = 1.0;
            });
          },
          intensity: _currentFilterIntensity,
          onIntensityChanged: (intensity) {
            setState(() {
              _currentFilterIntensity = intensity;
            });
          },
          imagePreviewProvider: FileImage(_image!),
        );

      case EditMode.adjust:
        return AdjustPanel(
          // Blur
          blur: _blur,
          onBlurChanged: (value) {
            setState(() {
              _blur = value;
            });
          },
          // Adjustments
          brightness: _adjBrightness,
          onBrightnessChanged: (value) {
            setState(() {
              _adjBrightness = value;
            });
          },
          contrast: _adjContrast,
          onContrastChanged: (value) {
            setState(() {
              _adjContrast = value;
            });
          },
          sepia: _adjSepia,
          onSepiaChanged: (value) {
            setState(() {
              _adjSepia = value;
            });
          },
        );

    // --- UPDATED EFFECTS CASE ---
      case EditMode.effects:
        return EffectsPanel(
          vignette: _vignette,
          onVignetteChanged: (value) {
            setState(() {
              _vignette = value;
            });
          },
          // Grain (Overlays)
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
          onOverlayIntensityChanged: (value) {
            setState(() {
              _overlayIntensity = value;
            });
          },
          // (Chroma params removed)
        );
    // ----------------------------

      case EditMode.text:
        return TextPanel(
          onTextAdded: (text) {
            setState(() {
              _textOnImage = text;
            });
          },
        );
      case EditMode.none:
      default:
        return const SizedBox.shrink();
    }
  }

  ColorMatrix _getInterpolatedMatrix() {
    // 1. Get the base filter
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

    // 2. Build adjustment matrix (We removed the Saturation slider,
    //    but still use the value from state for the matrix calculation)
    final adjMatrix = FilterMatrix.buildMatrix(
      brightness: _adjBrightness,
      contrast: _adjContrast,
      saturation: _adjSaturation, // This is color saturation
      sepia: _adjSepia,
      hue: 0,
    );

    // 3. Multiply them together
    return FilterMatrix.multiply(adjMatrix, filterMatrix);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo Editor'),
        actions: [
          if (_image != null && !_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _goToPreview,
                child: const Text(
                  'Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Center(
                child: _image == null
                    ? _buildSelectPhotoView()
                    : _buildPhotoView(),
              ),
            ),
            if (_image != null) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                // --- UPDATED HEIGHTS ---
                height: _editMode == EditMode.none
                    ? 0
                    : _editMode == EditMode.effects
                    ? 220 // Adjusted height (was 340)
                    : _editMode == EditMode.adjust
                    ? 220
                    : 180, // Filters/Text height
                // -----------------------
                child: SingleChildScrollView(
                  child: _buildEditorPanel(),
                ),
              ),
              const SizedBox(height: 8),
              BottomBar(
                onTap: _onBottomBarTapped,
                currentMode: _editMode,
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSelectPhotoView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.photo_library, size: 80, color: Colors.grey[600]),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _selectPhoto,
          child: const Text('Select Photo', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }

  // (Helper widget _buildBaseImage removed)

  // --- UPDATED WIDGET ---
  Widget _buildPhotoView() {
    return RepaintBoundary(
      key: _imagePreviewKey,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // --- 1. Base Image with Filters and Blur ---
          // (Chroma stack removed, replaced with single base image)
          ClipRRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: _blur * 5, // This is the "simple blur"
                sigmaY: _blur * 5,
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(_getInterpolatedMatrix()),
                child: Image.file(
                  _image!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // --- END OF BASE IMAGE ---

          // 2. Vignette (Stays on top)
          if (_vignette)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),

          // 3. Overlay (Stays on top)
          if (_selectedOverlayUrl.isNotEmpty && _overlayIntensity > 0.0)
            Positioned.fill(
              child: Opacity(
                opacity: _overlayIntensity,
                child: Image.asset(
                  _selectedOverlayUrl,
                  fit: BoxFit.cover,
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),

          // 4. Text (Stays on top)
          if (_textOnImage.isNotEmpty)
            Positioned.fill(
              child: Center(
                child: Text(
                  _textOnImage,
                  textAlign: TextAlign.center,
                  style: _textStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}