import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kaysons_logistics/core/supabase/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'profile read failure after successful verification does not consume OTP again',
    () async {
      var verifications = 0;
      var profileReads = 0;
      final jwtPayload = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'exp':
                    DateTime.now()
                        .add(const Duration(hours: 1))
                        .millisecondsSinceEpoch ~/
                    1000,
                'sub': '11111111-1111-1111-1111-111111111111',
                'role': 'authenticated',
              }),
            ),
          )
          .replaceAll('=', '');
      final user = {
        'id': '11111111-1111-1111-1111-111111111111',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': '',
        'phone': '919876543210',
        'phone_confirmed_at': '2026-10-04T00:00:00Z',
        'created_at': '2026-10-04T00:00:00Z',
        'app_metadata': {},
        'user_metadata': {},
      };
      final transport = MockClient((request) async {
        if (request.url.path.endsWith('/verify')) {
          verifications++;
          return http.Response(
            jsonEncode({
              'access_token': 'eyJhbGciOiJIUzI1NiJ9.$jwtPayload.signature',
              'refresh_token': 'test-refresh',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': user,
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/profiles')) {
          profileReads++;
          if (profileReads == 1) {
            return http.Response(
              jsonEncode({'message': 'temporary read failure', 'code': 'TEST'}),
              500,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'status': 'pending', 'role': 'transporter'}),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = SupabaseClient(
        'https://registration.test',
        'test-anon',
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      final service = AuthService.forClient(client);
      await expectLater(
        service.verifyRegistrationOtp(phone: '+919876543210', token: '123456'),
        throwsA(isA<PostgrestException>()),
      );
      expect(service.user?.phoneConfirmedAt, isNotNull);
      final profile = await service.verifyRegistrationOtp(
        phone: '+919876543210',
        token: '123456',
      );
      expect(profile['status'], 'pending');
      expect(verifications, 1);
      expect(profileReads, 2);
      // A confirmed session for another number must not bypass its SMS proof.
      await expectLater(
        service.verifyRegistrationOtp(phone: '+919876543211', token: '123456'),
        throwsA(isA<AuthException>()),
      );
      expect(verifications, 2);
      expect(profileReads, 2);
    },
  );
}
