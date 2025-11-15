// effects_panel.dart
import 'package:flutter/material.dart';

class EffectsPanel extends StatelessWidget {
  // Vignette
  final bool vignette;
  final Function(bool) onVignetteChanged;

  // Grain/Overlay
  final Map<String, String> overlayOptions;
  final String selectedOverlayUrl;
  final double overlayIntensity;
  final Function(String) onOverlayChanged;
  final Function(double) onOverlayIntensityChanged;

  // (Chroma properties removed)

  const EffectsPanel({
    super.key,
    required this.vignette,
    required this.onVignetteChanged,
    required this.overlayOptions,
    required this.selectedOverlayUrl,
    required this.overlayIntensity,
    required this.onOverlayChanged,
    required this.onOverlayIntensityChanged,
    // (Chroma params removed from constructor)
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.black.withOpacity(0.3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Vignette Switch ---
          SwitchListTile(
            title:
            const Text('Vignette', style: TextStyle(color: Colors.white)),
            value: vignette,
            onChanged: onVignetteChanged,
            activeColor: Colors.blue,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          ),

          const Divider(color: Colors.white30),

          // --- Grain/Overlay Selection ---
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              child: Text('Grain',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
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

          // --- Grain/Overlay Intensity Slider ---
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: selectedOverlayUrl.isNotEmpty ? 1.0 : 0.0,
            child: Visibility(
              visible: selectedOverlayUrl.isNotEmpty,
              child: _buildSlider(
                label: 'Intensity',
                value: overlayIntensity,
                onChanged: onOverlayIntensityChanged,
                min: 0.0,
                max: 1.0,
                divisions: 20,
              ),
            ),
          ),

          // (Divider and Chroma slider removed)
        ],
      ),
    );
  }

  // --- Helper widget to build a labeled slider ---
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
          width: 70,
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