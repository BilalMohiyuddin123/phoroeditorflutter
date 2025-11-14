//save_button.dart
import 'package:flutter/material.dart';

class SaveImageButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SaveImageButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          children: [
            Icon(Icons.save_alt, size: 20),
            SizedBox(width: 8),
            Text('Save'),
          ],
        ),
      ),
    );
  }
}