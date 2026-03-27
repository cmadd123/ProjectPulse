import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Scans a receipt image and extracts total amount and vendor name.
/// Uses Google ML Kit on-device text recognition (free, no API key).
class ReceiptScanResult {
  final double? amount;
  final String? vendor;
  final String? date;
  final String rawText;

  ReceiptScanResult({this.amount, this.vendor, this.date, required this.rawText});
}

class ReceiptScannerService {
  static final _textRecognizer = TextRecognizer();

  /// Scan a receipt image and extract structured data
  static Future<ReceiptScanResult> scanReceipt(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognized = await _textRecognizer.processImage(inputImage);
    final rawText = recognized.text;
    final lines = recognized.blocks
        .expand((block) => block.lines)
        .map((line) => line.text.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return ReceiptScanResult(
      amount: _extractTotal(lines),
      vendor: _extractVendor(lines),
      date: _extractDate(lines),
      rawText: rawText,
    );
  }

  /// Find the total amount — look for common total labels then grab the largest dollar amount
  static double? _extractTotal(List<String> lines) {
    // Regex for dollar amounts: $12.34, 12.34, $1,234.56
    final amountRegex = RegExp(r'\$?\s*(\d{1,3}(?:,\d{3})*\.?\d{0,2})');

    // First pass: look for lines with total/amount/due keywords
    final totalKeywords = ['total', 'amount due', 'balance due', 'grand total', 'subtotal', 'amount', 'sale'];
    double? bestTotal;

    for (final line in lines) {
      final lower = line.toLowerCase();
      // Skip lines about savings, discounts, tax-only lines
      if (lower.contains('save') || lower.contains('discount') || lower.contains('you saved')) continue;

      for (final keyword in totalKeywords) {
        if (lower.contains(keyword)) {
          final match = amountRegex.firstMatch(line);
          if (match != null) {
            final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
            if (value != null && value > 0) {
              // Prefer "total" over "subtotal", and larger amounts
              if (lower.contains('total') && !lower.contains('sub')) {
                bestTotal = value; // Strong match — use this
              } else if (bestTotal == null || value > bestTotal) {
                bestTotal = value;
              }
            }
          }
        }
      }
    }

    if (bestTotal != null) return bestTotal;

    // Fallback: find the largest dollar amount on the receipt
    double largest = 0;
    for (final line in lines) {
      for (final match in amountRegex.allMatches(line)) {
        final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
        if (value != null && value > largest && value < 100000) {
          largest = value;
        }
      }
    }

    return largest > 0 ? largest : null;
  }

  /// Extract vendor name — usually the first non-numeric, non-address line at the top
  static String? _extractVendor(List<String> lines) {
    if (lines.isEmpty) return null;

    // Known store names to match directly
    final knownStores = [
      'home depot', 'the home depot', 'lowes', "lowe's", 'menards',
      'ace hardware', 'true value', 'harbor freight', 'walmart',
      'costco', 'sam\'s club', 'fastenal', 'grainger', 'ferguson',
      'floor & decor', 'lumber liquidators', 'sherwin-williams',
      '84 lumber', 'builders firstsource', 'bmc', 'abc supply',
    ];

    // Check first 5 lines for known stores
    for (var i = 0; i < lines.length && i < 5; i++) {
      final lower = lines[i].toLowerCase();
      for (final store in knownStores) {
        if (lower.contains(store)) {
          return lines[i];
        }
      }
    }

    // Fallback: first line that looks like a name (not a number, not an address)
    for (var i = 0; i < lines.length && i < 3; i++) {
      final line = lines[i];
      // Skip lines that are mostly numbers, phone numbers, or addresses
      if (RegExp(r'^\d').hasMatch(line)) continue;
      if (RegExp(r'\d{3}[-.\s]?\d{3}[-.\s]?\d{4}').hasMatch(line)) continue;
      if (line.length < 3 || line.length > 40) continue;
      return line;
    }

    return null;
  }

  /// Extract date from receipt
  static String? _extractDate(List<String> lines) {
    // Common date formats: 03/26/2026, 3/26/26, Mar 26, 2026, 2026-03-26
    final dateRegex = RegExp(
        r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})|'
        r'(\w{3,9}\s+\d{1,2},?\s*\d{4})|'
        r'(\d{4}-\d{2}-\d{2})');

    for (final line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
