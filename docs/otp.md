# Phone OTP Login

## Goal

Add email OTP and India phone number OTP login alongside the existing email/password login.

## Current App State

- Login currently uses email and password through Supabase Auth.
- User phone numbers are stored in `profiles.phone`.
- For OTP login, the phone number also needs to be linked to the Supabase Auth user, not only the `profiles` table.

## Recommended Flow

1. User chooses email OTP or phone OTP.
2. For phone OTP, user enters a 10 digit Indian mobile number.
3. App normalizes phone input to E.164 format: `+91XXXXXXXXXX`.
4. App asks Supabase to send an OTP.
5. User enters the 6 digit OTP.
6. App verifies the OTP with Supabase.
7. App fetches the existing profile role and routes the user:
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

await supabase.auth.signInWithOtp(
  email: 'transporter@example.com',
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

final response = await supabase.auth.verifyOTP(
  email: 'transporter@example.com',
  token: '123456',
  type: OtpType.email,
);
```

Use `shouldCreateUser: false` so unknown emails or phone numbers do not create incomplete accounts.

## AuthService Additions

```dart
Future<void> sendPhoneOtp(String phone) {
  return _auth.signInWithOtp(
    phone: phone,
    shouldCreateUser: false,
  );
}

Future<void> sendEmailOtp(String email) {
  return _auth.signInWithOtp(
    email: email,
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

Future<void> verifyEmailOtp({
  required String email,
  required String token,
}) async {
  await _auth.verifyOTP(
    email: email,
    token: token,
    type: OtpType.email,
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
   - Supabase's default resend window is 60 seconds per user/phone.
   - The app should mirror this by disabling "Resend OTP" for 60 seconds after each send.
4. Ensure Indian SMS compliance before live use.

## Backend Linkage

- `profiles.email` must stay unique.
- `profiles.phone` must be unique when present.
- Registration stores phone numbers in E.164 format (`+91XXXXXXXXXX`).
- A profile phone update should sync the same phone onto the matching Supabase Auth user so email OTP and phone OTP both resolve to the same account.

Supabase supports phone login through SMS providers such as Twilio, MessageBird, Vonage, and community-supported TextLocal. India SMS delivery must follow TRAI DLT rules, so sender IDs and message templates should be registered with the SMS provider before production.

## Product Recommendation

Keep email/password as a fallback. Make phone OTP the primary login for transporters because they are likely to use the web app from mobile or shared operational devices.

## References

- Supabase Flutter `signInWithOtp`: https://supabase.com/docs/reference/dart/auth-signinwithotp
- Supabase Flutter `verifyOTP`: https://supabase.com/docs/reference/dart/auth-verifyotp
- Supabase Phone Login guide: https://supabase.com/docs/guides/auth/phone-login
