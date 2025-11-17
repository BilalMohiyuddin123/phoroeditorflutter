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
  bool isDateElement; // Changed from isTimeElement
  bool isVertical;    // NEW: Handles Vertical/Horizontal
  bool isSelected;

  TextLayer({
    required this.id,
    required this.text,
    this.position = const Offset(100, 200),
    this.fontSize = 32.0,
    this.color = Colors.white,
    this.fontFamily = 'Roboto',
    this.isDateElement = false,
    this.isVertical = false, // Default horizontal
    this.isSelected = true,
  });
}

// ---------------------------------------------------------
// 2. SMART CONTROL PANEL UI
// ---------------------------------------------------------
class SmartTextPanel extends StatefulWidget {
  final TextLayer? selectedLayer;
  final VoidCallback onAddNewText;
  final VoidCallback onAddNewDate; // Changed from Time
  final Function(Color) onColorChanged;
  final Function(double) onSizeChanged;
  final Function(String) onTextChanged;
  final Function(String) onFontChanged;
  final Function(bool) onVerticalChanged; // New callback

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
  });

  @override
  State<SmartTextPanel> createState() => _SmartTextPanelState();
}

class _SmartTextPanelState extends State<SmartTextPanel> {
  final TextEditingController _textEditingController = TextEditingController();

  // Standard Fonts
  final List<String> _textFonts = [
    "Roboto", "Montserrat", "Lobster", "Oswald", "Bebas Neue",
    "Pacifico", "Dancing Script", "Abril Fatface", "Caveat", "Shadows Into Light"
  ];

  // Date Specific Fonts (Perforated, Digital, Typewriter)
  final List<String> _dateFonts = [
    "Codystar", // Perforated dots
    "Special Elite", // Typewriter
    "Orbitron", // Digital
    "Wallpoet", // Stencil
    "Press Start 2P", // Retro
    "Bungee Inline",
    "Major Mono Display"
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
        // 1. Header & Close
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(layer.isDateElement ? "EDIT DATE" : "EDIT TEXT",
                style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: const Icon(Icons.keyboard_hide, color: Colors.white54),
            )
          ],
        ),

        const SizedBox(height: 15),

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
                      "19/05",
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

        // 6. Color Picker
        const Text("Color", style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 10),
        SpectrumColorSlider(
          selectedColor: layer.color,
          onColorChanged: widget.onColorChanged,
        ),
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

class SpectrumColorSlider extends StatefulWidget {
  final Color selectedColor;
  final Function(Color) onColorChanged;

  const SpectrumColorSlider({super.key, required this.selectedColor, required this.onColorChanged});

  @override
  State<SpectrumColorSlider> createState() => _SpectrumColorSliderState();
}

class _SpectrumColorSliderState extends State<SpectrumColorSlider> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onPanUpdate: (details) => _handleTouch(details.localPosition, context),
          onTapDown: (details) => _handleTouch(details.localPosition, context),
          child: Container(
            height: 35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                colors: [
                  Color(0xffff0000), Color(0xffffff00), Color(0xff00ff00),
                  Color(0xff00ffff), Color(0xff0000ff), Color(0xffff00ff), Color(0xffff0000)
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(backgroundColor: widget.selectedColor, radius: 15),
            const SizedBox(width: 10),
            Text(
              "#${widget.selectedColor.value.toRadixString(16).toUpperCase().substring(2)}",
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            )
          ],
        )
      ],
    );
  }

  void _handleTouch(Offset localPosition, BuildContext context) {
    final double width = context.size!.width;
    final double percent = (localPosition.dx / width).clamp(0.0, 1.0);
    final HSVColor hsv = HSVColor.fromAHSV(1.0, percent * 360, 1.0, 1.0);
    widget.onColorChanged(hsv.toColor());
  }
}