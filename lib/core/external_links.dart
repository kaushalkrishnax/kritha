import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openExternalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    _notify(context, 'This link is not a valid web address.');
    return false;
  }
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      _notify(context, 'No browser was available to open this link.');
    }
    return opened;
  } on Object {
    if (context.mounted) {
      _notify(context, 'This link could not be opened.');
    }
    return false;
  }
}

Future<void> copyTextToClipboard(
  BuildContext context,
  String text, {
  String message = 'Copied to clipboard',
}) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) _notify(context, message);
  } on Object {
    if (context.mounted) _notify(context, 'The text could not be copied.');
  }
}

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
