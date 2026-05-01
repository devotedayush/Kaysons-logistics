import 'dart:typed_data';

class RegistrationDraft {
  RegistrationDraft._();
  static final instance = RegistrationDraft._();

  String? email;
  String? password;
  String? fullName;
  String? businessName;
  String? bankHolder;
  String? bankAccountNumber;
  String? mobile;
  String? landline;
  String? gst;
  String? businessNumber;
  String? rcNumber;
  String? insuranceNumber;
  Uint8List? chequeBytes;
  String? chequeFileName;
  String? chequeExtension;

  bool isRegistering = false;

  void reset() {
    email = null;
    password = null;
    fullName = null;
    businessName = null;
    bankHolder = null;
    bankAccountNumber = null;
    mobile = null;
    landline = null;
    gst = null;
    businessNumber = null;
    rcNumber = null;
    insuranceNumber = null;
    chequeBytes = null;
    chequeFileName = null;
    chequeExtension = null;
    isRegistering = false;
  }
}
