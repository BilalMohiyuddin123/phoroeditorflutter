import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'permissions_handler.dart'; // Your existing AppUtils

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

  // We need to track how wide the image looks on screen
  // to calculate the ratio for the final save.
  double _lastRenderedWidth = 1.0;

  @override
  void initState() {
    super.initState();
    _loadUiImage(widget.imageData);
  }

  Future<void> _loadUiImage(Uint8List data) async {
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    setState(() {
      _decodedImage = frame.image;
    });
  }

  /// Save the current glitch canvas as image
  Future<void> _saveImage() async {
    if (_decodedImage == null) return;
    setState(() => _isSaving = true);

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // The full resolution size
      final size = Size(_decodedImage!.width.toDouble(), _decodedImage!.height.toDouble());

      // --- KEY FIX IS HERE ---
      // Calculate the ratio between the Real Image and the Preview Image.
      // If Real is 3000px and Preview is 300px, ratio is 10.
      // We must multiply intensity by 10 so the glitch looks the same.
      double scaleFactor = _decodedImage!.width / _lastRenderedWidth;

      // Ensure we don't divide by zero or get weird values
      if (scaleFactor.isNaN || scaleFactor.isInfinite || scaleFactor == 0) {
        scaleFactor = 1.0;
      }

      final double savedIntensity = _glitchIntensity * scaleFactor;
      // -----------------------

      GlitchPainter(
          image: _decodedImage!,
          intensity: _glitchEnabled ? savedIntensity : 0
      ).paint(canvas, size);

      final picture = recorder.endRecording();
      final img = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final bytes = byteData.buffer.asUint8List();
        bool success = await AppUtils.saveImageToGallery(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(success ? 'Image saved!' : 'Failed to save image')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _editMore() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Glitch Preview')),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _decodedImage == null
                  ? const CircularProgressIndicator()
                  : LayoutBuilder(
                builder: (context, constraints) {
                  final scaleX = constraints.maxWidth / _decodedImage!.width;
                  final scaleY = constraints.maxHeight / _decodedImage!.height;
                  final scale = scaleX < scaleY ? scaleX : scaleY;

                  final displayWidth = _decodedImage!.width * scale;
                  final displayHeight = _decodedImage!.height * scale;

                  // STORE THE PREVIEW WIDTH for calculation in _saveImage
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
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _glitchEnabled,
                  onChanged: (val) => setState(() => _glitchEnabled = val),
                ),
                Row(
                  children: [
                    const Text('Intensity:', style: TextStyle(color: Colors.white70)),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 10, // Allowed larger max for more dramatic effect
                        divisions: 20,
                        value: _glitchIntensity,
                        onChanged: _glitchEnabled
                            ? (val) => setState(() => _glitchIntensity = val)
                            : null,
                      ),
                    ),
                    Text(_glitchIntensity.round().toString(),
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, spreadRadius: 2),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _editMore,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit More'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveImage,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.download),
                    label: Text(_isSaving ? 'Saving...' : 'Save Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
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
      ..filterQuality = FilterQuality.high // Keeps preview smooth
      ..isAntiAlias = true;

    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

    // Destination rectangle scaled to preview or full size
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
        image,
        srcRect,
        dstRect.shift(Offset(intensity, 0)),
        paint);

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
        image,
        srcRect,
        dstRect.shift(Offset(-intensity, 0)),
        paint);
  }

  @override
  bool shouldRepaint(covariant GlitchPainter oldDelegate) =>
      oldDelegate.intensity != intensity || oldDelegate.image != image;
}