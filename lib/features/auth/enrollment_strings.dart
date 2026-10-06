import 'package:flutter/widgets.dart';

/// Small shared bilingual copy for phone enrollment and deferred completion.
String enrollmentText(BuildContext context, String english, String hindi) =>
    Localizations.localeOf(context).languageCode == 'hi' ? hindi : english;

bool isValidContactEmail(String value) =>
    value.trim().isEmpty ||
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

bool isValidBankDetails(String holder, String account, String ifsc) =>
    holder.trim().isNotEmpty &&
    RegExp(r'^[0-9]{9,18}$').hasMatch(account.trim()) &&
    RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc.trim().toUpperCase());
