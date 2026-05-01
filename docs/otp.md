# Phone OTP Login

## Goal

Add India phone number + OTP login alongside the existing email/password login.

## Current App State

- Login currently uses email and password through Supabase Auth.
- User phone numbers are stored in `profiles.phone`.
- For OTP login, the phone number also needs to be linked to the Supabase Auth user, not only the `profiles` table.

## Recommended Flow

1. User enters a 10 digit Indian mobile number.
2. App normalizes it to E.164 format: `+91XXXXXXXXXX`.
3. App asks Supabase to send an OTP.
4. User enters the 6 digit OTP.
5. App verifies the OTP with Supabase.
6. App fetches the existing profile role and routes the user:
   - `admin` -> `/admin`
   - `logistics_manager` -> `/lm/home`
   - `transporter` -> `/home`

## Supabase Client Calls

Send OTP:

```dart
await supabase.auth.signInWithOtp(
  phone: '+919876543210',
  shouldCreateUser: false,
);
```

Verify OTP:

```dart
final response = await supabase.auth.verifyOTP(
  phone: '+919876543210',
  token: '123456',
  type: OtpType.sms,
);
```

Use `shouldCreateUser: false` so unknown phone numbers do not create incomplete accounts.

## AuthService Additions

```dart
Future<void> sendPhoneOtp(String phone) {
  return _auth.signInWithOtp(
    phone: phone,
    shouldCreateUser: false,
  );
}

Future<void> verifyPhoneOtp({
  required String phone,
  required String token,
}) async {
  await _auth.verifyOTP(
    phone: phone,
    token: token,
    type: OtpType.sms,
  );
}
```

## India Phone Normalization

```dart
String normalizeIndiaPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  final tenDigits =
      digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  return '+91$tenDigits';
}
```

Reject the input if the final number is not exactly `+91` plus 10 digits.

## Supabase Dashboard Setup

1. Enable Phone provider in Supabase Auth.
2. Configure an SMS provider.
3. Configure OTP rate limits and CAPTCHA before production.
4. Ensure Indian SMS compliance before live use.

Supabase supports phone login through SMS providers such as Twilio, MessageBird, Vonage, and community-supported TextLocal. India SMS delivery must follow TRAI DLT rules, so sender IDs and message templates should be registered with the SMS provider before production.

## Product Recommendation

Keep email/password as a fallback. Make phone OTP the primary login for transporters because they are likely to use the web app from mobile or shared operational devices.

## References

- Supabase Flutter `signInWithOtp`: https://supabase.com/docs/reference/dart/auth-signinwithotp
- Supabase Flutter `verifyOTP`: https://supabase.com/docs/reference/dart/auth-verifyotp
- Supabase Phone Login guide: https://supabase.com/docs/guides/auth/phone-login
