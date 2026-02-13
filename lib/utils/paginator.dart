import 'package:flutter/material.dart';

class Paginator {
  /// Split text into pages based on the available size and text style.
  static List<String> paginate({
    required String text,
    required TextStyle style,
    required Size boxSize,
    required EdgeInsets padding,
    bool isVertical = false,
  }) {
    if (text.isEmpty) return [];

    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      locale: const Locale('ja', 'JP'),
    );

    final double maxWidth = boxSize.width - padding.horizontal;
    final double maxHeight = boxSize.height - padding.vertical;

    if (maxWidth <= 0 || maxHeight <= 0) return [text];

    // ───────────────────────────────────────────────
    // Vertical Pagination Logic
    // ───────────────────────────────────────────────
    if (isVertical) {
      final List<String> pages = [];
      final sb = StringBuffer();
      
      // Vertical layout params
      final fontSize = style.fontSize ?? 16.0;
      final lineSpacingMult = style.height ?? 1.8;
      // Width of one vertical line (including spacing)
      final oneLineWidth = fontSize * lineSpacingMult;
      
      // Max vertical lines per page (horizontal capacity)
      final int maxLinesPerPage = (maxWidth / oneLineWidth).floor();
      if (maxLinesPerPage < 1) return [text]; // Screen too narrow

      final paragraphs = text.split('\n');
      int currentLinesOnPage = 0;
      
      for (final paragraph in paragraphs) {
        if (paragraph.isEmpty) {
          // Empty line = empty vertical column
          if (currentLinesOnPage >= maxLinesPerPage) {
             pages.add(sb.toString());
             sb.clear();
             currentLinesOnPage = 0;
          }
          sb.writeln(); 
          currentLinesOnPage++;
          continue;
        }

        int charIndex = 0;
        
        // Loop through chars in paragraph
        while (charIndex < paragraph.length) {
          // Check page full
          if (currentLinesOnPage >= maxLinesPerPage) {
            pages.add(sb.toString());
            sb.clear();
            currentLinesOnPage = 0;
          }

          // Build one vertical line
          double currentLineHeight = 0;
          String lineBuffer = "";
          
          while (charIndex < paragraph.length) {
            final char = paragraph[charIndex];
            
            // Measure char height
            // Ideally we measure exactly, but for simplicity use fontSize
            // Japanese chars are usually square.
            // Half-width chars might need rotation but take less space vertically (as width)
            // For simple estimation, assume height = fontSize
            final charH = fontSize; 
            
            // If line buffer is empty, force add at least one char to prevent infinite loop
            if (lineBuffer.isNotEmpty && currentLineHeight + charH > maxHeight) {
              // Line full
              break;
            }
            
            lineBuffer += char;
            currentLineHeight += charH;
            charIndex++;
          }
          
          sb.write(lineBuffer);
          sb.writeln(); // Separate vertical columns by newline internally
          currentLinesOnPage++;
        }
      }
      
      if (sb.isNotEmpty) {
        pages.add(sb.toString());
      }
      
      return pages;
    }

    // ───────────────────────────────────────────────
    // Horizontal Pagination Logic
    // ───────────────────────────────────────────────
    final List<String> pages = [];
    final paragraphs = text.split('\n');
    String currentPageContent = '';
    double currentHeight = 0;
    
    // Helper to measure a chunk of text
    double measureHeight(String s) {
      if (s.isEmpty) return 0;
      textPainter.text = TextSpan(text: s, style: style);
      textPainter.layout(maxWidth: maxWidth);
      return textPainter.height;
    }

    StringBuffer pageBuffer = StringBuffer();

    for (int i = 0; i < paragraphs.length; i++) {
      String paragraph = paragraphs[i];
      
      if (paragraph.isEmpty) {
        // Just a newline
        // We need to measure height of a newline?
        // Usually textPainter with '\n' gives height of one line.
        double newlineHeight = measureHeight('\n');
        
        if (currentHeight + newlineHeight > maxHeight) {
          pages.add(pageBuffer.toString());
          pageBuffer.clear();
          currentHeight = 0;
        }
        pageBuffer.writeln();
        currentHeight += newlineHeight;
        continue;
      }

      double paraHeight = measureHeight(paragraph);
      
      if (currentHeight + paraHeight <= maxHeight) {
        pageBuffer.writeln(paragraph);
        currentHeight += paraHeight;
      } else {
        // Paragraph doesn't fit
        if (paraHeight > maxHeight) {
          // Should we fill the remaining page first?
          // If page is mostly empty, yes. If mostly full, start new page.
          // Let's keep simple: if buffer not empty, push it.
          if (pageBuffer.isNotEmpty) {
            pages.add(pageBuffer.toString());
            pageBuffer.clear();
            currentHeight = 0;
          }
          
          // Split huge paragraph
          int currentIndex = 0;
          while (currentIndex < paragraph.length) {
            // Find fitting text
            String remaining = paragraph.substring(currentIndex);
            textPainter.text = TextSpan(text: remaining, style: style);
            textPainter.layout(maxWidth: maxWidth);
            
            if (textPainter.height <= maxHeight) {
              pageBuffer.writeln(remaining);
              currentHeight = textPainter.height;
              currentIndex = paragraph.length;
              break; 
            }
            
            // Find break point
            TextPosition pos = textPainter.getPositionForOffset(Offset(maxWidth, maxHeight));
            int end = pos.offset;
            
            // Safety for infinite loops
            if (end <= 0) end = 1;
            
            String chunk = remaining.substring(0, end);
            pages.add(chunk); 
            currentIndex += end;
          }
        } else {
          // Fits in a new page
          pages.add(pageBuffer.toString());
          pageBuffer.clear();
          pageBuffer.writeln(paragraph);
          currentHeight = paraHeight;
        }
      }
    }
    
    if (pageBuffer.isNotEmpty) {
      pages.add(pageBuffer.toString());
    }

    return pages;
  }
}
