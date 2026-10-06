import 'package:flutter_test/flutter_test.dart';
import 'package:kaysons_logistics/core/supabase/freights_repo.dart';

void main() {
  test('delivery update preserves office references and existing proof', () {
    final saved = <String, dynamic>{
      'invoice_numbers': ['OFFICE-1'],
      'invoice_photo_path': 'office/invoice.jpg',
      'pod_photo_path': 'delivery/pod.jpg',
      'receiver_name': 'Old receiver',
    };
    final update = <String, dynamic>{
      'invoice_numbers': ['TRANSPORTER-EDIT'],
      'invoice_photo_path': null,
      'receiver_name': 'Correct receiver',
    };
    final merged = mergeTransporterDeliveryStage(
      saved,
      update,
      DateTime.utc(2026, 10, 1, 12),
    );
    expect(merged['invoice_numbers'], ['OFFICE-1']);
    expect(merged['invoice_photo_path'], 'office/invoice.jpg');
    expect(merged['pod_photo_path'], 'delivery/pod.jpg');
    expect(merged['receiver_name'], 'Correct receiver');
    expect(merged['submitted_at'], '2026-10-01T12:00:00.000Z');
    expect(saved['receiver_name'], 'Old receiver');
  });
}
