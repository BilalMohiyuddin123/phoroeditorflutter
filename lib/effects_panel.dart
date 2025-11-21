import 'package:flutter/material.dart';

class EffectsPanel extends StatelessWidget {
  final bool vignette;
  final ValueChanged<bool> onVignetteChanged;
  final double vignetteValue;
  final ValueChanged<double> onVignetteValueChanged;

  final Map<String, String> overlayOptions;
  final String selectedOverlayUrl;
  final double overlayIntensity;
  final ValueChanged<String> onOverlayChanged;
  final ValueChanged<double> onOverlayIntensityChanged;

  const EffectsPanel({
    super.key,
    required this.vignette,
    required this.onVignetteChanged,
    required this.vignetteValue,
    required this.onVignetteValueChanged,
    required this.overlayOptions,
    required this.selectedOverlayUrl,
    required this.overlayIntensity,
    required this.onOverlayChanged,
    required this.onOverlayIntensityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final keys = overlayOptions.keys.toList();

    final sliderTheme = SliderTheme.of(context).copyWith(
      activeTrackColor: Colors.blue,
      inactiveTrackColor: Colors.blue.withOpacity(0.3),
      thumbColor: Colors.blue,
      overlayColor: Colors.blue.withOpacity(0.2),
      trackHeight: 3.0,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
    );

    return Container(
      // Adjusted padding: Reduced vertical padding slightly to fit more content
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 5),
      color: Colors.black.withOpacity(0.3),

      // --- THE FIX: Scroll View Wrapper ---
      // This ensures that if the content > 180px, it scrolls instead of overflowing
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), // Makes scrolling feel smooth
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Vignette Row
            Row(
              children: [
                const SizedBox(width: 8),
                const Text(
                  "Vignette",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: vignette,
                    activeColor: Colors.blue,
                    inactiveTrackColor: Colors.grey[800],
                    onChanged: onVignetteChanged,
                  ),
                ),
                if (vignette)
                  Expanded(
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        value: vignetteValue,
                        min: 0.1,
                        max: 1.0,
                        onChanged: onVignetteValueChanged,
                      ),
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),

            // Compact spacer (Changed from 12 to 8 to save space)
            const SizedBox(height: 8),

            // 2. Grains List
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: keys.length,
                separatorBuilder: (ctx, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final name = keys[index];
                  final url = overlayOptions[name]!;
                  final isSelected = (url == selectedOverlayUrl) ||
                      (url.isEmpty && selectedOverlayUrl.isEmpty);

                  return GestureDetector(
                    onTap: () => onOverlayChanged(url),
                    child: _buildTextureItem(name, url, isSelected),
                  );
                },
              ),
            ),

            // Compact spacer (Changed from 12 to 8)
            const SizedBox(height: 8),

            // 3. Grain Intensity
            if (selectedOverlayUrl.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
                    child: Text(
                      "Intensity: ${(overlayIntensity * 100).toStringAsFixed(0)}",
                      style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  SizedBox(
                    height: 30,
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        value: overlayIntensity,
                        min: 0.0,
                        max: 1.0,
                        onChanged: onOverlayIntensityChanged,
                      ),
                    ),
                  ),
                ],
              )
            else
            // A small spacer to ensure scrolling feels right if list is long
              const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextureItem(String name, String url, bool isSelected) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey[800]!,
              width: isSelected ? 2.0 : 1.0,
            ),
            image: url.isNotEmpty
                ? DecorationImage(
              image: AssetImage(url),
              fit: BoxFit.cover,
              opacity: 0.7,
            )
                : null,
          ),
          child: url.isEmpty
              ? const Center(
              child: Icon(Icons.block, color: Colors.white54, size: 20))
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.white,
            fontSize: 10,
          ),
        )
      ],
    );
  }
}