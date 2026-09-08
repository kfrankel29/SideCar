import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class LegalDocuments {
  static const version = '2026-09-03';
  static final privacyPolicy = Uri.parse(
    'https://sidecar-fb0e7.web.app/privacy/',
  );
  static final termsOfService = Uri.parse(
    'https://sidecar-fb0e7.web.app/terms/',
  );
  static final accountDeletion = Uri.parse(
    'https://sidecar-fb0e7.web.app/delete-account/',
  );

  static Future<void> open(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That page could not be opened.')),
      );
    }
  }
}

Future<bool> showLegalConsentDialog(BuildContext context) async {
  var acceptedTerms = false;
  var confirmedAge = false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Before you continue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: confirmedAge,
              onChanged: (value) =>
                  setDialogState(() => confirmedAge = value == true),
              title: const Text('I confirm that I am at least 18 years old.'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: acceptedTerms,
              onChanged: (value) =>
                  setDialogState(() => acceptedTerms = value == true),
              title: const Text(
                'I agree to the Terms of Service and acknowledge the Privacy Policy.',
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => LegalDocuments.open(
                    dialogContext,
                    LegalDocuments.termsOfService,
                  ),
                  child: const Text('Terms of Service'),
                ),
                TextButton(
                  onPressed: () => LegalDocuments.open(
                    dialogContext,
                    LegalDocuments.privacyPolicy,
                  ),
                  child: const Text('Privacy Policy'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: acceptedTerms && confirmedAge
                ? () => Navigator.pop(dialogContext, true)
                : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    ),
  );
  return result == true;
}
