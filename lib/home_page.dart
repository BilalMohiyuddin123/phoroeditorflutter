// home_page.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart'; // Required for DateFormat

import 'bottom_bar.dart';
import 'effects_panel.dart';
import 'filters_panel.dart';
import 'permissions_handler.dart';
import 'text_panel.dart'; // Imports SmartTextPanel & TextLayer
import 'photo_editor_screen.dart'; // Imports DraggableTextWidget
import 'preview_page.dart';
import 'adjust_panel.dart';

// Ensure this Enum matches exactly what is used in BottomBar
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

  // --- TEXT ENGINE STATE ---
  List<TextLayer> textLayers = [];
  String? selectedLayerId;

  TextLayer? get activeLayer {
    try {
      return textLayers.firstWhere((e) => e.id == selectedLayerId);
    } catch (e) {
      return null;
    }
  }
  // ----------------------------

  // --- Adjustment state ---
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
          content: Text('Permission denied. Please grant permission to select photos.'),
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
    // 1. Check if layer exists
    final existingIndex = textLayers.indexWhere((layer) => layer.isDateElement == isDate);

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
        text: isDate ? DateFormat('dd/MM/yy').format(DateTime.now()) : "Double Tap",
        fontFamily: isDate ? 'Orbitron' : 'Roboto',

        // FIXED: Changed from 500 to 100 to ensure it is visible on screen.
        // You can drag it to the bottom corner manually.
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

  // Added 'isVertical' parameter
  void _updateLayer({Color? color, double? size, String? text, String? font, bool? isVertical}) {
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
  // ---------------------------

  Future<void> _goToPreview() async {
    // Deselect text so borders don't appear in the screenshot
    setState(() {
      for (var layer in textLayers) layer.isSelected = false;
      selectedLayerId = null;
    });

    await Future.delayed(const Duration(milliseconds: 50));

    setState(() {
      _isLoading = true;
    });
    try {
      RenderRepaintBoundary boundary = _imagePreviewKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // High Pixel Ratio for HD Quality
      // We keep this at 3.0 for high quality. The glitch fix is handled in _buildPhotoView.
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
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
          SnackBar(content: Text('An error occurred generating preview: $e')),
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
      // If we leave text mode, deselect text
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
          // PASS THE CURRENT FILTER HERE
          activeFilter: _currentFilter,

          onFilterSelected: (matrix) => setState(() {
            _currentFilter = matrix;
            _currentFilterIntensity = 1.0;
          }),
          intensity: _currentFilterIntensity,
          onIntensityChanged: (val) => setState(() => _currentFilterIntensity = val),
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
              if (url.isNotEmpty && _overlayIntensity == 0.0) _overlayIntensity = 0.5;
            });
          },
          onOverlayIntensityChanged: (v) => setState(() => _overlayIntensity = v),
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
          // THIS IS THE NEW BACK BUTTON ACTION
          onClose: () {
            setState(() {
              selectedLayerId = null; // Deselect to go back to Add Menu
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
    // Panel Height Logic
    double panelHeight = 0;
    if (_editMode == EditMode.effects || _editMode == EditMode.adjust) panelHeight = 220;
    else if (_editMode == EditMode.filters) panelHeight = 180;
    else if (_editMode == EditMode.text) panelHeight = 280;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Photo Editor', style: TextStyle(color: Colors.white)),
        actions: [
          if (_image != null && !_isLoading)
            TextButton(
              onPressed: _goToPreview,
              child: const Text('Preview', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
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
          children: [
            Expanded(
              child: Center(
                child: _image == null ? _buildSelectPhotoView() : _buildPhotoView(),
              ),
            ),
            if (_image != null) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: panelHeight,
                // NOTE: SmartTextPanel handles its own internal scrolling/layout
                child: _buildEditorPanel(),
              ),
              const SizedBox(height: 8),
              BottomBar(onTap: _onBottomBarTapped, currentMode: _editMode),
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
        Icon(Icons.add_photo_alternate, size: 80, color: Colors.grey[800]),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          onPressed: _selectPhoto,
          child: const Text('Select Photo', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildPhotoView() {
    return GestureDetector(
      // Tap Background to Deselect Text
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
                imageFilter: ui.ImageFilter.blur(sigmaX: _blur * 5, sigmaY: _blur * 5),
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
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
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
                    // *** KEY FIX: This ensures the glitch texture stays sharp (crunchy)
                    // even when exported at high resolution.
                    filterQuality: FilterQuality.none,
                  ),
                ),
              ),

            // Render Text Layers
            ...textLayers.map((layer) {
              return DraggableTextWidget(
                layer: layer,
                onTap: () {
                  // Automatically switch to text mode if tapping a text item
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