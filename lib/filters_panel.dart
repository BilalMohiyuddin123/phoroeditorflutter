// filters_panel.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

typedef ColorMatrix = List<double>;

class FilterMatrix {
  static const ColorMatrix none = [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static ColorMatrix multiply(ColorMatrix a, ColorMatrix b) {
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

    final sepMat = <double>[
      0.393 + 0.607 * (1 - sep), 0.769 - 0.769 * (1 - sep), 0.189 - 0.189 * (1 - sep), 0, 0,
      0.349 - 0.349 * (1 - sep), 0.686 + 0.314 * (1 - sep), 0.168 - 0.168 * (1 - sep), 0, 0,
      0.272 - 0.272 * (1 - sep), 0.534 - 0.534 * (1 - sep), 0.131 + 0.869 * (1 - sep), 0, 0,
      0, 0, 0, 1, 0,
    ];

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

  static ColorMatrix _contrastMatrix(double contrast, double offset) =>
      <double>[
        contrast, 0, 0, 0, offset,
        0, contrast, 0, 0, offset,
        0, 0, contrast, 0, offset,
        0, 0, 0, 1, 0,
      ];

  static ColorMatrix _combineMatrices(List<ColorMatrix> matrices) {
    ColorMatrix result = List<double>.from(none);
    for (final m in matrices) {
      result = multiply(result, m);
    }
    return result;
  }

  static const presets = {
    'None': {'brightness': 100.0, 'contrast': 100.0, 'saturation': 100.0, 'hue': 0.0, 'sepia': 0.0},
    'Midnight 1': {'brightness': 109.0, 'contrast': 89.0, 'saturation': 110.0, 'hue': 0.0, 'sepia': 15.0},
    'Midnight 2': {'brightness': 105.0, 'contrast': 85.0, 'saturation': 120.0, 'hue': 0.0, 'sepia': 20.0},
    'Warm': {'brightness': 100.0, 'contrast': 100.0, 'saturation': 100.0, 'hue': 0.0, 'sepia': 30.0},
    'B&W': {'brightness': 100.0, 'contrast': 110.0, 'saturation': 0.0, 'hue': 0.0, 'sepia': 0.0},
    'Vintage': {'brightness': 90.0, 'contrast': 110.0, 'saturation': 80.0, 'hue': 0.0, 'sepia': 40.0},
  };
}

class FiltersPanel extends StatelessWidget {
  final Function(ColorMatrix) onFilterSelected;
  final ColorMatrix activeFilter; // <--- 1. Added this parameter
  final double intensity;
  final Function(double) onIntensityChanged;
  final ImageProvider imagePreviewProvider;

  const FiltersPanel({
    super.key,
    required this.onFilterSelected,
    required this.activeFilter, // <--- 2. Require it here
    required this.intensity,
    required this.onIntensityChanged,
    required this.imagePreviewProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.3),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
            const SizedBox(height: 5),
            SizedBox(
              height: 30,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                ),
                child: Slider(
                  value: intensity,
                  min: 0.0,
                  max: 1.5,
                  onChanged: onIntensityChanged,
                  activeColor: Colors.blueAccent,
                  inactiveColor: Colors.grey[800],
                ),
              ),
            ),
            Text(
                "Intensity: ${(intensity * 100).toStringAsFixed(0)}%",
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String name, ColorMatrix matrix) {
    // 3. Compare this button's matrix with the activeFilter
    bool isSelected = _matricesEqual(matrix, activeFilter);

    return InkWell(
      onTap: () => onFilterSelected(matrix),
      child: Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                // 4. Dynamic Border Color and Width
                border: Border.all(
                  color: isSelected ? Colors.blueAccent : Colors.white24,
                  width: isSelected ? 3 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(matrix),
                  child: Image(
                    image: imagePreviewProvider,
                    fit: BoxFit.cover,
                    width: 70,
                    height: 70,
                    errorBuilder: (c, e, s) => Container(color: Colors.grey[800]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                // 5. Highlight text color too if you want
                color: isSelected ? Colors.blueAccent : Colors.white,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to check if two matrices are effectively equal
  bool _matricesEqual(ColorMatrix a, ColorMatrix b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      // Use a small epsilon for float comparison logic
      if ((a[i] - b[i]).abs() > 0.001) return false;
    }
    return true;
  }
}