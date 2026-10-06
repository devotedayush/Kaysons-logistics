import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase/auth_service.dart';
import 'auth_workspace.dart';
import '../../core/widgets/workspace_widgets.dart';
import '../../core/widgets/primary_button.dart';
import 'enrollment_strings.dart';

abstract class PhoneRegistrationGateway {
  Future<void> send(String phone);
  Future<Map<String, dynamic>?> verify(String phone, String code);
  Future<Map<String, dynamic>?> profile();
  Future<void> complete(String name, String email);
  Future<AppRole> approvedRole();
  Future<void> signOut();
}

class _LiveRegistrationGateway implements PhoneRegistrationGateway {
  final service = AuthService.instance;
  @override
  Future<void> send(String phone) => service.sendRegistrationOtp(phone);
  @override
  Future<Map<String, dynamic>?> verify(String phone, String code) =>
      service.verifyRegistrationOtp(phone: phone, token: code);
  @override
  Future<Map<String, dynamic>?> profile() => service.fetchAccessProfile();
  @override
  Future<void> complete(String name, String email) =>
      service.completePhoneRegistration(name: name, contactEmail: email);
  @override
  Future<AppRole> approvedRole() => service.requireApprovedAccess();
  @override
  Future<void> signOut() => service.signOut();
}

class PhoneRegistrationScreen extends StatefulWidget {
  const PhoneRegistrationScreen({super.key, this.gateway});
  final PhoneRegistrationGateway? gateway;
  @override
  State<PhoneRegistrationScreen> createState() =>
      _PhoneRegistrationScreenState();
}

class _PhoneRegistrationScreenState extends State<PhoneRegistrationScreen> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  String? _sentPhone;
  bool _busy = false, _consent = false, _verified = false, _complete = false;
  int _seconds = 0;
  Timer? _timer;
  late final _gateway = widget.gateway ?? _LiveRegistrationGateway();
  String t(String en, String hi) => enrollmentText(context, en, hi);
  @override
  void dispose() {
    for (final c in [_phone, _name, _email, _code]) {
      c.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  void _cooldown() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _seconds--);
      if (_seconds <= 0) timer.cancel();
    });
  }

  Future<void> _send() async {
    if (_busy || _seconds > 0) return;
    if (_name.text.trim().isEmpty ||
        !_consent ||
        !isValidContactEmail(_email.text)) {
      _message(
        t(
          'Enter your name, a valid optional email, and accept the consent.',
          'अपना नाम, सही वैकल्पिक ईमेल भरें और सहमति दें।',
        ),
      );
      return;
    }
    String phone;
    try {
      phone = normalizeIndiaPhoneNumber(_phone.text);
    } on FormatException {
      _message(
        t(
          'Enter a valid 10-digit Indian mobile number.',
          'सही 10 अंकों का भारतीय मोबाइल नंबर भरें।',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _gateway.send(phone);
      if (!mounted) return;
      setState(() {
        _sentPhone = phone;
        _code.clear();
      });
      _cooldown();
    } catch (_) {
      if (mounted) {
        _message(
          t(
            'Could not send the code. Please try again shortly.',
            'कोड नहीं भेजा जा सका। थोड़ी देर में फिर प्रयास करें।',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _sentPhone == null) return;
    if (!_verified && !RegExp(r'^[0-9]{6}$').hasMatch(_code.text.trim())) {
      _message(
        t('Enter the 6-digit SMS code.', 'SMS में आया 6 अंकों का कोड भरें।'),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final profile =
          _verified
              ? await _gateway.profile()
              : await _gateway.verify(_sentPhone!, _code.text.trim());
      if (!mounted) return;
      final status = profile?['status'];
      if (status == 'approved') {
        final role = await _gateway.approvedRole();
        if (mounted) context.go(routeForRole(role));
        return;
      }
      if (status != 'pending') {
        await _gateway.signOut();
        if (mounted) {
          _message(
            t(
              'This account was declined. Contact a Kaysons administrator.',
              'यह खाता अस्वीकृत है। Kaysons प्रशासक से संपर्क करें।',
            ),
          );
        }
        return;
      }
      setState(() => _verified = true);
      await _gateway.complete(_name.text, _email.text);
      if (mounted) setState(() => _complete = true);
    } catch (_) {
      if (mounted) {
        _message(
          t(
            'Could not complete registration. Check the code and try again; your account status is preserved.',
            'पंजीकरण पूरा नहीं हुआ। कोड जाँचें और फिर प्रयास करें; खाते की स्थिति सुरक्षित है।',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextField(
      controller: controller,
      enabled: !_busy && !_verified,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AuthWorkspace(
    title:
        _complete
            ? t('Registration submitted', 'पंजीकरण जमा हो गया')
            : t('Transporter registration', 'ट्रांसपोर्टर पंजीकरण'),
    subtitle:
        _complete
            ? t(
              'Your phone is verified. Your request is now with the Kaysons administrator.',
              'आपका फोन सत्यापित है। आपका अनुरोध Kaysons प्रशासक के पास है।',
            )
            : _sentPhone == null
            ? t(
              'Start with your phone and name. Business and bank details can be filled later.',
              'फोन और नाम से शुरुआत करें। व्यवसाय और बैंक की जानकारी बाद में भर सकते हैं।',
            )
            : t(
              'Enter the SMS code to finish your registration request.',
              'पंजीकरण अनुरोध पूरा करने के लिए SMS कोड भरें।',
            ),
    step:
        _complete
            ? t(
              'Phone verified · Awaiting approval',
              'फोन सत्यापित · स्वीकृति की प्रतीक्षा',
            )
            : _sentPhone == null
            ? t('Step 1 of 2 · Your details', 'चरण 1/2 · आपकी जानकारी')
            : t('Step 2 of 2 · Verify phone', 'चरण 2/2 · फोन सत्यापन'),
    children:
        _complete
            ? [
              GuidanceCard(
                title: t('What happens next?', 'आगे क्या होगा?'),
                message: t(
                  'An administrator will review and approve your account. Then you can sign in and use the app.',
                  'प्रशासक आपके खाते की समीक्षा और स्वीकृति देंगे। उसके बाद आप लॉगिन करके ऐप इस्तेमाल कर सकते हैं।',
                ),
                tone: WorkspaceTone.success,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => context.push('/account/profile'),
                icon: const Icon(Icons.person_outline),
                label: Text(
                  t(
                    'Add profile details (optional)',
                    'प्रोफ़ाइल जानकारी जोड़ें (वैकल्पिक)',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await _gateway.signOut();
                    if (context.mounted) context.go('/login');
                  },
                  child: Text(t('Back to sign in', 'लॉगिन पर वापस जाएँ')),
                ),
              ),
            ]
            : _sentPhone == null
            ? [
              _field(t('Full name', 'पूरा नाम'), _name),
              _field(
                t('Mobile number (+91)', 'मोबाइल नंबर (+91)'),
                _phone,
                type: TextInputType.phone,
              ),
              Text(
                t(
                  'Use a number you can receive SMS on.',
                  'वह नंबर दें जिस पर आपको SMS मिल सके।',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    t(
                      'Add contact email (optional)',
                      'संपर्क ईमेल जोड़ें (वैकल्पिक)',
                    ),
                  ),
                  children: [
                    _field(
                      t(
                        'Contact email (optional, not a login)',
                        'संपर्क ईमेल (वैकल्पिक, लॉगिन नहीं)',
                      ),
                      _email,
                      type: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _consent,
                onChanged:
                    _busy ? null : (v) => setState(() => _consent = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  t(
                    'I consent to Kaysons using these details for account registration and contacting me.',
                    'मैं खाते के पंजीकरण और संपर्क के लिए Kaysons को इन जानकारियों के उपयोग की सहमति देता/देती हूँ।',
                  ),
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label:
                      _busy
                          ? t('Sending…', 'भेज रहे हैं…')
                          : _seconds > 0
                          ? t(
                            'Send code in ${_seconds}s',
                            '$_seconds सेकंड में कोड भेजें',
                          )
                          : t('Send verification code', 'सत्यापन कोड भेजें'),
                  onPressed: _busy || _seconds > 0 ? null : _send,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                t(
                  'Phone verification sends a request for admin approval.',
                  'फोन सत्यापन के बाद प्रशासक की स्वीकृति के लिए अनुरोध भेजा जाएगा।',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]
            : [
              GuidanceCard(
                title: t(
                  'Code sent to $_sentPhone',
                  'कोड $_sentPhone पर भेजा गया',
                ),
                message: t(
                  'Open your SMS and enter the 6-digit code below.',
                  'अपना SMS खोलें और नीचे 6 अंकों का कोड भरें।',
                ),
                icon: Icons.sms_outlined,
              ),
              const SizedBox(height: 20),
              if (!_verified)
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    labelText: t('6-digit SMS code', '6 अंकों का SMS कोड'),
                    hintText: '123456',
                  ),
                ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label:
                      _busy
                          ? t('Please wait…', 'कृपया प्रतीक्षा करें…')
                          : t('Complete registration', 'पंजीकरण पूरा करें'),
                  onPressed: _busy ? null : _submit,
                ),
              ),
              if (!_verified) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy || _seconds > 0 ? null : _send,
                      child: Text(
                        _seconds > 0
                            ? t(
                              'Resend in ${_seconds}s',
                              '$_seconds सेकंड में फिर भेजें',
                            )
                            : t('Resend code', 'कोड फिर भेजें'),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _busy
                              ? null
                              : () => setState(() {
                                _sentPhone = null;
                                _code.clear();
                              }),
                      child: Text(t('Change phone number', 'फोन नंबर बदलें')),
                    ),
                  ],
                ),
              ],
            ],
  );
}
