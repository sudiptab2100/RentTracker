import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lightweight WhatsApp integration via `wa.me` deep links and the native share
/// sheet. Sending a document silently is not possible without the paid Business
/// API, so PDF/CSV files are shared through the OS share sheet (the owner then
/// picks WhatsApp and taps send), while text reminders open the tenant chat
/// with a pre-filled message.
class WhatsAppService {
  const WhatsAppService();

  /// Normalizes a phone number to digits with a country code (no '+').
  /// Assumes [countryCode] for local 10-digit numbers.
  static String sanitizePhone(String raw, {String countryCode = '91'}) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) digits = '$countryCode$digits';
    return digits;
  }

  /// Opens a WhatsApp chat with [phone], optionally pre-filling [text].
  /// Returns false if WhatsApp/browser could not be launched.
  Future<bool> openChat({
    required String phone,
    String? text,
    String countryCode = '91',
  }) async {
    final number = sanitizePhone(phone, countryCode: countryCode);
    if (number.isEmpty) return false;
    final query = (text != null && text.isNotEmpty)
        ? '?text=${Uri.encodeComponent(text)}'
        : '';
    final uri = Uri.parse('https://wa.me/$number$query');
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Writes [bytes] to a temp file and opens the share sheet so the owner can
  /// send it via WhatsApp (or any other app).
  Future<void> shareBytes(
    Uint8List bytes,
    String filename, {
    String? text,
    String? subject,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: text,
        subject: subject,
      ),
    );
  }

  /// Shares plain text (e.g. a reminder) through the share sheet.
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}

const whatsAppService = WhatsAppService();
