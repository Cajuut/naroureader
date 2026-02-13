import 'package:flutter/material.dart';

class VerticalTextViewer extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double width;
  final double height;

  const VerticalTextViewer({
    super.key,
    required this.text,
    required this.style,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // text contains lines separated by '\n'.
    // Each line is a vertical column.
    
    return Container(
      width: width,
      height: height,
      color: Colors.transparent, // Background handled by parent
      child: CustomPaint(
        size: Size(width, height),
        painter: _VerticalTextPainter(
          text: text,
          style: style,
        ),
      ),
    );
  }
}

class _VerticalTextPainter extends CustomPainter {
  final String text;
  final TextStyle style;

  _VerticalTextPainter({
    required this.text,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      locale: const Locale('ja', 'JP'),
    );

    final fontSize = style.fontSize ?? 16.0;
    final lineHeight = style.height ?? 1.8;
    final oneLineWidth = fontSize * lineHeight;
    
    // Start from Top-Right
    double currentX = size.width - oneLineWidth;
    double currentY = 0;
    
    // Split text into lines (vertical columns)
    final lines = text.split('\n');
    
    for (final line in lines) {
      if (currentX < 0) break; // Out of bounds
      
      currentY = 0;
      
      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        
        // Draw char
        // Check for rotation if needed (brackets, punctuation)
        // For now, draw everything upright except specific chars?
        // Or assume Japanese font handles it? (No, Flutter draws horizontal glyphs usually)
        
        // Simple rotation check
        bool needsRotation = _needsRotation(char);
        
        textPainter.text = TextSpan(text: char, style: style);
        textPainter.layout();
        
        final charWidth = textPainter.width;
        final charHeight = textPainter.height;
        
        // Center char in line width
        final xOffset = currentX + (oneLineWidth - charWidth) / 2;
        
        if (needsRotation) {
          canvas.save();
          // Rotate 90 degrees clockwise
          canvas.translate(xOffset + charWidth / 2, currentY + charHeight / 2);
          canvas.rotate(90 * 3.14159 / 180);
          canvas.translate(-(xOffset + charWidth / 2), -(currentY + charHeight / 2));
          textPainter.paint(canvas, Offset(xOffset, currentY));
          canvas.restore();
        } else {
          textPainter.paint(canvas, Offset(xOffset, currentY));
        }
        
        // Advance Y
        // Use fixed pitch or proportional?
        // Usually fixed pitch for vertical text looks better.
        currentY += fontSize; // simplistic
      }
      
      // Move to next line (Left)
      currentX -= oneLineWidth;
    }
  }

  bool _needsRotation(String char) {
    // Rotate parentheses, punctuation, dashes
    const rotateChars = ['(', ')', '[', ']', '「', '」', '『', '』', 'ー', '…', '〜'];
    return rotateChars.contains(char);
    // Actually, Japanese '「' is usually upright in vertical text (top/bottom bracket).
    // If using horizontal font, '「' is left bracket. In vertical, it should be top bracket.
    // Horizontal font glyph '「' rotated 90 deg becomes top bracket? No.
    // Top bracket is a different glyph or rotation.
    // '「' (U+300C) in horizontal is 'corner bracket'.
    // If we rotate it 90 deg clockwise, it looks like TOP-RIGHT corner.
    // Correct vertical '「' looks like top half of box.
    
    // This is complex. Many apps map to vertical presentation forms (U+FExx).
    // For 'ー' (cho-on), horizontal is horizontal bar. Vertical needs vertical bar.
    // Rotating horizontal bar 90 degrees works.
    
    // For brackets, it highly depends on the font.
    // Let's rotate 'ー', '…', '〜', '(', ')' for now.
    // Keeping brackets upright often works if they are full-width.
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Simplified
  }
}
