import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../supabase/supabase_bootstrap.dart';
import 'workspace_widgets.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _documentText(
              context,
              'Could not open the file. Please try again.',
              'फ़ाइल नहीं खुल सकी। फिर प्रयास करें।',
            ),
          ),
        ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _documentText(
            context,
            'Could not open the file. Please try again.',
            'फ़ाइल नहीं खुल सकी। फिर प्रयास करें।',
          ),
        ),
      ),
    );
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

String _documentText(BuildContext context, String en, String hi) =>
    Localizations.localeOf(context).languageCode == 'hi' ? hi : en;

class _StoragePhotoDialog extends StatefulWidget {
  const _StoragePhotoDialog({
    required this.title,
    required this.path,
    this.onReplace,
  });
  final String title, path;
  final VoidCallback? onReplace;
  @override
  State<_StoragePhotoDialog> createState() => _StoragePhotoDialogState();
}

class _StoragePhotoDialogState extends State<_StoragePhotoDialog> {
  late Future<String> _url = createDeliveryDocumentSignedUrl(widget.path);
  @override
  Widget build(BuildContext context) {
    String t(String en, String hi) => _documentText(context, en, hi);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: t('Close preview', 'प्रमाण बंद करें'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.path.split('/').last,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              FutureBuilder<String>(
                future: _url,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return SizedBox(
                      height: 220,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(t('Opening document…', 'दस्तावेज़ खुल रहा है…')),
                        ],
                      ),
                    );
                  }
                  if (snap.hasError || snap.data == null) {
                    return WorkspaceEmptyState(
                      title: t(
                        'Preview could not be loaded',
                        'प्रमाण नहीं खुल सका',
                      ),
                      message: t(
                        'Try loading it again or use Open file below.',
                        'फिर प्रयास करें या नीचे फ़ाइल खोलें दबाएँ।',
                      ),
                      icon: Icons.insert_drive_file_outlined,
                      action: OutlinedButton.icon(
                        onPressed:
                            () => setState(
                              () =>
                                  _url = createDeliveryDocumentSignedUrl(
                                    widget.path,
                                  ),
                            ),
                        icon: const Icon(Icons.refresh),
                        label: Text(t('Try again', 'फिर प्रयास करें')),
                      ),
                    );
                  }
                  if (widget.path.toLowerCase().endsWith('.pdf')) {
                    return GuidanceCard(
                      title: t('PDF document', 'PDF दस्तावेज़'),
                      message: t(
                        'Tap Open file to read all pages in your browser or PDF viewer.',
                        'सभी पृष्ठ देखने के लिए फ़ाइल खोलें दबाएँ।',
                      ),
                      icon: Icons.picture_as_pdf_outlined,
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 380),
                      child: InteractiveViewer(
                        minScale: .5,
                        maxScale: 4,
                        child: Image.network(
                          snap.data!,
                          fit: BoxFit.contain,
                          loadingBuilder:
                              (_, child, progress) =>
                                  progress == null
                                      ? child
                                      : const SizedBox(
                                        height: 220,
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                          errorBuilder:
                              (_, _, _) => Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  t(
                                    'Image preview unavailable. Use Open file below.',
                                    'तस्वीर नहीं दिख रही है। नीचे फ़ाइल खोलें दबाएँ।',
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => openDeliveryDocument(context, widget.path),
                icon: const Icon(Icons.open_in_new),
                label: Text(t('Open file', 'फ़ाइल खोलें')),
              ),
              if (widget.onReplace != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onReplace!();
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    t('Replace uploaded file', 'अपलोड की गई फ़ाइल बदलें'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
