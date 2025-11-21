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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 15.0),
      color: Colors.black.withOpacity(0.3),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Blur Slider ---
            // --- Blur Slider ---
            _buildSlider(
              context: context,
              label: 'Blur',
              value: blur * 100,          // Show 0–100
              onChanged: (v) => onBlurChanged(v / 100), // Convert UI value to 0–1
              min: 0.0,
              max: 100.0,
            ),

            const SizedBox(height: 10),

            // --- Brightness Slider ---
            _buildSlider(
              context: context,
              label: 'Brightness',
              value: brightness,
              onChanged: onBrightnessChanged,
              min: 0.0,
              max: 200.0,
            ),
            const SizedBox(height: 10),

            // --- Contrast Slider ---
            _buildSlider(
              context: context,
              label: 'Contrast',
              value: contrast,
              onChanged: onContrastChanged,
              min: 0.0,
              max: 200.0,
            ),
            const SizedBox(height: 10),

            // --- Tint (Sepia) Slider ---
            _buildSlider(
              context: context,
              label: 'Tint',
              value: sepia,
              onChanged: onSepiaChanged,
              min: 0.0,
              max: 100.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required BuildContext context,
    required String label,
    required double value,
    required Function(double) onChanged,
    required double min,
    required double max,
  }) {
    return Row(
      children: [
        // Label
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Slider
        Expanded(
          child: SizedBox(
            height: 30,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.0,
                activeTrackColor: Colors.blueAccent,
                inactiveTrackColor: Colors.blueAccent.withOpacity(0.3),
                thumbColor: Colors.blueAccent,
                overlayColor: Colors.white.withOpacity(0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        // Number Value
        SizedBox(
          width: 35,
          child: Text(
            value.toStringAsFixed(0),
            textAlign: TextAlign.end,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}