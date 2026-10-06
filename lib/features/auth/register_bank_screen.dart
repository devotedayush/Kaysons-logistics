import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/pill_text_field.dart';
import 'registration_draft.dart';
import 'registration_shell.dart';

class RegisterBankScreen extends StatefulWidget {
  const RegisterBankScreen({super.key});

  @override
  State<RegisterBankScreen> createState() => _RegisterBankScreenState();
}

class _RegisterBankScreenState extends State<RegisterBankScreen> {
  final _holder = TextEditingController();
  final _account = TextEditingController();
  String? _selectedChequeName;

  @override
  void dispose() {
    _holder.dispose();
    _account.dispose();
    super.dispose();
  }

  Future<void> _pickChequePhoto() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.imageReadFailed)),
      );
      return;
    }
    final draft = RegistrationDraft.instance;
    draft.chequeBytes = bytes;
    draft.chequeFileName = file.name;
    draft.chequeExtension = file.extension;
    setState(() => _selectedChequeName = file.name);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return RegistrationShell(
      step: 4,
      title: l.registerBankTitle,
      subtitle: l.registerProfileSubtitle,
      fields: [
        LabeledField(
          label: l.accountHolderName,
          child: PillTextField(controller: _holder, hint: 'Naveen Garg'),
        ),
        LabeledField(
          label: l.bankAccountNumber,
          child: PillTextField(
            controller: _account,
            hint: '135469464313464',
            keyboardType: TextInputType.number,
          ),
        ),
        LabeledField(
          label: l.photoUpload,
          child: _UploadChip(
            selectedName: _selectedChequeName,
            onTap: _pickChequePhoto,
          ),
        ),
      ],
      ctaLabel: l.next,
      onNext: () {
        RegistrationDraft.instance.bankHolder = _holder.text.trim();
        RegistrationDraft.instance.bankAccountNumber = _account.text.trim();
        context.push('/register/contact');
      },
    );
  }
}

class _UploadChip extends StatelessWidget {
  const _UploadChip({required this.onTap, this.selectedName});
  final VoidCallback onTap;
  final String? selectedName;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E7E7),
          border: Border.all(color: const Color(0xFFCAC4D0)),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selectedName == null
                  ? Icons.upload_file
                  : Icons.check_circle_outline,
              size: 18,
              color:
                  selectedName == null
                      ? const Color(0xFF625B71)
                      : const Color(0xFF14A33A),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selectedName == null ? l.uploadBlankCheque : l.selectedReplace,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF625B71),
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
