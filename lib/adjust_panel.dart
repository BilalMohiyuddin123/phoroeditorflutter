// adjust_panel.dart
import 'package:flutter/material.dart';

class AdjustPanel extends StatelessWidget {
  // Blur
  final double blur;
  final Function(double) onBlurChanged;

  // Adjustments
  final double brightness;
  final Function(double) onBrightnessChanged;
  final double contrast;
  final Function(double) onContrastChanged;
  final double sepia; // Tint
  final Function(double) onSepiaChanged;

  const AdjustPanel({
    super.key,
    required this.blur,
    required this.onBlurChanged,
    required this.brightness,
    required this.onBrightnessChanged,
    required this.contrast,
    required this.onContrastChanged,
    required this.sepia,
    required this.onSepiaChanged,
  });

  @override
  // --- THIS IS THE FIX ---
  Widget build(BuildContext context) {
    // It was 'BuildContextContext', it is now 'BuildContext'
    // -------------------------
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.black.withOpacity(0.3),
      // Use SingleChildScrollView to prevent overflow on smaller screens
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Blur Slider ---
            _buildSlider(
              label: 'Blur',
              value: blur,
              onChanged: onBlurChanged,
              min: 0.0,
              max: 1.0,
              divisions: 10,
            ),
            // --- Brightness Slider ---
            _buildSlider(
              label: 'Brightness',
              value: brightness,
              onChanged: onBrightnessChanged,
              min: 0.0,
              max: 200.0, // 0% to 200%
              divisions: 20,
              displayValue: (brightness).toStringAsFixed(0),
            ),
            // --- Contrast Slider ---
            _buildSlider(
              label: 'Contrast',
              value: contrast,
              onChanged: onContrastChanged,
              min: 0.0,
              max: 200.0, // 0% to 200%
              divisions: 20,
              displayValue: (contrast).toStringAsFixed(0),
            ),
            // --- Sepia (Tint) Slider ---
            _buildSlider(
              label: 'Tint', // As requested
              value: sepia,
              onChanged: onSepiaChanged,
              min: 0.0,
              max: 100.0, // 0% to 100%
              divisions: 20,
              displayValue: (sepia).toStringAsFixed(0),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget to build a labeled slider
  Widget _buildSlider({
    required String label,
    required double value,
    required Function(double) onChanged,
    required double min,
    required double max,
    required int divisions,
    String? displayValue,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 70, // Increased width for longer labels
          child: Text(
            label,
            style: const TextStyle(color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: displayValue ?? (value * 100).toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}