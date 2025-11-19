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
    // REMOVED: The code that split text with newlines.
    // We now render the text normally, but rotate the widget below.

    return Positioned(
      left: layer.position.dx,
      top: layer.position.dy,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (details) => onDrag(details.delta),
        // UPDATED: RotatedBox handles the rotation now
        child: RotatedBox(
          // 3 quarter turns = 270 degrees (Text reads bottom-to-top, standard for side labels)
          // Change to 1 if you want it reading top-to-bottom.
          quarterTurns: layer.isVertical ? 3 : 0,
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
                  layer.text, // Just use the raw text
                  textAlign: TextAlign.center,
                  style: GoogleFonts.getFont(
                    layer.fontFamily,
                    fontSize: layer.fontSize,
                    color: layer.color,
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
      ),
    );
  }
}