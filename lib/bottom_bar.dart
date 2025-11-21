// bottom_bar.dart
import 'package:flutter/material.dart';
import 'home_page.dart'; // Ensures it can see the EditMode enum

class BottomBar extends StatelessWidget {
  final Function(EditMode) onTap;
  final EditMode currentMode;

  const BottomBar({
    super.key,
    required this.onTap,
    required this.currentMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70, // Slightly taller for better touch targets
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Better spacing
        children: [
          _buildButton(context,
              icon: Icons.filter_vintage, // Updated Icon
              label: 'Filters',
              mode: EditMode.filters),

          _buildButton(context,
              icon: Icons.tune,
              label: 'Adjust',
              mode: EditMode.adjust),

          _buildButton(context,
              icon: Icons.auto_fix_high, // Updated Icon
              label: 'Effects',
              mode: EditMode.effects),

          // --- THE TEXT BUTTON ---
          _buildButton(context,
              icon: Icons.text_fields,
              label: 'Text',
              mode: EditMode.text),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context,
      {required IconData icon,
        required String label,
        required EditMode mode}) {

    final bool isSelected = currentMode == mode;
    final Color color = isSelected ? Colors.blueAccent : Colors.white;

    return GestureDetector(
      onTap: () => onTap(mode),
      behavior: HitTestBehavior.opaque, // Ensures the whole area is clickable
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
                label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                )
            ),
          ],
        ),
      ),
    );
  }
}