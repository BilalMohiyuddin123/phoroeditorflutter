// effects_panel.dart
import 'package:flutter/material.dart';

class EffectsPanel extends StatelessWidget {
  // Existing properties
  final double blur;
  final bool vignette;
  final Function(double) onBlurChanged;
  final Function(bool) onVignetteChanged;

  // NEW PROPERTIES
  final Map<String, String> overlayOptions;
  final String selectedOverlayUrl;
  final double overlayIntensity;
  final Function(String) onOverlayChanged;
  final Function(double) onOverlayIntensityChanged;

  const EffectsPanel({
    super.key,
    // Existing
    required this.blur,
    required this.vignette,
    required this.onBlurChanged,
    required this.onVignetteChanged,
    // NEW
    required this.overlayOptions,
    required this.selectedOverlayUrl,
    required this.overlayIntensity,
    required this.onOverlayChanged,
    required this.onOverlayIntensityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.black.withOpacity(0.3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Blur Slider ---
          Row(
            children: [
              // --- FIX IS HERE ---
              const SizedBox(
                width: 60,
                child: Text('Blur', style: TextStyle(color: Colors.white)),
              ),
              Expanded(
                child: Slider(
                  value: blur,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: (blur * 100).toStringAsFixed(0),
                  onChanged: onBlurChanged,
                ),
              ),
            ],
          ),
          // --- Vignette Switch ---
          SwitchListTile(
            title: const Text('Vignette', style: TextStyle(color: Colors.white)),
            value: vignette,
            onChanged: onVignetteChanged,
            activeColor: Colors.blue,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          const Divider(color: Colors.white30),

          // --- NEW: Overlay Selection ---
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Text('Overlays', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: overlayOptions.entries.map((entry) {
                final String name = entry.key;
                final String url = entry.value;
                final bool isSelected = selectedOverlayUrl == url;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(name),
                    selected: isSelected,
                    onSelected: (selected) {
                      onOverlayChanged(selected ? url : '');
                    },
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // --- NEW: Overlay Intensity Slider ---
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: selectedOverlayUrl.isNotEmpty ? 1.0 : 0.0,
            child: Visibility(
              visible: selectedOverlayUrl.isNotEmpty,
              child: Row(
                children: [
                  // --- FIX IS HERE ---
                  const SizedBox(
                    width: 60,
                    child: Text('Intensity', style: TextStyle(color: Colors.white)),
                  ),
                  Expanded(
                    child: Slider(
                      value: overlayIntensity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      label: (overlayIntensity * 100).toStringAsFixed(0),
                      onChanged: onOverlayIntensityChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}