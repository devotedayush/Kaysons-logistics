import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../supabase/supabase_bootstrap.dart';

const _deliveryDocumentsBucket = 'delivery-documents';

Future<String> createDeliveryDocumentSignedUrl(String path) {
  return supabase.storage
      .from(_deliveryDocumentsBucket)
      .createSignedUrl(path, 60 * 10);
}

Future<void> openDeliveryDocument(BuildContext context, String path) async {
  try {
    final url = await createDeliveryDocumentSignedUrl(path);
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open file')));
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open file: $e')));
  }
}

Future<void> showDeliveryDocumentPreview({
  required BuildContext context,
  required String title,
  required String path,
  VoidCallback? onReplace,
}) async {
  await showDialog<void>(
    context: context,
    builder:
        (context) => Dialog(
          insetPadding: const EdgeInsets.all(18),
          child: _StoragePhotoDialog(
            title: title,
            path: path,
            onReplace: onReplace,
          ),
        ),
  );
}

class _StoragePhotoDialog extends StatelessWidget {
  const _StoragePhotoDialog({
    required this.title,
    required this.path,
    this.onReplace,
  });

  final String title;
  final String path;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: createDeliveryDocumentSignedUrl(path),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 280,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final url = snap.data;
                if (url == null || snap.hasError) {
                  return SizedBox(
                    height: 180,
                    child: Center(
                      child: Text(
                        'Could not load preview${snap.error == null ? '' : ': ${snap.error}'}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 420),
                    color: const Color(0xFFF6EDFB),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            height: 280,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder:
                            (_, __, ___) => const SizedBox(
                              height: 180,
                              child: Center(child: Text('Preview unavailable')),
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onReplace != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onReplace?.call();
                    },
                    icon: const Icon(Icons.change_circle_outlined),
                    label: const Text('Replace'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => openDeliveryDocument(context, path),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
                FilledButton.icon(
                  onPressed: () => openDeliveryDocument(context, path),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
