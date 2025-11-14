//bottom_bar.dart
import 'package:flutter/material.dart';
import 'home_page.dart'; // For EditMode enum

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
      height: 60,
      color: Colors.grey[850],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildButton(context,
              icon: Icons.filter,
              label: 'Filters',
              mode: EditMode.filters),
          _buildButton(context,
              icon: Icons.flare,
              label: 'Effects',
              mode: EditMode.effects),
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
    bool isSelected = currentMode == mode;
    Color color = isSelected ? Colors.blue : Colors.white;

    return InkWell(
      onTap: () => onTap(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}