import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/freights_repo.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';

class InvoiceLinkScreen extends StatefulWidget {
  const InvoiceLinkScreen({super.key, required this.bidId});

  final String bidId;

  @override
  State<InvoiceLinkScreen> createState() => _InvoiceLinkScreenState();
}

class _InvoiceLinkScreenState extends State<InvoiceLinkScreen> {
  final _invoice = TextEditingController();
  final _gr = TextEditingController();
  final _eway = TextEditingController();
  final _toll = TextEditingController();
  final _club = TextEditingController();
  final _dalla = TextEditingController();
  final _other = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_invoice, _gr, _eway, _toll, _club, _dalla, _other]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (_invoice.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice number is required')),
      );
      return;
    }
    if (_gr.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GR / Bilty number is required before locking freight')),
      );
      return;
    }
    if (_eway.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-way bill number is required before locking freight')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FreightsRepo.instance.linkInvoiceAndLock(
        freightId: widget.bidId,
        invoiceNumber: _invoice.text.trim(),
        grNumber: _gr.text.trim(),
        eWayBillNumber: _eway.text.trim(),
        toll: double.tryParse(_toll.text.trim()),
        club: double.tryParse(_club.text.trim()),
        dalla: double.tryParse(_dalla.text.trim()),
        other: double.tryParse(_other.text.trim()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice linked. Freight locked.')),
      );
      context.go('/lm/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Link invoice'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Invoice & GR linking',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          _row('Invoice Number',
              PillTextField(controller: _invoice, hint: 'INV-2026-0042', textAlign: TextAlign.start)),
          _row('GR / Bilty Number',
              PillTextField(controller: _gr, hint: 'GR-7821', textAlign: TextAlign.start)),
          _row('E-way Bill Number',
              PillTextField(controller: _eway, hint: 'EWB-1122334455', textAlign: TextAlign.start)),
          const Divider(height: 32),
          const Text('Mid-cost adjustments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          _row('Toll charges',
              PillTextField(controller: _toll, hint: '0', keyboardType: TextInputType.number, textAlign: TextAlign.start)),
          _row('Club charges',
              PillTextField(controller: _club, hint: '0', keyboardType: TextInputType.number, textAlign: TextAlign.start)),
          _row('Dalla charges',
              PillTextField(controller: _dalla, hint: '0', keyboardType: TextInputType.number, textAlign: TextAlign.start)),
          _row('Other charges',
              PillTextField(controller: _other, hint: '0', keyboardType: TextInputType.number, textAlign: TextAlign.start)),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _saving ? 'Saving…' : 'Submit & lock freight',
            onPressed: _saving ? null : _submit,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _row(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
