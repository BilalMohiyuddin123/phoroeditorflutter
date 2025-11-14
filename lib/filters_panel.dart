// filters_panel.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

typedef ColorMatrix = List<double>;

class FilterMatrix {
  /// === Identity (no effect) ===
  static const ColorMatrix none = [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// Helper: linear interpolation
  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// === Build a matrix from CSS-like parameters ===
  static ColorMatrix buildMatrix({
    double brightness = 100,
    double contrast = 100,
    double saturation = 100,
    double hue = 0,
    double sepia = 0,
  }) {
    final b = brightness / 100;
    final c = contrast / 100;
    final s = saturation / 100;
    final h = hue * math.pi / 180;
    final sep = sepia / 100;

    // Hue rotation
    final cosH = math.cos(h);
    final sinH = math.sin(h);
    const lumR = 0.213;
    const lumG = 0.715;
    const lumB = 0.072;

    final hueMat = <double>[
      lumR + cosH * (1 - lumR) + sinH * (-lumR),
      lumG + cosH * (-lumG) + sinH * (-lumG),
      lumB + cosH * (-lumB) + sinH * (1 - lumB),
      0,
      0,
      lumR + cosH * (-lumR) + sinH * 0.143,
      lumG + cosH * (1 - lumG) + sinH * 0.14,
      lumB + cosH * (-lumB) + sinH * (-0.283),
      0,
      0,
      lumR + cosH * (-lumR) + sinH * (-(1 - lumR)),
      lumG + cosH * (-lumG) + sinH * lumG,
      lumB + cosH * (1 - lumB) + sinH * lumB,
      0,
      0,
      0, 0, 0, 1, 0,
    ];

    // Sepia
    final sepMat = <double>[
      0.393 + 0.607 * (1 - sep), 0.769 - 0.769 * (1 - sep), 0.189 - 0.189 * (1 - sep), 0, 0,
      0.349 - 0.349 * (1 - sep), 0.686 + 0.314 * (1 - sep), 0.168 - 0.168 * (1 - sep), 0, 0,
      0.272 - 0.272 * (1 - sep), 0.534 - 0.534 * (1 - sep), 0.131 + 0.869 * (1 - sep), 0, 0,
      0, 0, 0, 1, 0,
    ];

    // Saturation
    const satLumR = 0.3086;
    const satLumG = 0.6094;
    const satLumB = 0.0820;

    final satMat = <double>[
      (1 - s) * satLumR + s, (1 - s) * satLumG, (1 - s) * satLumB, 0, 0,
      (1 - s) * satLumR, (1 - s) * satLumG + s, (1 - s) * satLumB, 0, 0,
      (1 - s) * satLumR, (1 - s) * satLumG, (1 - s) * satLumB + s, 0, 0,
      0, 0, 0, 1, 0,
    ];

    final contrastOffset = 0.5 * (1 - c);

    final baseMat = _combineMatrices([
      _brightnessMatrix(b),
      _contrastMatrix(c, contrastOffset),
      satMat,
      hueMat,
      sepMat,
    ]);

    return baseMat;
  }

  static ColorMatrix _brightnessMatrix(double brightness) => <double>[
    brightness, 0, 0, 0, 0,
    0, brightness, 0, 0, 0,
    0, 0, brightness, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static ColorMatrix _contrastMatrix(double contrast, double offset) => <double>[
    contrast, 0, 0, 0, offset,
    0, contrast, 0, 0, offset,
    0, 0, contrast, 0, offset,
    0, 0, 0, 1, 0,
  ];

  static ColorMatrix _combineMatrices(List<ColorMatrix> matrices) {
    ColorMatrix result = List<double>.from(none);
    for (final m in matrices) {
      result = _multiply(result, m);
    }
    return result;
  }

  static ColorMatrix _multiply(ColorMatrix a, ColorMatrix b) {
    final out = List<double>.filled(20, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 5; col++) {
        out[row * 5 + col] = a[row * 5 + 0] * b[col + 0] +
            a[row * 5 + 1] * b[col + 5] +
            a[row * 5 + 2] * b[col + 10] +
            a[row * 5 + 3] * b[col + 15] +
            (col == 4 ? a[row * 5 + 4] : 0);
      }
    }
    out[19] = 1;
    return out;
  }

  /// === Filter Presets ===
  static const presets = {
    'None': {
      'brightness': 100.0,
      'contrast': 100.0,
      'saturation': 100.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Midnight 1': {
      'brightness': 109.0,
      'contrast': 89.0,
      'saturation': 110.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 15.0,
    },
    'Midnight 2': {
      'brightness': 105.0,
      'contrast': 85.0,
      'saturation': 120.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 20.0,
    },
    'Midnight 3': {
      'brightness': 100.0,
      'contrast': 105.0,
      'saturation': 95.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 5.0,
    },
    'Sepia': {
      'brightness': 100.0,
      'contrast': 95.0,
      'saturation': 90.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 70.0,
    },
    'Greyscale': {
      'brightness': 100.0,
      'contrast': 100.0,
      'saturation': 0.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Vibrant': {
      'brightness': 102.0,
      'contrast': 110.0,
      'saturation': 130.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Retro 1': {
      'brightness': 105.0,
      'contrast': 90.0,
      'saturation': 80.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 25.0,
    },
    'Retro 2': {
      'brightness': 110.0,
      'contrast': 85.0,
      'saturation': 70.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 35.0,
    },
    'Golden Hour': {
      'brightness': 110.0,
      'contrast': 105.0,
      'saturation': 115.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 22.0,
    },
    'Lo-Fi': {
      'brightness': 100.0,
      'contrast': 95.0,
      'saturation': 75.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 15.0,
    },
    'Dreamy': {
      'brightness': 115.0,
      'contrast': 85.0,
      'saturation': 110.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 10.0,
    },
    'Daylight': {
      'brightness': 105.0,
      'contrast': 105.0,
      'saturation': 110.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Nightlight': {
      'brightness': 90.0,
      'contrast': 115.0,
      'saturation': 110.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Sunset': {
      'brightness': 100.0,
      'contrast': 108.0,
      'saturation': 125.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 30.0,
    },
    'Nostalgia': {
      'brightness': 105.0,
      'contrast': 92.0,
      'saturation': 85.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 18.0,
    },
    'Teal & Orange': {
      'brightness': 100.0,
      'contrast': 110.0,
      'saturation': 130.0,
      'hue': -10.0,
      'temp': 0.0,
      'sepia': 5.0,
    },
    'Noir': {
      'brightness': 100.0,
      'contrast': 130.0,
      'saturation': 0.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Faded B&W': {
      'brightness': 105.0,
      'contrast': 80.0,
      'saturation': 0.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 10.0,
    },
    'Warm B&W': {
      'brightness': 100.0,
      'contrast': 110.0,
      'saturation': 0.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 30.0,
    },
    'Clarity': {
      'brightness': 102.0,
      'contrast': 120.0,
      'saturation': 105.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Cinematic': {
      'brightness': 98.0,
      'contrast': 115.0,
      'saturation': 110.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 10.0,
    },
    'Kodachrome': {
      'brightness': 100.0,
      'contrast': 105.0,
      'saturation': 140.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 12.0,
    },
    'Vintage': {
      'brightness': 108.0,
      'contrast': 90.0,
      'saturation': 85.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 40.0,
    },
    'Sunrise': {
      'brightness': 112.0,
      'contrast': 95.0,
      'saturation': 115.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 15.0,
    },
    'Cool': {
      'brightness': 105.0,
      'contrast': 102.0,
      'saturation': 90.0,
      'hue': 15.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Warm': {
      'brightness': 105.0,
      'contrast': 102.0,
      'saturation': 110.0,
      'hue': -5.0,
      'temp': 0.0,
      'sepia': 8.0,
    },
    'Cooler': {
      'brightness': 105.0,
      'contrast': 102.0,
      'saturation': 85.0,
      'hue': 20.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Ice Cold': {
      'brightness': 100.0,
      'contrast': 115.0,
      'saturation': 80.0,
      'hue': 25.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Warmer': {
      'brightness': 105.0,
      'contrast': 102.0,
      'saturation': 110.0,
      'hue': -8.0,
      'temp': 0.0,
      'sepia': 12.0,
    },
    'Toasty': {
      'brightness': 108.0,
      'contrast': 100.0,
      'saturation': 115.0,
      'hue': -3.0,
      'temp': 0.0,
      'sepia': 28.0,
    },
    'Muted Cool': {
      'brightness': 105.0,
      'contrast': 90.0,
      'saturation': 80.0,
      'hue': 10.0,
      'temp': 0.0,
      'sepia': 5.0,
    },
    'Muted Warm': {
      'brightness': 105.0,
      'contrast': 90.0,
      'saturation': 85.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 20.0,
    },
    'Forest': {
      'brightness': 100.0,
      'contrast': 105.0,
      'saturation': 110.0,
      'hue': 40.0,
      'temp': 0.0,
      'sepia': 5.0,
    },
    'Rose': {
      'brightness': 102.0,
      'contrast': 100.0,
      'saturation': 115.0,
      'hue': -15.0,
      'temp': 0.0,
      'sepia': 10.0,
    },
    'Deep Blue': {
      'brightness': 100.0,
      'contrast': 105.0,
      'saturation': 120.0,
      'hue': -100.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Indigo': {
      'brightness': 95.0,
      'contrast': 110.0,
      'saturation': 110.0,
      'hue': -85.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Violet': {
      'brightness': 102.0,
      'contrast': 100.0,
      'saturation': 125.0,
      'hue': -50.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Lavender': {
      'brightness': 108.0,
      'contrast': 95.0,
      'saturation': 90.0,
      'hue': -35.0,
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Alley Glow': { // For the cool, cyan night-time look
      'brightness': 102.0,
      'contrast': 90.0,
      'saturation': 95.0,
      'hue': 30.0, // This adds the strong cyan/green tint
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Retro Cam': { // For the warm, faded, VHS look
      'brightness': 110.0, // Lifts brightness for a faded feel
      'contrast': 85.0,   // Very low contrast
      'saturation': 80.0, // Muted colors
      'hue': -10.0,     // Shifts colors slightly to red
      'temp': 0.0,
      'sepia': 45.0,      // Strong warm sepia tint
    },
    'Faded Daylight': { // Bright, washed-out, and warm
      'brightness': 110.0,
      'contrast': 90.0,
      'saturation': 85.0,
      'hue': 0.0,
      'temp': 0.0,
      'sepia': 25.0,
    },
    'Vintage Summer': { // Very warm, punchy colors
      'brightness': 105.0,
      'contrast': 105.0,
      'saturation': 120.0,
      'hue': -8.0, // Shift to red
      'temp': 0.0,
      'sepia': 30.0,
    },
    '80s Cool': { // A brighter, cooler film look
      'brightness': 105.0,
      'contrast': 110.0,
      'saturation': 90.0,
      'hue': 15.0, // Cool shift
      'temp': 0.0,
      'sepia': 0.0,
    },
    'Neon Noir': { // For city lights, adds a purple/magenta tint
      'brightness': 95.0,
      'contrast': 120.0,
      'saturation': 110.0,
      'hue': -45.0, // Magenta/purple shift
      'temp': 0.0,
      'sepia': 0.0,
    },
    'CineNight': { // Cinematic cool shadows and warm highlights
      'brightness': 98.0,
      'contrast': 115.0,
      'saturation': 90.0,
      'hue': 20.0, // Cool blue/teal
      'temp': 0.0,
      'sepia': 10.0, // Warm highlights
    },
    'Expired Film': { // Very desaturated with a strong green tint
      'brightness': 100.0,
      'contrast': 95.0,
      'saturation': 75.0,
      'hue': 40.0, // Strong green/cyan cast
      'temp': 0.0,
      'sepia': 15.0,
    },
  };
}

class FiltersPanel extends StatelessWidget {
  final Function(ColorMatrix) onFilterSelected;
  final double intensity;
  final Function(double) onIntensityChanged;

  // === 1. ADDED THIS LINE ===
  final ImageProvider imagePreviewProvider;

  const FiltersPanel({
    super.key,
    required this.onFilterSelected,
    required this.intensity,
    required this.onIntensityChanged,

    // === 2. ADDED THIS LINE ===
    required this.imagePreviewProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.black.withOpacity(0.3),
      child: Column(
        children: [
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: FilterMatrix.presets.keys.map((name) {
                final preset = FilterMatrix.presets[name]!;
                final matrix = FilterMatrix.buildMatrix(
                  brightness: preset['brightness']!,
                  contrast: preset['contrast']!,
                  saturation: preset['saturation']!,
                  hue: preset['hue']!,
                  sepia: preset['sepia']!,
                );
                return _buildFilterButton(name, matrix);
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Intensity: ${(intensity * 100).toStringAsFixed(0)}%",
            style: const TextStyle(color: Colors.white),
          ),
          Slider(
            value: intensity,
            min: 0.0,
            max: 1.5,
            divisions: 15,
            label: "${(intensity * 100).toStringAsFixed(0)}%",
            onChanged: onIntensityChanged,
            activeColor: Colors.blue,
            inactiveColor: Colors.grey,
          ),
        ],
      ),
    );
  }

  // === 3. UPDATED THIS ENTIRE METHOD ===
  Widget _buildFilterButton(String name, ColorMatrix matrix) {
    return InkWell(
      onTap: () => onFilterSelected(matrix),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(matrix),
                  // Replaced Image.network with this:
                  child: Image(
                    image: imagePreviewProvider, // Use the new provider
                    fit: BoxFit.cover,
                    width: 50,
                    height: 50,
                    // Keep an error builder just in case
                    errorBuilder: (c, e, s) =>
                        Container(color: Colors.grey[400]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(name, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}