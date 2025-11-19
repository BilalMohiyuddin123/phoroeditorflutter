import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------
// 1. DATA MODEL
// ---------------------------------------------------------
class TextLayer {
  String id;
  String text;
  Offset position;
  double fontSize;
  Color color;
  String fontFamily;
  bool isDateElement;
  bool isVertical;
  bool isSelected;

  TextLayer({
    required this.id,
    required this.text,
    this.position = const Offset(100, 200),
    this.fontSize = 32.0,
    this.color = Colors.white,
    this.fontFamily = 'Roboto',
    this.isDateElement = false,
    this.isVertical = false,
    this.isSelected = true,
  });
}

// ---------------------------------------------------------
// 2. SMART CONTROL PANEL UI
// ---------------------------------------------------------
class SmartTextPanel extends StatefulWidget {
  final TextLayer? selectedLayer;
  final VoidCallback onAddNewText;
  final VoidCallback onAddNewDate;
  final Function(Color) onColorChanged;
  final Function(double) onSizeChanged;
  final Function(String) onTextChanged;
  final Function(String) onFontChanged;
  final Function(bool) onVerticalChanged;
  final VoidCallback onClose; // NEW: Back button callback

  const SmartTextPanel({
    super.key,
    this.selectedLayer,
    required this.onAddNewText,
    required this.onAddNewDate,
    required this.onColorChanged,
    required this.onSizeChanged,
    required this.onTextChanged,
    required this.onFontChanged,
    required this.onVerticalChanged,
    required this.onClose, // Required
  });

  @override
  State<SmartTextPanel> createState() => _SmartTextPanelState();
}

class _SmartTextPanelState extends State<SmartTextPanel> {
  final TextEditingController _textEditingController = TextEditingController();

  // Standard Fonts
  final List<String> _textFonts = [
    "Roboto","Caveat","Shadows Into Light","Oswald", "Montserrat","Pacifico","Lobster", "Bebas Neue",
    "Dancing Script", "Abril Fatface"
  ];

  // Date Specific Fonts
  final List<String> _dateFonts = [
    "Orbitron",
  ];

  @override
  void didUpdateWidget(SmartTextPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLayer != null &&
        (oldWidget.selectedLayer?.id != widget.selectedLayer?.id)) {
      _textEditingController.text = widget.selectedLayer!.text;
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.selectedLayer != null;

    return Container(
      height: isEditing ? 420 : 150,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: const Color(0xFF1E1E1E),
      child: isEditing ? _buildEditMode() : _buildAddMode(),
    );
  }

  // --- VIEW 1: ADD NEW ---
  Widget _buildAddMode() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Add Layer", style: TextStyle(color: Colors.white54, letterSpacing: 1.2)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBigButton(Icons.text_fields, "Add Text", Colors.blueAccent, widget.onAddNewText),
            _buildBigButton(Icons.calendar_today, "Add Date", Colors.orangeAccent, widget.onAddNewDate),
          ],
        ),
      ],
    );
  }

  // --- VIEW 2: EDIT MODE ---
  Widget _buildEditMode() {
    final layer = widget.selectedLayer!;
    final fontsToUse = layer.isDateElement ? _dateFonts : _textFonts;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // 1. Header & Back Button
        Row(
          children: [
            // NEW: Back Button
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
              onPressed: () {
                // Close keyboard if open
                FocusScope.of(context).unfocus();
                // Trigger the close callback
                widget.onClose();
              },
            ),
            Text(layer.isDateElement ? "EDIT DATE" : "EDIT TEXT",
                style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            const Spacer(),
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: const Icon(Icons.keyboard_hide, color: Colors.white54),
            )
          ],
        ),

        const SizedBox(height: 5),

        // 2. Text Input (Hidden for Date)
        if (!layer.isDateElement)
          TextField(
            controller: _textEditingController,
            onChanged: widget.onTextChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white10,
              prefixIcon: const Icon(Icons.edit, color: Colors.white54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),

        // 3. Orientation Toggle (Only for Date)
        if (layer.isDateElement)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8)
            ),
            child: Row(
              children: [
                Expanded(child: _buildToggleOption("Horizontal", !layer.isVertical)),
                Expanded(child: _buildToggleOption("Vertical", layer.isVertical)),
              ],
            ),
          ),

        const SizedBox(height: 10),

        // 4. Font Selector
        const Text("Font Style", style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: fontsToUse.length,
            itemBuilder: (context, index) {
              final font = fontsToUse[index];
              final isSelected = layer.fontFamily == font;
              return GestureDetector(
                onTap: () => widget.onFontChanged(font),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                      "Abc",
                      style: GoogleFonts.getFont(
                          font,
                          color: isSelected ? Colors.black : Colors.white,
                          fontSize: 16
                      )
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // 5. Size Slider
        Row(
          children: [
            const Text("Size", style: TextStyle(color: Colors.white, fontSize: 12)),
            Expanded(
              child: Slider(
                value: layer.fontSize,
                min: 10,
                max: 100,
                activeColor: Colors.white,
                inactiveColor: Colors.white24,
                onChanged: widget.onSizeChanged,
              ),
            ),
            Text(layer.fontSize.toInt().toString(), style: const TextStyle(color: Colors.white)),
          ],
        ),

        const SizedBox(height: 10),

        // 6. SIMPLIFIED COLOR PICKER
        const Text("Color & Opacity", style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 10),

        SimpleColorPicker(
          selectedColor: layer.color,
          onColorChanged: widget.onColorChanged,
        ),

        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildToggleOption(String label, bool isActive) {
    return GestureDetector(
      onTap: () => widget.onVerticalChanged(label == "Vertical"),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: isActive ? Colors.white24 : Colors.transparent,
            borderRadius: BorderRadius.circular(6)
        ),
        child: Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBigButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        height: 80,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 3. SIMPLE COLOR PICKER
// ---------------------------------------------------------
class SimpleColorPicker extends StatelessWidget {
  final Color selectedColor;
  final Function(Color) onColorChanged;

  const SimpleColorPicker({super.key, required this.selectedColor, required this.onColorChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. THE MASTER COLOR SLIDER (Black -> White -> Rainbow)
        _buildGradientTrack(
          height: 20,
          gradient: const LinearGradient(
              colors: [
                Colors.black,
                Colors.white,
                Color(0xffff0000), // Red
                Color(0xffffff00), // Yellow
                Color(0xff00ff00), // Green
                Color(0xff00ffff), // Cyan
                Color(0xff0000ff), // Blue
                Color(0xffff00ff), // Magenta
                Color(0xffff0000), // Red
              ],
              stops: [
                0.0, 0.1, // Black to White
                0.1, 0.25, 0.4, 0.55, 0.7, 0.85, 1.0 // Rainbow
              ]
          ),
          onPositionChanged: (percent) {
            _calculateColorFromPosition(percent);
          },
        ),

        const SizedBox(height: 15),

        // 2. OPACITY SLIDER
        _buildGradientTrack(
          height: 20,
          gradient: LinearGradient(
              colors: [
                selectedColor.withOpacity(0.0),
                selectedColor.withOpacity(1.0),
              ]
          ),
          onPositionChanged: (percent) {
            onColorChanged(selectedColor.withOpacity(percent.clamp(0.0, 1.0)));
          },
        ),

        const SizedBox(height: 8),

        // 3. PREVIEW HEX
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            "#${selectedColor.value.toRadixString(16).toUpperCase().substring(2)}",
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        )
      ],
    );
  }

  void _calculateColorFromPosition(double position) {
    Color result;

    if (position < 0.05) {
      result = Colors.black;
    } else if (position < 0.12) {
      result = Colors.white;
    } else {
      double huePercent = (position - 0.12) / (1.0 - 0.12);
      double hue = (huePercent * 360).clamp(0.0, 360.0);
      result = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
    }
    onColorChanged(result.withOpacity(selectedColor.opacity));
  }

  Widget _buildGradientTrack({
    required double height,
    required Gradient gradient,
    required Function(double) onPositionChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) {
            double percent = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
            onPositionChanged(percent);
          },
          onTapDown: (details) {
            double percent = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
            onPositionChanged(percent);
          },
          child: Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24)
            ),
            child: Container(),
          ),
        );
      },
    );
  }
}