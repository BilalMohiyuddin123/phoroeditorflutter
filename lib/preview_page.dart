import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'permissions_handler.dart'; // Your existing AppUtils.saveImageToGallery

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
      // Render the glitch to an ui.Image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(_decodedImage!.width.toDouble(), _decodedImage!.height.toDouble());
      GlitchPainter(image: _decodedImage!, intensity: _glitchEnabled ? _glitchIntensity : 0)
          .paint(canvas, size);

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

                  return SizedBox(
                    width: displayWidth,
                    height: displayHeight,
                    child: CustomPaint(
                      painter: GlitchPainter(
                        image: _decodedImage!,
                        intensity: _glitchEnabled ? _glitchIntensity : 0,
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
                        max: 100,
                        divisions: 100,
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

  GlitchPainter({required this.image, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..blendMode = BlendMode.plus;

    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (intensity == 0) {
      canvas.drawImageRect(image, srcRect, dstRect, Paint());
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
