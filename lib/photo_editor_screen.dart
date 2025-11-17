import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'text_panel.dart';

class DraggableTextWidget extends StatelessWidget {
  final TextLayer layer;
  final VoidCallback onTap;
  final Function(Offset) onDrag;
  final VoidCallback onDelete;

  const DraggableTextWidget({
    super.key,
    required this.layer,
    required this.onTap,
    required this.onDrag,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Logic for Vertical Text: Add newlines between every character
    String displayText = layer.text;
    if (layer.isVertical) {
      displayText = layer.text.split('').join('\n');
    }

    return Positioned(
      left: layer.position.dx,
      top: layer.position.dy,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (details) => onDrag(details.delta),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: layer.isSelected
                    ? Border.all(color: Colors.blueAccent, width: 1.5)
                    : Border.all(color: Colors.transparent),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                displayText,
                textAlign: TextAlign.center,
                style: GoogleFonts.getFont(
                  layer.fontFamily,
                  fontSize: layer.fontSize,
                  color: layer.color,
                  height: 1.0, // Tighter line height for vertical text
                  shadows: [
                    const Shadow(blurRadius: 5, color: Colors.black54, offset: Offset(2, 2))
                  ],
                ),
              ),
            ),

            if (layer.isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}