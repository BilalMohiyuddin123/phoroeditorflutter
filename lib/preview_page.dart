// preview_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'permissions_handler.dart'; // We need this for AppUtils.saveImageToGallery

class PreviewPage extends StatefulWidget {
  final Uint8List imageData;

  const PreviewPage({super.key, required this.imageData});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  bool _isSaving = false;

  /// Goes back to the editing page
  void _editMore() {
    Navigator.pop(context);
  }

  /// Saves the image data to the gallery
  Future<void> _saveToGallery() async {
    setState(() {
      _isSaving = true;
    });

    try {
      bool success = await AppUtils.saveImageToGallery(widget.imageData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                success ? 'Image saved to gallery!' : 'Failed to save image.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview & Save'),
        automaticallyImplyLeading: false, // Remove default back arrow
      ),
      body: Column(
        children: [
          // Expanded image preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Image.memory(
                widget.imageData,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Bottom button bar
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[900], // Dark background for the bar
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // "Edit More" button
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

                // "Save Image" button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveToGallery,
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