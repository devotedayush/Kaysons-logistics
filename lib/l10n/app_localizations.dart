import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'हिंदी'**
  String get hindi;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @accountPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Account & privacy'**
  String get accountPrivacy;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @bids.
  ///
  /// In en, this message translates to:
  /// **'Bids'**
  String get bids;

  /// No description provided for @ledger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get ledger;

  /// No description provided for @fleet.
  ///
  /// In en, this message translates to:
  /// **'Fleet'**
  String get fleet;

  /// No description provided for @dispatch.
  ///
  /// In en, this message translates to:
  /// **'Dispatch'**
  String get dispatch;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @dateWindowDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String dateWindowDays(int days);

  /// No description provided for @dateWindowCustomDates.
  ///
  /// In en, this message translates to:
  /// **'Custom dates'**
  String get dateWindowCustomDates;

  /// No description provided for @dateWindowFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get dateWindowFrom;

  /// No description provided for @dateWindowTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get dateWindowTo;

  /// No description provided for @dateWindowUsePreset.
  ///
  /// In en, this message translates to:
  /// **'Use preset'**
  String get dateWindowUsePreset;

  /// No description provided for @deliveries.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get deliveries;

  /// No description provided for @adminConsole.
  ///
  /// In en, this message translates to:
  /// **'Admin console'**
  String get adminConsole;

  /// No description provided for @adminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review users, oversee freight activity, and keep the network healthy.'**
  String get adminSubtitle;

  /// No description provided for @accountant.
  ///
  /// In en, this message translates to:
  /// **'Accountant'**
  String get accountant;

  /// No description provided for @accountantSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage ledgers, reports, and Clawd analysis.'**
  String get accountantSubtitle;

  /// No description provided for @logisticsManager.
  ///
  /// In en, this message translates to:
  /// **'Logistics manager'**
  String get logisticsManager;

  /// No description provided for @logisticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Publish freights, monitor bids, and track deliveries.'**
  String get logisticsSubtitle;

  /// No description provided for @dispatchManager.
  ///
  /// In en, this message translates to:
  /// **'Dispatch manager'**
  String get dispatchManager;

  /// No description provided for @dispatchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track accepted deliveries and keep movement details current.'**
  String get dispatchSubtitle;

  /// No description provided for @transporter.
  ///
  /// In en, this message translates to:
  /// **'Transporter'**
  String get transporter;

  /// No description provided for @transporterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find freight, manage bids, and review fleet progress.'**
  String get transporterSubtitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Never miss a freight'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get regular updates on the latest freight'**
  String get welcomeSubtitle;

  /// No description provided for @loginEmailMobile.
  ///
  /// In en, this message translates to:
  /// **'Log in with email / mobile'**
  String get loginEmailMobile;

  /// No description provided for @registerWithUs.
  ///
  /// In en, this message translates to:
  /// **'Register with us'**
  String get registerWithUs;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInInstruction.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your registered email and password.'**
  String get signInInstruction;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @noAccountRegister.
  ///
  /// In en, this message translates to:
  /// **'No account? Register'**
  String get noAccountRegister;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed'**
  String get loginFailed;

  /// No description provided for @clawd.
  ///
  /// In en, this message translates to:
  /// **'Clawd'**
  String get clawd;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @stepOfFive.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 5'**
  String stepOfFive(int step);

  /// No description provided for @alreadyAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyAccount;

  /// No description provided for @goBack.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get goBack;

  /// No description provided for @registerEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address'**
  String get registerEmailTitle;

  /// No description provided for @registerEmailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your email. If you don\'t have a Kaysons account yet, we\'ll set one up.'**
  String get registerEmailSubtitle;

  /// No description provided for @yourEmail.
  ///
  /// In en, this message translates to:
  /// **'Your email'**
  String get yourEmail;

  /// No description provided for @createPassword.
  ///
  /// In en, this message translates to:
  /// **'Create password'**
  String get createPassword;

  /// No description provided for @passwordLength.
  ///
  /// In en, this message translates to:
  /// **'Must be at least 8 characters'**
  String get passwordLength;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmPassword;

  /// No description provided for @termsAgreement.
  ///
  /// In en, this message translates to:
  /// **'I agree to Kaysons Terms of Use and Privacy Policy and to receive emails from Kaysons.'**
  String get termsAgreement;

  /// No description provided for @registerNameTitle.
  ///
  /// In en, this message translates to:
  /// **'What is your name?'**
  String get registerNameTitle;

  /// No description provided for @registerProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This is used to build your profile on our platform.'**
  String get registerProfileSubtitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get companyName;

  /// No description provided for @registerBankTitle.
  ///
  /// In en, this message translates to:
  /// **'What is your bank name?'**
  String get registerBankTitle;

  /// No description provided for @accountHolderName.
  ///
  /// In en, this message translates to:
  /// **'Full name on bank account'**
  String get accountHolderName;

  /// No description provided for @bankAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Bank account number'**
  String get bankAccountNumber;

  /// No description provided for @photoUpload.
  ///
  /// In en, this message translates to:
  /// **'Photo upload'**
  String get photoUpload;

  /// No description provided for @imageReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read selected image'**
  String get imageReadFailed;

  /// No description provided for @registerContactTitle.
  ///
  /// In en, this message translates to:
  /// **'How do we contact you?'**
  String get registerContactTitle;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get mobileNumber;

  /// No description provided for @landlineNumber.
  ///
  /// In en, this message translates to:
  /// **'Company landline number'**
  String get landlineNumber;

  /// No description provided for @businessRegistrationNumber.
  ///
  /// In en, this message translates to:
  /// **'Business registration number'**
  String get businessRegistrationNumber;

  /// No description provided for @lorryRcNumber.
  ///
  /// In en, this message translates to:
  /// **'Lorry RC number'**
  String get lorryRcNumber;

  /// No description provided for @lorryInsuranceNumber.
  ///
  /// In en, this message translates to:
  /// **'Lorry insurance number'**
  String get lorryInsuranceNumber;

  /// No description provided for @gstinOptional.
  ///
  /// In en, this message translates to:
  /// **'GSTIN (optional)'**
  String get gstinOptional;

  /// No description provided for @registerRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart registration: email or password is missing'**
  String get registerRestart;

  /// No description provided for @invalidMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit Indian mobile number'**
  String get invalidMobile;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get registrationFailed;

  /// No description provided for @contactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Give us your number and business details. You will be signed in after submitting.'**
  String get contactSubtitle;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @submitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get submitting;

  /// No description provided for @uploadBlankCheque.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of a blank cheque'**
  String get uploadBlankCheque;

  /// No description provided for @selectedReplace.
  ///
  /// In en, this message translates to:
  /// **'Selected - tap to replace'**
  String get selectedReplace;

  /// No description provided for @privacyDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Request account deletion?'**
  String get privacyDeleteTitle;

  /// No description provided for @privacyDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'We will verify the request using your registered email. Your account and associated personal data will be deleted or de-identified, except records we must retain for legal, accounting, fraud-prevention or active contractual reasons.'**
  String get privacyDeleteWarning;

  /// No description provided for @privacyReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get privacyReason;

  /// No description provided for @privacyReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us anything we should know'**
  String get privacyReasonHint;

  /// No description provided for @privacyConfirm.
  ///
  /// In en, this message translates to:
  /// **'I understand this requests permanent deletion of my account and associated data.'**
  String get privacyConfirm;

  /// No description provided for @privacyKeepAccount.
  ///
  /// In en, this message translates to:
  /// **'Keep account'**
  String get privacyKeepAccount;

  /// No description provided for @privacySubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit request'**
  String get privacySubmit;

  /// No description provided for @privacyReceivedMessage.
  ///
  /// In en, this message translates to:
  /// **'Deletion request received. We will verify it by email.'**
  String get privacyReceivedMessage;

  /// No description provided for @privacyCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'Deletion request cancelled.'**
  String get privacyCancelledMessage;

  /// No description provided for @privacyYourPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your privacy'**
  String get privacyYourPrivacy;

  /// No description provided for @privacySummary.
  ///
  /// In en, this message translates to:
  /// **'See what Kaysons Logistics collects, why it is used, how long it is kept, and how to contact us.'**
  String get privacySummary;

  /// No description provided for @privacyReadPolicy.
  ///
  /// In en, this message translates to:
  /// **'Read privacy policy'**
  String get privacyReadPolicy;

  /// No description provided for @privacyWebRequest.
  ///
  /// In en, this message translates to:
  /// **'Request from the web'**
  String get privacyWebRequest;

  /// No description provided for @privacyWebSummary.
  ///
  /// In en, this message translates to:
  /// **'You can also request deletion after uninstalling the app. The public form does not require a login.'**
  String get privacyWebSummary;

  /// No description provided for @privacyOpenWeb.
  ///
  /// In en, this message translates to:
  /// **'Open deletion webpage'**
  String get privacyOpenWeb;

  /// No description provided for @privacyHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help?'**
  String get privacyHelp;

  /// No description provided for @privacyContact.
  ///
  /// In en, this message translates to:
  /// **'Contact {email} for privacy, access, correction or account questions.'**
  String privacyContact(String email);

  /// No description provided for @privacyEmailSupport.
  ///
  /// In en, this message translates to:
  /// **'Email support'**
  String get privacyEmailSupport;

  /// No description provided for @privacyReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Deletion request received'**
  String get privacyReceivedTitle;

  /// No description provided for @privacyStatusRequested.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}\nRequested: {date}'**
  String privacyStatusRequested(String status, String date);

  /// No description provided for @privacyThirtyDays.
  ///
  /// In en, this message translates to:
  /// **'We normally complete a verified request within 30 days. We may contact your registered email to confirm identity or explain records that must be retained.'**
  String get privacyThirtyDays;

  /// No description provided for @privacyCancelRequest.
  ///
  /// In en, this message translates to:
  /// **'Cancel deletion request'**
  String get privacyCancelRequest;

  /// No description provided for @privacyDeleteData.
  ///
  /// In en, this message translates to:
  /// **'Delete account and data'**
  String get privacyDeleteData;

  /// No description provided for @privacyDeleteSummary.
  ///
  /// In en, this message translates to:
  /// **'Submit a permanent deletion request for your Kaysons Logistics account and associated personal data. Verification protects your account from unauthorized requests.'**
  String get privacyDeleteSummary;

  /// No description provided for @privacyRequestDeletion.
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get privacyRequestDeletion;

  /// No description provided for @privacyVerifying.
  ///
  /// In en, this message translates to:
  /// **'Identity verification'**
  String get privacyVerifying;

  /// No description provided for @privacyApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved for deletion'**
  String get privacyApproved;

  /// No description provided for @privacyPending.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get privacyPending;

  /// No description provided for @privacyLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load deletion status'**
  String get privacyLoadError;

  /// No description provided for @privacyOpenError.
  ///
  /// In en, this message translates to:
  /// **'Could not open the webpage'**
  String get privacyOpenError;

  /// No description provided for @privacySubmitError.
  ///
  /// In en, this message translates to:
  /// **'Could not submit request'**
  String get privacySubmitError;

  /// No description provided for @privacyCancelError.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel request'**
  String get privacyCancelError;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @tpWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get tpWelcome;

  /// No description provided for @tpWelcomeName.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String tpWelcomeName(String name);

  /// No description provided for @tpLatestBids.
  ///
  /// In en, this message translates to:
  /// **'Latest bids'**
  String get tpLatestBids;

  /// No description provided for @tpNoOpenBidsSoon.
  ///
  /// In en, this message translates to:
  /// **'No open bids right now. Check back soon.'**
  String get tpNoOpenBidsSoon;

  /// No description provided for @tpWonBids.
  ///
  /// In en, this message translates to:
  /// **'Won bids'**
  String get tpWonBids;

  /// No description provided for @tpQuickOptions.
  ///
  /// In en, this message translates to:
  /// **'Quick options'**
  String get tpQuickOptions;

  /// No description provided for @tpVehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get tpVehicles;

  /// No description provided for @tpAddOrDelete.
  ///
  /// In en, this message translates to:
  /// **'Add or delete'**
  String get tpAddOrDelete;

  /// No description provided for @tpBidHistory.
  ///
  /// In en, this message translates to:
  /// **'Bid history'**
  String get tpBidHistory;

  /// No description provided for @tpWonAndActive.
  ///
  /// In en, this message translates to:
  /// **'Won and active'**
  String get tpWonAndActive;

  /// No description provided for @tpDrivers.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get tpDrivers;

  /// No description provided for @tpPerVehicle.
  ///
  /// In en, this message translates to:
  /// **'Per vehicle'**
  String get tpPerVehicle;

  /// No description provided for @tpWonBidsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Won bids will appear here after a freight is awarded.'**
  String get tpWonBidsEmpty;

  /// No description provided for @tpAwaitingVehicle.
  ///
  /// In en, this message translates to:
  /// **'Awaiting vehicle'**
  String get tpAwaitingVehicle;

  /// No description provided for @tpClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get tpClosed;

  /// No description provided for @tpTimeHoursLeft.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr {minutes} min left'**
  String tpTimeHoursLeft(int hours, int minutes);

  /// No description provided for @tpTimeMinutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min left'**
  String tpTimeMinutesLeft(int minutes);

  /// No description provided for @tpCasesWeight.
  ///
  /// In en, this message translates to:
  /// **'{cases} Cases · {weight} MT'**
  String tpCasesWeight(String cases, String weight);

  /// No description provided for @tpOpenBids.
  ///
  /// In en, this message translates to:
  /// **'Open bids'**
  String get tpOpenBids;

  /// No description provided for @tpOpenBidsCount.
  ///
  /// In en, this message translates to:
  /// **'Open bids ({count})'**
  String tpOpenBidsCount(int count);

  /// No description provided for @tpNoOpenBids.
  ///
  /// In en, this message translates to:
  /// **'No open bids right now.'**
  String get tpNoOpenBids;

  /// No description provided for @tpBidHistoryCount.
  ///
  /// In en, this message translates to:
  /// **'Bid history ({count})'**
  String tpBidHistoryCount(int count);

  /// No description provided for @tpStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Status: Completed'**
  String get tpStatusCompleted;

  /// No description provided for @tpStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Status: Open'**
  String get tpStatusOpen;

  /// No description provided for @tpStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Status: Expired'**
  String get tpStatusExpired;

  /// No description provided for @tpStatusAwarded.
  ///
  /// In en, this message translates to:
  /// **'Status: Awarded'**
  String get tpStatusAwarded;

  /// No description provided for @tpStatusDispatched.
  ///
  /// In en, this message translates to:
  /// **'Status: Dispatched'**
  String get tpStatusDispatched;

  /// No description provided for @tpStatusLocked.
  ///
  /// In en, this message translates to:
  /// **'Status: Locked'**
  String get tpStatusLocked;

  /// No description provided for @tpStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Status: Closed'**
  String get tpStatusClosed;

  /// No description provided for @tpMyFleet.
  ///
  /// In en, this message translates to:
  /// **'My fleet'**
  String get tpMyFleet;

  /// No description provided for @tpManageVehicles.
  ///
  /// In en, this message translates to:
  /// **'Manage vehicles'**
  String get tpManageVehicles;

  /// No description provided for @tpManageFleetPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add, edit, or delete vehicle and driver details'**
  String get tpManageFleetPrompt;

  /// No description provided for @tpNoWonBids.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t won any bids yet. Slide over to Bids.'**
  String get tpNoWonBids;

  /// No description provided for @opsNewRequirement.
  ///
  /// In en, this message translates to:
  /// **'New requirement'**
  String get opsNewRequirement;

  /// No description provided for @opsEditRequirement.
  ///
  /// In en, this message translates to:
  /// **'Edit requirement'**
  String get opsEditRequirement;

  /// No description provided for @opsDeliveryTracking.
  ///
  /// In en, this message translates to:
  /// **'Delivery tracking'**
  String get opsDeliveryTracking;

  /// No description provided for @opsLockFreight.
  ///
  /// In en, this message translates to:
  /// **'Lock freight'**
  String get opsLockFreight;

  /// No description provided for @opsTransporters.
  ///
  /// In en, this message translates to:
  /// **'Transporters'**
  String get opsTransporters;

  /// No description provided for @opsVehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get opsVehicles;

  /// No description provided for @opsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get opsRefresh;

  /// No description provided for @opsPublishBid.
  ///
  /// In en, this message translates to:
  /// **'Publish bid'**
  String get opsPublishBid;

  /// No description provided for @opsActiveBids.
  ///
  /// In en, this message translates to:
  /// **'Active bids'**
  String get opsActiveBids;

  /// No description provided for @opsInTransit.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get opsInTransit;

  /// No description provided for @opsLockedDone.
  ///
  /// In en, this message translates to:
  /// **'Locked / done'**
  String get opsLockedDone;

  /// No description provided for @opsVehicleChecks.
  ///
  /// In en, this message translates to:
  /// **'Vehicle checks'**
  String get opsVehicleChecks;

  /// No description provided for @opsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get opsNotifications;

  /// No description provided for @opsFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get opsFrom;

  /// No description provided for @opsStopsOptional.
  ///
  /// In en, this message translates to:
  /// **'Stops in between (optional)'**
  String get opsStopsOptional;

  /// No description provided for @opsStopCity.
  ///
  /// In en, this message translates to:
  /// **'Stop city'**
  String get opsStopCity;

  /// No description provided for @opsStopCases.
  ///
  /// In en, this message translates to:
  /// **'Stop cases'**
  String get opsStopCases;

  /// No description provided for @opsStopMetricTon.
  ///
  /// In en, this message translates to:
  /// **'Stop metric ton'**
  String get opsStopMetricTon;

  /// No description provided for @opsFinalDestination.
  ///
  /// In en, this message translates to:
  /// **'Final destination'**
  String get opsFinalDestination;

  /// No description provided for @opsDestinationCity.
  ///
  /// In en, this message translates to:
  /// **'Destination city'**
  String get opsDestinationCity;

  /// No description provided for @opsDestinationCases.
  ///
  /// In en, this message translates to:
  /// **'Destination cases'**
  String get opsDestinationCases;

  /// No description provided for @opsDestinationMetricTon.
  ///
  /// In en, this message translates to:
  /// **'Destination metric ton'**
  String get opsDestinationMetricTon;

  /// No description provided for @opsBaseFreight.
  ///
  /// In en, this message translates to:
  /// **'Base Freight'**
  String get opsBaseFreight;

  /// No description provided for @opsOpenForBidding.
  ///
  /// In en, this message translates to:
  /// **'Open for bidding'**
  String get opsOpenForBidding;

  /// No description provided for @opsCompeteUntilClose.
  ///
  /// In en, this message translates to:
  /// **'Transporters compete on price until the close time.'**
  String get opsCompeteUntilClose;

  /// No description provided for @opsAssignDirectlyHint.
  ///
  /// In en, this message translates to:
  /// **'Assign directly to one transporter, skip the bidding window.'**
  String get opsAssignDirectlyHint;

  /// No description provided for @opsOpensAt.
  ///
  /// In en, this message translates to:
  /// **'Opens at'**
  String get opsOpensAt;

  /// No description provided for @opsClosesAt.
  ///
  /// In en, this message translates to:
  /// **'Closes at'**
  String get opsClosesAt;

  /// No description provided for @opsInternalCallingBid.
  ///
  /// In en, this message translates to:
  /// **'Reference price (optional)'**
  String get opsInternalCallingBid;

  /// No description provided for @opsReferencePriceHint.
  ///
  /// In en, this message translates to:
  /// **'Used for estimates. Do not enter a confidential target price here.'**
  String get opsReferencePriceHint;

  /// No description provided for @opsAnonymousInternalBid.
  ///
  /// In en, this message translates to:
  /// **'Anonymous internal bid'**
  String get opsAnonymousInternalBid;

  /// No description provided for @opsHideCallingBid.
  ///
  /// In en, this message translates to:
  /// **'Hide your calling bid from transporters'**
  String get opsHideCallingBid;

  /// No description provided for @opsTransporterAccess.
  ///
  /// In en, this message translates to:
  /// **'Transporter access'**
  String get opsTransporterAccess;

  /// No description provided for @opsWhoCanBid.
  ///
  /// In en, this message translates to:
  /// **'Who can bid?'**
  String get opsWhoCanBid;

  /// No description provided for @opsAllApprovedTransporters.
  ///
  /// In en, this message translates to:
  /// **'All approved transporters'**
  String get opsAllApprovedTransporters;

  /// No description provided for @opsAllApprovedHint.
  ///
  /// In en, this message translates to:
  /// **'Everyone approved can see this bid, except anyone you exclude.'**
  String get opsAllApprovedHint;

  /// No description provided for @opsOnlySelectedTransporters.
  ///
  /// In en, this message translates to:
  /// **'Only selected transporters'**
  String get opsOnlySelectedTransporters;

  /// No description provided for @opsOnlySelectedHint.
  ///
  /// In en, this message translates to:
  /// **'Only the transporters you choose can see and bid.'**
  String get opsOnlySelectedHint;

  /// No description provided for @opsChooseTransporters.
  ///
  /// In en, this message translates to:
  /// **'Choose transporters'**
  String get opsChooseTransporters;

  /// No description provided for @opsExcludeTransporters.
  ///
  /// In en, this message translates to:
  /// **'Exclude transporters (optional)'**
  String get opsExcludeTransporters;

  /// No description provided for @opsExcludeHint.
  ///
  /// In en, this message translates to:
  /// **'Checked transporters cannot see this bid.'**
  String get opsExcludeHint;

  /// No description provided for @opsSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'Selected: {count}'**
  String opsSelectedCount(int count);

  /// No description provided for @opsExcludedCount.
  ///
  /// In en, this message translates to:
  /// **'Excluded: {count}'**
  String opsExcludedCount(int count);

  /// No description provided for @opsChooseAtLeastOneTransporter.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one transporter for a selected-only bid.'**
  String get opsChooseAtLeastOneTransporter;

  /// No description provided for @opsReviewAndPublish.
  ///
  /// In en, this message translates to:
  /// **'Review & publish'**
  String get opsReviewAndPublish;

  /// No description provided for @opsVisibleTo.
  ///
  /// In en, this message translates to:
  /// **'Visible to'**
  String get opsVisibleTo;

  /// No description provided for @opsBidCloses.
  ///
  /// In en, this message translates to:
  /// **'Bidding closes'**
  String get opsBidCloses;

  /// No description provided for @opsPrefer.
  ///
  /// In en, this message translates to:
  /// **'Prefer'**
  String get opsPrefer;

  /// No description provided for @opsBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get opsBlock;

  /// No description provided for @opsAssignToTransporter.
  ///
  /// In en, this message translates to:
  /// **'Assign to transporter'**
  String get opsAssignToTransporter;

  /// No description provided for @opsAssignDispatch.
  ///
  /// In en, this message translates to:
  /// **'Assign & dispatch'**
  String get opsAssignDispatch;

  /// No description provided for @opsNoApprovedTransporters.
  ///
  /// In en, this message translates to:
  /// **'No approved transporters yet.'**
  String get opsNoApprovedTransporters;

  /// No description provided for @opsSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get opsSaveChanges;

  /// No description provided for @opsSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get opsSaved;

  /// No description provided for @opsTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get opsTrack;

  /// No description provided for @opsLockInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get opsLockInvoices;

  /// No description provided for @opsEditStopsWindow.
  ///
  /// In en, this message translates to:
  /// **'Edit stops / extend window'**
  String get opsEditStopsWindow;

  /// No description provided for @opsAddAnotherInvoice.
  ///
  /// In en, this message translates to:
  /// **'Add another invoice'**
  String get opsAddAnotherInvoice;

  /// No description provided for @opsAddAnotherGrBilty.
  ///
  /// In en, this message translates to:
  /// **'Add another GR / Bilty'**
  String get opsAddAnotherGrBilty;

  /// No description provided for @opsAddAnotherEwayBill.
  ///
  /// In en, this message translates to:
  /// **'Add another e-way bill'**
  String get opsAddAnotherEwayBill;

  /// No description provided for @opsRemoveDocument.
  ///
  /// In en, this message translates to:
  /// **'Remove document number'**
  String get opsRemoveDocument;

  /// No description provided for @tpGoodsInvoiceChallanNumbers.
  ///
  /// In en, this message translates to:
  /// **'Goods invoice / challan numbers'**
  String get tpGoodsInvoiceChallanNumbers;

  /// No description provided for @tpMultiStopDocumentsHint.
  ///
  /// In en, this message translates to:
  /// **'Add invoice, GR/Bilty and e-way bill references under each delivery destination below.'**
  String get tpMultiStopDocumentsHint;

  /// No description provided for @tpAddReference.
  ///
  /// In en, this message translates to:
  /// **'Add {label}'**
  String tpAddReference(String label);

  /// No description provided for @tpRemoveReference.
  ///
  /// In en, this message translates to:
  /// **'Remove {label}'**
  String tpRemoveReference(String label);

  /// No description provided for @opsAddCharge.
  ///
  /// In en, this message translates to:
  /// **'Add charge'**
  String get opsAddCharge;

  /// No description provided for @opsRemoveInvoice.
  ///
  /// In en, this message translates to:
  /// **'Remove invoice'**
  String get opsRemoveInvoice;

  /// No description provided for @opsRemoveCharge.
  ///
  /// In en, this message translates to:
  /// **'Remove charge'**
  String get opsRemoveCharge;

  /// No description provided for @opsWholeDispatch.
  ///
  /// In en, this message translates to:
  /// **'Whole dispatch'**
  String get opsWholeDispatch;

  /// No description provided for @opsConfirmArrived.
  ///
  /// In en, this message translates to:
  /// **'Confirm arrived'**
  String get opsConfirmArrived;

  /// No description provided for @opsWrongDetails.
  ///
  /// In en, this message translates to:
  /// **'Wrong details'**
  String get opsWrongDetails;

  /// No description provided for @opsOptionalNote.
  ///
  /// In en, this message translates to:
  /// **'Optional note'**
  String get opsOptionalNote;

  /// No description provided for @opsWhatIsWrong.
  ///
  /// In en, this message translates to:
  /// **'What is wrong?'**
  String get opsWhatIsWrong;

  /// No description provided for @opsVehicleConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Vehicle confirmed'**
  String get opsVehicleConfirmed;

  /// No description provided for @opsIssueRaised.
  ///
  /// In en, this message translates to:
  /// **'Issue raised'**
  String get opsIssueRaised;

  /// No description provided for @opsLocationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Location updated'**
  String get opsLocationUpdated;

  /// No description provided for @opsDeliveryCheckSaved.
  ///
  /// In en, this message translates to:
  /// **'Delivery check saved'**
  String get opsDeliveryCheckSaved;

  /// No description provided for @opsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get opsCancel;

  /// No description provided for @opsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get opsSave;

  /// No description provided for @opsPhotoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded'**
  String get opsPhotoUploaded;

  /// No description provided for @opsProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get opsProfileUpdated;

  /// No description provided for @opsInvoiceLocked.
  ///
  /// In en, this message translates to:
  /// **'Invoice details saved.'**
  String get opsInvoiceLocked;

  /// No description provided for @opsFromToRequired.
  ///
  /// In en, this message translates to:
  /// **'From and To are required'**
  String get opsFromToRequired;

  /// No description provided for @opsPickTransporter.
  ///
  /// In en, this message translates to:
  /// **'Pick a transporter to assign the freight to'**
  String get opsPickTransporter;

  /// No description provided for @opsAmountsValid.
  ///
  /// In en, this message translates to:
  /// **'Freight amounts must be valid numbers'**
  String get opsAmountsValid;

  /// No description provided for @opsAmountsPositive.
  ///
  /// In en, this message translates to:
  /// **'Freight amounts must be greater than zero'**
  String get opsAmountsPositive;

  /// No description provided for @opsCloseAfterOpen.
  ///
  /// In en, this message translates to:
  /// **'Close time must be after open time'**
  String get opsCloseAfterOpen;

  /// No description provided for @opsInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number must be a valid Indian mobile number'**
  String get opsInvalidPhone;

  /// No description provided for @opsCouldNotReadImage.
  ///
  /// In en, this message translates to:
  /// **'Could not read selected image'**
  String get opsCouldNotReadImage;

  /// No description provided for @tpCouldNotLoadDrivers.
  ///
  /// In en, this message translates to:
  /// **'Could not load drivers: {error}'**
  String tpCouldNotLoadDrivers(String error);

  /// No description provided for @tpDeleteDriverQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete driver?'**
  String get tpDeleteDriverQuestion;

  /// No description provided for @tpThisDriver.
  ///
  /// In en, this message translates to:
  /// **'This driver'**
  String get tpThisDriver;

  /// No description provided for @tpDriverWillBeRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed.'**
  String tpDriverWillBeRemoved(String name);

  /// No description provided for @tpCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get tpCancel;

  /// No description provided for @tpDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tpDelete;

  /// No description provided for @tpAddDriver.
  ///
  /// In en, this message translates to:
  /// **'Add driver'**
  String get tpAddDriver;

  /// No description provided for @tpDriverNameMissing.
  ///
  /// In en, this message translates to:
  /// **'Driver name missing'**
  String get tpDriverNameMissing;

  /// No description provided for @tpPhoneLicence.
  ///
  /// In en, this message translates to:
  /// **'{phone} · Licence {licence}'**
  String tpPhoneLicence(String phone, String licence);

  /// No description provided for @tpEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get tpEdit;

  /// No description provided for @tpNoDrivers.
  ///
  /// In en, this message translates to:
  /// **'No drivers added yet'**
  String get tpNoDrivers;

  /// No description provided for @tpAddDriversHint.
  ///
  /// In en, this message translates to:
  /// **'Add drivers separately, then choose one during dispatch.'**
  String get tpAddDriversHint;

  /// No description provided for @tpEnterDriverName.
  ///
  /// In en, this message translates to:
  /// **'Enter driver name'**
  String get tpEnterDriverName;

  /// No description provided for @tpEnterValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Indian mobile number'**
  String get tpEnterValidPhone;

  /// No description provided for @tpSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String tpSaveFailed(String error);

  /// No description provided for @tpEditDriver.
  ///
  /// In en, this message translates to:
  /// **'Edit driver'**
  String get tpEditDriver;

  /// No description provided for @tpDriverName.
  ///
  /// In en, this message translates to:
  /// **'Driver name'**
  String get tpDriverName;

  /// No description provided for @tpDriverPhone.
  ///
  /// In en, this message translates to:
  /// **'Driver phone'**
  String get tpDriverPhone;

  /// No description provided for @tpLicenceNumber.
  ///
  /// In en, this message translates to:
  /// **'Licence number'**
  String get tpLicenceNumber;

  /// No description provided for @tpSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get tpSaving;

  /// No description provided for @tpSaveDriver.
  ///
  /// In en, this message translates to:
  /// **'Save driver'**
  String get tpSaveDriver;

  /// No description provided for @tpCouldNotLoadVehicles.
  ///
  /// In en, this message translates to:
  /// **'Could not load vehicles: {error}'**
  String tpCouldNotLoadVehicles(String error);

  /// No description provided for @tpThisVehicle.
  ///
  /// In en, this message translates to:
  /// **'this vehicle'**
  String get tpThisVehicle;

  /// No description provided for @tpDeleteVehicleQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete vehicle?'**
  String get tpDeleteVehicleQuestion;

  /// No description provided for @tpVehicleWillBeRemoved.
  ///
  /// In en, this message translates to:
  /// **'{vehicle} will be removed from your fleet records.'**
  String tpVehicleWillBeRemoved(String vehicle);

  /// No description provided for @tpVehicleDeleted.
  ///
  /// In en, this message translates to:
  /// **'Vehicle deleted'**
  String get tpVehicleDeleted;

  /// No description provided for @tpDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String tpDeleteFailed(String error);

  /// No description provided for @tpAddVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle'**
  String get tpAddVehicle;

  /// No description provided for @tpVehicleNumberMissing.
  ///
  /// In en, this message translates to:
  /// **'Vehicle number missing'**
  String get tpVehicleNumberMissing;

  /// No description provided for @tpTruck.
  ///
  /// In en, this message translates to:
  /// **'Truck'**
  String get tpTruck;

  /// No description provided for @tpRc.
  ///
  /// In en, this message translates to:
  /// **'RC'**
  String get tpRc;

  /// No description provided for @tpInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get tpInsurance;

  /// No description provided for @tpStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get tpStatus;

  /// No description provided for @tpActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tpActive;

  /// No description provided for @tpNoVehicles.
  ///
  /// In en, this message translates to:
  /// **'No vehicles added yet'**
  String get tpNoVehicles;

  /// No description provided for @tpAddVehiclesHint.
  ///
  /// In en, this message translates to:
  /// **'Add each truck with RC, insurance, and capacity details.'**
  String get tpAddVehiclesHint;

  /// No description provided for @tpEnterVehicleNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a vehicle number'**
  String get tpEnterVehicleNumber;

  /// No description provided for @tpEditVehicle.
  ///
  /// In en, this message translates to:
  /// **'Edit vehicle'**
  String get tpEditVehicle;

  /// No description provided for @tpVehicleNumber.
  ///
  /// In en, this message translates to:
  /// **'Vehicle number'**
  String get tpVehicleNumber;

  /// No description provided for @tpVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get tpVehicleType;

  /// No description provided for @tpTruckTrailer.
  ///
  /// In en, this message translates to:
  /// **'Truck / Trailer'**
  String get tpTruckTrailer;

  /// No description provided for @tpCapacityCases.
  ///
  /// In en, this message translates to:
  /// **'Capacity Cases'**
  String get tpCapacityCases;

  /// No description provided for @tpMetricMt.
  ///
  /// In en, this message translates to:
  /// **'Metric MT'**
  String get tpMetricMt;

  /// No description provided for @tpRcNumber.
  ///
  /// In en, this message translates to:
  /// **'RC number'**
  String get tpRcNumber;

  /// No description provided for @tpInsuranceNumber.
  ///
  /// In en, this message translates to:
  /// **'Insurance number'**
  String get tpInsuranceNumber;

  /// No description provided for @tpSaveVehicle.
  ///
  /// In en, this message translates to:
  /// **'Save vehicle'**
  String get tpSaveVehicle;

  /// No description provided for @tpCases.
  ///
  /// In en, this message translates to:
  /// **'{cases} Cases'**
  String tpCases(String cases);

  /// No description provided for @opsNoActiveBids.
  ///
  /// In en, this message translates to:
  /// **'No active bids right now.'**
  String get opsNoActiveBids;

  /// No description provided for @opsAllBids.
  ///
  /// In en, this message translates to:
  /// **'All bids'**
  String get opsAllBids;

  /// No description provided for @opsNoBidsDate.
  ///
  /// In en, this message translates to:
  /// **'No bids found for this date window.'**
  String get opsNoBidsDate;

  /// No description provided for @opsFleetDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Fleet - deliveries'**
  String get opsFleetDeliveries;

  /// No description provided for @opsNoAwardedFreights.
  ///
  /// In en, this message translates to:
  /// **'No awarded freights yet.'**
  String get opsNoAwardedFreights;

  /// No description provided for @opsNoDataDate.
  ///
  /// In en, this message translates to:
  /// **'No data in this date window.'**
  String get opsNoDataDate;

  /// No description provided for @opsManagerProfile.
  ///
  /// In en, this message translates to:
  /// **'Manager profile'**
  String get opsManagerProfile;

  /// No description provided for @opsName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get opsName;

  /// No description provided for @opsPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get opsPhoneNumber;

  /// No description provided for @opsAreaCovered.
  ///
  /// In en, this message translates to:
  /// **'Area covered'**
  String get opsAreaCovered;

  /// No description provided for @opsNoTransporters.
  ///
  /// In en, this message translates to:
  /// **'No transporters found.'**
  String get opsNoTransporters;

  /// No description provided for @opsNoVehicles.
  ///
  /// In en, this message translates to:
  /// **'No vehicles found.'**
  String get opsNoVehicles;

  /// No description provided for @opsDeliveryStages.
  ///
  /// In en, this message translates to:
  /// **'Delivery stages'**
  String get opsDeliveryStages;

  /// No description provided for @opsVehicleVerification.
  ///
  /// In en, this message translates to:
  /// **'Vehicle verification'**
  String get opsVehicleVerification;

  /// No description provided for @opsWaitingVehicle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for transporter to submit vehicle and driver details.'**
  String get opsWaitingVehicle;

  /// No description provided for @opsNotSubmittedYet.
  ///
  /// In en, this message translates to:
  /// **'Not submitted yet'**
  String get opsNotSubmittedYet;

  /// No description provided for @opsNoSubContractors.
  ///
  /// In en, this message translates to:
  /// **'No sub-contractors recorded'**
  String get opsNoSubContractors;

  /// No description provided for @opsSubContractorOptional.
  ///
  /// In en, this message translates to:
  /// **'Sub-contractor, if used'**
  String get opsSubContractorOptional;

  /// No description provided for @opsLorryNumber.
  ///
  /// In en, this message translates to:
  /// **'Lorry number'**
  String get opsLorryNumber;

  /// No description provided for @opsDriverName.
  ///
  /// In en, this message translates to:
  /// **'Driver name'**
  String get opsDriverName;

  /// No description provided for @opsDriverPhone.
  ///
  /// In en, this message translates to:
  /// **'Driver phone'**
  String get opsDriverPhone;

  /// No description provided for @opsInvoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice number'**
  String get opsInvoiceNumber;

  /// No description provided for @opsGrBiltyNumber.
  ///
  /// In en, this message translates to:
  /// **'GR / Bilty number'**
  String get opsGrBiltyNumber;

  /// No description provided for @opsEwayBillNumber.
  ///
  /// In en, this message translates to:
  /// **'E-way bill number'**
  String get opsEwayBillNumber;

  /// No description provided for @opsCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get opsCurrentLocation;

  /// No description provided for @opsReceiverName.
  ///
  /// In en, this message translates to:
  /// **'Receiver name'**
  String get opsReceiverName;

  /// No description provided for @opsReceiverPhone.
  ///
  /// In en, this message translates to:
  /// **'Receiver phone'**
  String get opsReceiverPhone;

  /// No description provided for @opsGrNumber.
  ///
  /// In en, this message translates to:
  /// **'GR number'**
  String get opsGrNumber;

  /// No description provided for @opsAdditionalBillReason.
  ///
  /// In en, this message translates to:
  /// **'Additional bill reason'**
  String get opsAdditionalBillReason;

  /// No description provided for @opsExtendWindow.
  ///
  /// In en, this message translates to:
  /// **'Extend bidding window'**
  String get opsExtendWindow;

  /// No description provided for @opsStopsInBetween.
  ///
  /// In en, this message translates to:
  /// **'Stops in between'**
  String get opsStopsInBetween;

  /// No description provided for @opsAccessLegend.
  ///
  /// In en, this message translates to:
  /// **'Green = preferred; red = blocked; unselected = open'**
  String get opsAccessLegend;

  /// No description provided for @opsDispatchTeam.
  ///
  /// In en, this message translates to:
  /// **'Dispatch team'**
  String get opsDispatchTeam;

  /// No description provided for @opsAssignRegisteredUsers.
  ///
  /// In en, this message translates to:
  /// **'Assign registered users to track your accepted deliveries.'**
  String get opsAssignRegisteredUsers;

  /// No description provided for @opsInvoicesGrLinking.
  ///
  /// In en, this message translates to:
  /// **'Invoice records'**
  String get opsInvoicesGrLinking;

  /// No description provided for @opsAddEveryInvoice.
  ///
  /// In en, this message translates to:
  /// **'Record the invoice, GR/Bilty and e-way bill details for this trip. This does not create a PDF or send a bill.'**
  String get opsAddEveryInvoice;

  /// No description provided for @opsCompletedInvoiceNote.
  ///
  /// In en, this message translates to:
  /// **'Delivery is complete. You can still add missing invoice details; the delivery will stay complete.'**
  String get opsCompletedInvoiceNote;

  /// No description provided for @opsSavedInvoiceDetails.
  ///
  /// In en, this message translates to:
  /// **'Saved invoice details'**
  String get opsSavedInvoiceDetails;

  /// No description provided for @opsInvoiceReadOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'These are the recorded details for this trip. Ask an office administrator to correct a saved invoice.'**
  String get opsInvoiceReadOnlyNote;

  /// No description provided for @opsInvoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Invoice entry is unavailable for this bid. Ask an office administrator to review it.'**
  String get opsInvoiceUnavailable;

  /// No description provided for @opsCharges.
  ///
  /// In en, this message translates to:
  /// **'Charges'**
  String get opsCharges;

  /// No description provided for @opsChargeScopeHint.
  ///
  /// In en, this message translates to:
  /// **'Choose whether each charge applies to the whole dispatch or one invoice.'**
  String get opsChargeScopeHint;

  /// No description provided for @opsBiddersLive.
  ///
  /// In en, this message translates to:
  /// **'Bidders (live)'**
  String get opsBiddersLive;

  /// No description provided for @opsNoBidsReceived.
  ///
  /// In en, this message translates to:
  /// **'No bids received yet.'**
  String get opsNoBidsReceived;

  /// No description provided for @opsWinnerConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Winner confirmed. Transporter will now dispatch.'**
  String get opsWinnerConfirmed;

  /// No description provided for @opsTransporterFillDetails.
  ///
  /// In en, this message translates to:
  /// **'The transporter will fill in vehicle, driver and pickup details themselves from their Fleet tab.'**
  String get opsTransporterFillDetails;

  /// No description provided for @opsTotalRequirement.
  ///
  /// In en, this message translates to:
  /// **'Total requirement'**
  String get opsTotalRequirement;

  /// No description provided for @opsAgreedFreightPositive.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive agreed freight for direct assignment'**
  String get opsAgreedFreightPositive;

  /// No description provided for @opsVehicleListUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Vehicle list is unavailable until manager read access is applied.'**
  String get opsVehicleListUnavailable;

  /// No description provided for @adminAllBids.
  ///
  /// In en, this message translates to:
  /// **'All bids'**
  String get adminAllBids;

  /// No description provided for @adminNoBids.
  ///
  /// In en, this message translates to:
  /// **'No bids found for this date window.'**
  String get adminNoBids;

  /// No description provided for @adminCases.
  ///
  /// In en, this message translates to:
  /// **'Cases'**
  String get adminCases;

  /// No description provided for @adminStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminStatus;

  /// No description provided for @adminCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get adminCompleted;

  /// No description provided for @adminOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get adminOpen;

  /// No description provided for @adminClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get adminClosed;

  /// No description provided for @adminNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get adminNotifications;

  /// No description provided for @adminAlertNotifications.
  ///
  /// In en, this message translates to:
  /// **'Alert notifications'**
  String get adminAlertNotifications;

  /// No description provided for @adminNotificationsHelp.
  ///
  /// In en, this message translates to:
  /// **'Review POD, document mismatch, vehicle, and registration alerts from one place.'**
  String get adminNotificationsHelp;

  /// No description provided for @adminResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get adminResolved;

  /// No description provided for @adminAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminAll;

  /// No description provided for @adminNoNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications here right now.'**
  String get adminNoNotifications;

  /// No description provided for @adminProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get adminProfileUpdated;

  /// No description provided for @adminUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get adminUpdateFailed;

  /// No description provided for @adminAccountantProfile.
  ///
  /// In en, this message translates to:
  /// **'Accountant profile'**
  String get adminAccountantProfile;

  /// No description provided for @adminAdminProfile.
  ///
  /// In en, this message translates to:
  /// **'Admin profile'**
  String get adminAdminProfile;

  /// No description provided for @adminAccountantProfileHelp.
  ///
  /// In en, this message translates to:
  /// **'This profile is used across the accounting workspace.'**
  String get adminAccountantProfileHelp;

  /// No description provided for @adminProfileHelp.
  ///
  /// In en, this message translates to:
  /// **'This profile is used across your logistics workspace.'**
  String get adminProfileHelp;

  /// No description provided for @adminLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get adminLogout;

  /// No description provided for @adminAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account details'**
  String get adminAccountDetails;

  /// No description provided for @adminFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get adminFullName;

  /// No description provided for @adminNameHint.
  ///
  /// In en, this message translates to:
  /// **'Admin name'**
  String get adminNameHint;

  /// No description provided for @adminSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get adminSaving;

  /// No description provided for @adminSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get adminSaveProfile;

  /// No description provided for @adminUserManagement.
  ///
  /// In en, this message translates to:
  /// **'User management'**
  String get adminUserManagement;

  /// No description provided for @adminPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get adminPending;

  /// No description provided for @adminNoUsers.
  ///
  /// In en, this message translates to:
  /// **'No users'**
  String get adminNoUsers;

  /// No description provided for @adminUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get adminUnnamed;

  /// No description provided for @adminNoManager.
  ///
  /// In en, this message translates to:
  /// **'No manager'**
  String get adminNoManager;

  /// No description provided for @adminRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get adminRole;

  /// No description provided for @adminRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminRoleAdmin;

  /// No description provided for @adminError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get adminError;

  /// No description provided for @adminReportsTo.
  ///
  /// In en, this message translates to:
  /// **'Reports to'**
  String get adminReportsTo;

  /// No description provided for @adminAccessHelp.
  ///
  /// In en, this message translates to:
  /// **'Access follows the assigned role and approval status.'**
  String get adminAccessHelp;

  /// No description provided for @adminApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminApprove;

  /// No description provided for @adminReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminReject;

  /// No description provided for @adminRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get adminRemove;

  /// No description provided for @adminManagerFirst.
  ///
  /// In en, this message translates to:
  /// **'Create or approve a logistics manager first.'**
  String get adminManagerFirst;

  /// No description provided for @adminRoleUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Role update failed'**
  String get adminRoleUpdateFailed;

  /// No description provided for @adminManagerUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Manager update failed'**
  String get adminManagerUpdateFailed;

  /// No description provided for @adminDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get adminDeleteFailed;

  /// No description provided for @adminRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get adminRefresh;

  /// No description provided for @adminTotalFreight.
  ///
  /// In en, this message translates to:
  /// **'Total freight'**
  String get adminTotalFreight;

  /// No description provided for @adminMetricMt.
  ///
  /// In en, this message translates to:
  /// **'Metric MT'**
  String get adminMetricMt;

  /// No description provided for @adminPendingAcknowledgements.
  ///
  /// In en, this message translates to:
  /// **'Pending acknowledgements'**
  String get adminPendingAcknowledgements;

  /// No description provided for @adminTransporterVolume.
  ///
  /// In en, this message translates to:
  /// **'Transporter business volume'**
  String get adminTransporterVolume;

  /// No description provided for @adminCompanyFreight.
  ///
  /// In en, this message translates to:
  /// **'Company-wise freight'**
  String get adminCompanyFreight;

  /// No description provided for @adminTownFreight.
  ///
  /// In en, this message translates to:
  /// **'Town-wise freight'**
  String get adminTownFreight;

  /// No description provided for @adminNoDataRange.
  ///
  /// In en, this message translates to:
  /// **'No data in range'**
  String get adminNoDataRange;

  /// No description provided for @adminDelayAlerts.
  ///
  /// In en, this message translates to:
  /// **'Delay and acknowledgement alerts'**
  String get adminDelayAlerts;

  /// No description provided for @adminNoDelayedRows.
  ///
  /// In en, this message translates to:
  /// **'No delayed dispatch rows in this window.'**
  String get adminNoDelayedRows;

  /// No description provided for @adminDelayed.
  ///
  /// In en, this message translates to:
  /// **'delayed'**
  String get adminDelayed;

  /// No description provided for @adminDays.
  ///
  /// In en, this message translates to:
  /// **'day(s)'**
  String get adminDays;

  /// No description provided for @adminInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get adminInvoice;

  /// No description provided for @adminAck.
  ///
  /// In en, this message translates to:
  /// **'ack'**
  String get adminAck;

  /// No description provided for @adminUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get adminUnassigned;

  /// No description provided for @tpProfileAndLogout.
  ///
  /// In en, this message translates to:
  /// **'Profile and logout'**
  String get tpProfileAndLogout;

  /// No description provided for @tpBidPlaced.
  ///
  /// In en, this message translates to:
  /// **'Bid placed: ₹{amount}. You can revise it until bidding closes.'**
  String tpBidPlaced(String amount);

  /// No description provided for @tpBidFailed.
  ///
  /// In en, this message translates to:
  /// **'Bid failed: {error}'**
  String tpBidFailed(String error);

  /// No description provided for @tpBidClosed.
  ///
  /// In en, this message translates to:
  /// **'Bid closed'**
  String get tpBidClosed;

  /// No description provided for @tpBidClosedHint.
  ///
  /// In en, this message translates to:
  /// **'Only bids you win stay available in your past bids and fleet.'**
  String get tpBidClosedHint;

  /// No description provided for @tpBackToOpenBids.
  ///
  /// In en, this message translates to:
  /// **'Back to open bids'**
  String get tpBackToOpenBids;

  /// No description provided for @tpLiveBidding.
  ///
  /// In en, this message translates to:
  /// **'Live Bidding'**
  String get tpLiveBidding;

  /// No description provided for @tpNoBidsYet.
  ///
  /// In en, this message translates to:
  /// **'No bids yet'**
  String get tpNoBidsYet;

  /// No description provided for @tpAnonymousBidders.
  ///
  /// In en, this message translates to:
  /// **'{count} anonymous bidder(s)'**
  String tpAnonymousBidders(int count);

  /// No description provided for @tpPlacing.
  ///
  /// In en, this message translates to:
  /// **'Placing...'**
  String get tpPlacing;

  /// No description provided for @tpUpdateBid.
  ///
  /// In en, this message translates to:
  /// **'Update bid'**
  String get tpUpdateBid;

  /// No description provided for @tpPlaceBid.
  ///
  /// In en, this message translates to:
  /// **'Place bid'**
  String get tpPlaceBid;

  /// No description provided for @tpYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get tpYou;

  /// No description provided for @tpAnonymousBidder.
  ///
  /// In en, this message translates to:
  /// **'Anonymous bidder'**
  String get tpAnonymousBidder;

  /// No description provided for @tpTransporterBrowserHint.
  ///
  /// In en, this message translates to:
  /// **'Manage bids, fleet, and delivery updates from the browser.'**
  String get tpTransporterBrowserHint;

  /// No description provided for @tpBiddingOpenHours.
  ///
  /// In en, this message translates to:
  /// **'Bidding open · {hours}h {minutes}m left'**
  String tpBiddingOpenHours(int hours, int minutes);

  /// No description provided for @tpBiddingOpenMinutes.
  ///
  /// In en, this message translates to:
  /// **'Bidding open · {minutes}m left'**
  String tpBiddingOpenMinutes(int minutes);

  /// No description provided for @tpBiddingOpen.
  ///
  /// In en, this message translates to:
  /// **'Bidding open'**
  String get tpBiddingOpen;

  /// No description provided for @tpYouWonBid.
  ///
  /// In en, this message translates to:
  /// **'You won this bid'**
  String get tpYouWonBid;

  /// No description provided for @tpAwardedOther.
  ///
  /// In en, this message translates to:
  /// **'Awarded to another transporter'**
  String get tpAwardedOther;

  /// No description provided for @tpDeliveryStatus.
  ///
  /// In en, this message translates to:
  /// **'Delivery {status}'**
  String tpDeliveryStatus(String status);

  /// No description provided for @tpTrackArrow.
  ///
  /// In en, this message translates to:
  /// **'Track →'**
  String get tpTrackArrow;

  /// No description provided for @tpProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get tpProfileUpdated;

  /// No description provided for @tpUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String tpUpdateFailed(String error);

  /// No description provided for @tpAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get tpAdmin;

  /// No description provided for @tpLogisticsManager.
  ///
  /// In en, this message translates to:
  /// **'Logistics Manager'**
  String get tpLogisticsManager;

  /// No description provided for @tpDispatchManager.
  ///
  /// In en, this message translates to:
  /// **'Dispatch Manager'**
  String get tpDispatchManager;

  /// No description provided for @tpSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get tpSignedIn;

  /// No description provided for @tpProfileDetails.
  ///
  /// In en, this message translates to:
  /// **'Profile details'**
  String get tpProfileDetails;

  /// No description provided for @tpProfileDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Keep your contact and compliance information updated for smoother bidding and dispatch.'**
  String get tpProfileDetailsHint;

  /// No description provided for @tpBusinessInformation.
  ///
  /// In en, this message translates to:
  /// **'Business information'**
  String get tpBusinessInformation;

  /// No description provided for @tpFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get tpFullName;

  /// No description provided for @tpBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get tpBusinessName;

  /// No description provided for @tpPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get tpPhoneNumber;

  /// No description provided for @tpBusinessRegistration.
  ///
  /// In en, this message translates to:
  /// **'Business registration no.'**
  String get tpBusinessRegistration;

  /// No description provided for @tpSavingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get tpSavingEllipsis;

  /// No description provided for @tpSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get tpSaveChanges;

  /// No description provided for @tpAccountOverview.
  ///
  /// In en, this message translates to:
  /// **'Account overview'**
  String get tpAccountOverview;

  /// No description provided for @tpAccountOverviewHint.
  ///
  /// In en, this message translates to:
  /// **'Quick reference for your account status and sign-in details.'**
  String get tpAccountOverviewHint;

  /// No description provided for @tpNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get tpNotAvailable;

  /// No description provided for @tpRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get tpRole;

  /// No description provided for @tpUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get tpUnknown;

  /// No description provided for @tpPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get tpPassword;

  /// No description provided for @tpManagedCredentials.
  ///
  /// In en, this message translates to:
  /// **'Managed from login credentials'**
  String get tpManagedCredentials;

  /// No description provided for @tpFleetSetup.
  ///
  /// In en, this message translates to:
  /// **'Fleet setup'**
  String get tpFleetSetup;

  /// No description provided for @tpFleetSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Add vehicles and drivers separately for dispatch.'**
  String get tpFleetSetupHint;

  /// No description provided for @tpActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get tpActions;

  /// No description provided for @tpActionsHint.
  ///
  /// In en, this message translates to:
  /// **'Common account options and quick maintenance tasks.'**
  String get tpActionsHint;

  /// No description provided for @tpReloadProfile.
  ///
  /// In en, this message translates to:
  /// **'Reload profile data'**
  String get tpReloadProfile;

  /// No description provided for @tpFetchLatest.
  ///
  /// In en, this message translates to:
  /// **'Fetch latest account information'**
  String get tpFetchLatest;

  /// No description provided for @tpPrivacyDeletion.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy and account deletion'**
  String get tpPrivacyDeletion;

  /// No description provided for @tpSignOutHint.
  ///
  /// In en, this message translates to:
  /// **'Sign out and return to welcome screen'**
  String get tpSignOutHint;

  /// No description provided for @tpProfileSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Profile changes reflect across the mobile app and web dashboard.'**
  String get tpProfileSyncHint;

  /// No description provided for @tpEditableProfile.
  ///
  /// In en, this message translates to:
  /// **'Editable profile'**
  String get tpEditableProfile;

  /// No description provided for @tpDeliveryProgress.
  ///
  /// In en, this message translates to:
  /// **'Delivery progress'**
  String get tpDeliveryProgress;

  /// No description provided for @tpDeliveredCaps.
  ///
  /// In en, this message translates to:
  /// **'DELIVERED'**
  String get tpDeliveredCaps;

  /// No description provided for @tpInTransitCaps.
  ///
  /// In en, this message translates to:
  /// **'IN TRANSIT'**
  String get tpInTransitCaps;

  /// No description provided for @tpPickupCaps.
  ///
  /// In en, this message translates to:
  /// **'PICKUP'**
  String get tpPickupCaps;

  /// No description provided for @tpDispatchedCaps.
  ///
  /// In en, this message translates to:
  /// **'DISPATCHED'**
  String get tpDispatchedCaps;

  /// No description provided for @tpLmConfirmedVehicle.
  ///
  /// In en, this message translates to:
  /// **'LM confirmed vehicle'**
  String get tpLmConfirmedVehicle;

  /// No description provided for @tpLmRaisedIssue.
  ///
  /// In en, this message translates to:
  /// **'LM raised an issue'**
  String get tpLmRaisedIssue;

  /// No description provided for @tpWaitingVehicleConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for LM vehicle confirmation'**
  String get tpWaitingVehicleConfirmation;

  /// No description provided for @tpVehicleConfirmedHint.
  ///
  /// In en, this message translates to:
  /// **'The logistics manager has confirmed the vehicle details.'**
  String get tpVehicleConfirmedHint;

  /// No description provided for @tpDispatchUpdateHint.
  ///
  /// In en, this message translates to:
  /// **'Update the dispatch details and submit again for confirmation.'**
  String get tpDispatchUpdateHint;

  /// No description provided for @tpDispatchChangeHint.
  ///
  /// In en, this message translates to:
  /// **'If you change dispatch details, LM will need to confirm again.'**
  String get tpDispatchChangeHint;

  /// No description provided for @tpCouldNotReadImage.
  ///
  /// In en, this message translates to:
  /// **'Could not read selected image'**
  String get tpCouldNotReadImage;

  /// No description provided for @tpPhotoUploaded.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded'**
  String get tpPhotoUploaded;

  /// No description provided for @tpUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String tpUploadFailed(String error);

  /// No description provided for @tpUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get tpUploading;

  /// No description provided for @tpUploadedPreview.
  ///
  /// In en, this message translates to:
  /// **'Uploaded - tap to preview'**
  String get tpUploadedPreview;

  /// No description provided for @tpSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get tpSaved;

  /// No description provided for @tpDispatched.
  ///
  /// In en, this message translates to:
  /// **'Dispatched'**
  String get tpDispatched;

  /// No description provided for @tpLorryProof.
  ///
  /// In en, this message translates to:
  /// **'Lorry proof'**
  String get tpLorryProof;

  /// No description provided for @tpAddLorryPhotograph.
  ///
  /// In en, this message translates to:
  /// **'Add Lorry Photograph'**
  String get tpAddLorryPhotograph;

  /// No description provided for @tpUploadLorryPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of Lorry'**
  String get tpUploadLorryPhoto;

  /// No description provided for @tpDriverProof.
  ///
  /// In en, this message translates to:
  /// **'Driver proof'**
  String get tpDriverProof;

  /// No description provided for @tpEnterDriverPhotograph.
  ///
  /// In en, this message translates to:
  /// **'Enter Driver Photograph'**
  String get tpEnterDriverPhotograph;

  /// No description provided for @tpUploadDriverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of Driver'**
  String get tpUploadDriverPhoto;

  /// No description provided for @tpDriverAadhaarPhoto.
  ///
  /// In en, this message translates to:
  /// **'Enter Driver Aadhaar Card Photograph'**
  String get tpDriverAadhaarPhoto;

  /// No description provided for @tpUploadDriverAadhaar.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of Driver Aadhaar Card'**
  String get tpUploadDriverAadhaar;

  /// No description provided for @tpSubmitLorryDetails.
  ///
  /// In en, this message translates to:
  /// **'Submit Lorry details'**
  String get tpSubmitLorryDetails;

  /// No description provided for @tpSelectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select vehicle'**
  String get tpSelectVehicle;

  /// No description provided for @tpNoSavedVehicles.
  ///
  /// In en, this message translates to:
  /// **'No saved vehicles yet'**
  String get tpNoSavedVehicles;

  /// No description provided for @tpChooseSavedFleet.
  ///
  /// In en, this message translates to:
  /// **'Choose from your saved fleet'**
  String get tpChooseSavedFleet;

  /// No description provided for @tpUseSavedVehicle.
  ///
  /// In en, this message translates to:
  /// **'Use a vehicle you already added, or add one first.'**
  String get tpUseSavedVehicle;

  /// No description provided for @tpRcSaved.
  ///
  /// In en, this message translates to:
  /// **'RC saved'**
  String get tpRcSaved;

  /// No description provided for @tpInsuranceSaved.
  ///
  /// In en, this message translates to:
  /// **'Insurance saved'**
  String get tpInsuranceSaved;

  /// No description provided for @tpSelectDriver.
  ///
  /// In en, this message translates to:
  /// **'Select driver'**
  String get tpSelectDriver;

  /// No description provided for @tpNoSavedDrivers.
  ///
  /// In en, this message translates to:
  /// **'No saved drivers yet'**
  String get tpNoSavedDrivers;

  /// No description provided for @tpChooseSavedDrivers.
  ///
  /// In en, this message translates to:
  /// **'Choose from your saved drivers'**
  String get tpChooseSavedDrivers;

  /// No description provided for @tpUseSavedDriver.
  ///
  /// In en, this message translates to:
  /// **'Use a driver you already added, or add one first.'**
  String get tpUseSavedDriver;

  /// No description provided for @tpLicenceSaved.
  ///
  /// In en, this message translates to:
  /// **'Licence saved'**
  String get tpLicenceSaved;

  /// No description provided for @tpPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get tpPickup;

  /// No description provided for @tpPickupDetails.
  ///
  /// In en, this message translates to:
  /// **'Pickup details'**
  String get tpPickupDetails;

  /// No description provided for @tpEnterDriverPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter Driver Phone Number'**
  String get tpEnterDriverPhone;

  /// No description provided for @tpEnterSitePhoto.
  ///
  /// In en, this message translates to:
  /// **'Enter on site photo'**
  String get tpEnterSitePhoto;

  /// No description provided for @tpUploadPresence.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of your presence'**
  String get tpUploadPresence;

  /// No description provided for @tpSubmitPickup.
  ///
  /// In en, this message translates to:
  /// **'Submit Pickup details'**
  String get tpSubmitPickup;

  /// No description provided for @tpInTransit.
  ///
  /// In en, this message translates to:
  /// **'In Transit'**
  String get tpInTransit;

  /// No description provided for @tpSubcontractors.
  ///
  /// In en, this message translates to:
  /// **'Sub-contractors'**
  String get tpSubcontractors;

  /// No description provided for @tpAddContractor.
  ///
  /// In en, this message translates to:
  /// **'Add contractor'**
  String get tpAddContractor;

  /// No description provided for @tpVerificationDetails.
  ///
  /// In en, this message translates to:
  /// **'Verification details'**
  String get tpVerificationDetails;

  /// No description provided for @tpGrBiltyNumber.
  ///
  /// In en, this message translates to:
  /// **'GR / Bilty number'**
  String get tpGrBiltyNumber;

  /// No description provided for @tpEwayBillNumber.
  ///
  /// In en, this message translates to:
  /// **'E-way bill number'**
  String get tpEwayBillNumber;

  /// No description provided for @tpCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get tpCurrentLocation;

  /// No description provided for @tpEnterCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Enter the current location'**
  String get tpEnterCurrentLocation;

  /// No description provided for @tpLocationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Location updated'**
  String get tpLocationUpdated;

  /// No description provided for @tpLocationUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Location update failed: {error}'**
  String tpLocationUpdateFailed(String error);

  /// No description provided for @tpUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating...'**
  String get tpUpdating;

  /// No description provided for @tpUpdateLocation.
  ///
  /// In en, this message translates to:
  /// **'Update location'**
  String get tpUpdateLocation;

  /// No description provided for @tpTransitSitePhoto.
  ///
  /// In en, this message translates to:
  /// **'Transit site photo'**
  String get tpTransitSitePhoto;

  /// No description provided for @tpShareTransit.
  ///
  /// In en, this message translates to:
  /// **'Share transit details'**
  String get tpShareTransit;

  /// No description provided for @tpContractorNumber.
  ///
  /// In en, this message translates to:
  /// **'Contractor {number}'**
  String tpContractorNumber(int number);

  /// No description provided for @tpName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get tpName;

  /// No description provided for @tpPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get tpPhone;

  /// No description provided for @tpFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get tpFrom;

  /// No description provided for @tpTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get tpTo;

  /// No description provided for @tpSelectCity.
  ///
  /// In en, this message translates to:
  /// **'Select city'**
  String get tpSelectCity;

  /// No description provided for @tpDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get tpDelivered;

  /// No description provided for @tpDeliverySiteDetails.
  ///
  /// In en, this message translates to:
  /// **'Enter Delivery site details'**
  String get tpDeliverySiteDetails;

  /// No description provided for @tpEnterReceiverName.
  ///
  /// In en, this message translates to:
  /// **'Enter receiver name'**
  String get tpEnterReceiverName;

  /// No description provided for @tpEnterReceiverNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter Receiver number'**
  String get tpEnterReceiverNumber;

  /// No description provided for @tpEnterGrNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter GR Number'**
  String get tpEnterGrNumber;

  /// No description provided for @tpEnterEwayBill.
  ///
  /// In en, this message translates to:
  /// **'Enter E-way Bill Number'**
  String get tpEnterEwayBill;

  /// No description provided for @tpProofOfDelivery.
  ///
  /// In en, this message translates to:
  /// **'Proof of Delivery (POD)'**
  String get tpProofOfDelivery;

  /// No description provided for @tpUploadPod.
  ///
  /// In en, this message translates to:
  /// **'Upload Proof of Delivery'**
  String get tpUploadPod;

  /// No description provided for @tpAdditionalChargesReason.
  ///
  /// In en, this message translates to:
  /// **'Additional Charges (if any) — bill reason'**
  String get tpAdditionalChargesReason;

  /// No description provided for @tpLoadingChargesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. loading charges'**
  String get tpLoadingChargesHint;

  /// No description provided for @tpBillPhoto.
  ///
  /// In en, this message translates to:
  /// **'Bill photo'**
  String get tpBillPhoto;

  /// No description provided for @tpUploadBillPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of the bill'**
  String get tpUploadBillPhoto;

  /// No description provided for @tpOnSitePhoto.
  ///
  /// In en, this message translates to:
  /// **'On-site photo'**
  String get tpOnSitePhoto;

  /// No description provided for @tpShareDelivery.
  ///
  /// In en, this message translates to:
  /// **'Share delivery details'**
  String get tpShareDelivery;

  /// No description provided for @opsInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get opsInvoice;

  /// No description provided for @opsLrOptional.
  ///
  /// In en, this message translates to:
  /// **'LR number (optional)'**
  String get opsLrOptional;

  /// No description provided for @opsDeliveryRefOptional.
  ///
  /// In en, this message translates to:
  /// **'Delivery reference (optional)'**
  String get opsDeliveryRefOptional;

  /// No description provided for @opsPartyName.
  ///
  /// In en, this message translates to:
  /// **'Party name'**
  String get opsPartyName;

  /// No description provided for @opsTown.
  ///
  /// In en, this message translates to:
  /// **'Town'**
  String get opsTown;

  /// No description provided for @opsCases.
  ///
  /// In en, this message translates to:
  /// **'Cases'**
  String get opsCases;

  /// No description provided for @opsMetricTons.
  ///
  /// In en, this message translates to:
  /// **'Metric tons'**
  String get opsMetricTons;

  /// No description provided for @opsFreightShare.
  ///
  /// In en, this message translates to:
  /// **'Freight share'**
  String get opsFreightShare;

  /// No description provided for @opsBillDate.
  ///
  /// In en, this message translates to:
  /// **'Bill date'**
  String get opsBillDate;

  /// No description provided for @opsDispatchDate.
  ///
  /// In en, this message translates to:
  /// **'Dispatch date'**
  String get opsDispatchDate;

  /// No description provided for @opsVehicleNumber.
  ///
  /// In en, this message translates to:
  /// **'Vehicle number'**
  String get opsVehicleNumber;

  /// No description provided for @opsVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get opsVehicleType;

  /// No description provided for @opsChargeType.
  ///
  /// In en, this message translates to:
  /// **'Charge type'**
  String get opsChargeType;

  /// No description provided for @opsAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get opsAmount;

  /// No description provided for @opsChargeAllocation.
  ///
  /// In en, this message translates to:
  /// **'Charge allocation'**
  String get opsChargeAllocation;

  /// No description provided for @opsRemarksOptional.
  ///
  /// In en, this message translates to:
  /// **'Remarks (optional)'**
  String get opsRemarksOptional;

  /// No description provided for @opsSubmitLockFreight.
  ///
  /// In en, this message translates to:
  /// **'Save invoice details'**
  String get opsSubmitLockFreight;

  /// No description provided for @opsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get opsSaving;

  /// No description provided for @opsWorkDetails.
  ///
  /// In en, this message translates to:
  /// **'Work details'**
  String get opsWorkDetails;

  /// No description provided for @opsManagerIdentityHint.
  ///
  /// In en, this message translates to:
  /// **'Only manager identity and operating area are needed here.'**
  String get opsManagerIdentityHint;

  /// No description provided for @opsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get opsAccount;

  /// No description provided for @opsTransporterOwnershipHint.
  ///
  /// In en, this message translates to:
  /// **'Business, GST and vehicle ownership stay with transporters.'**
  String get opsTransporterOwnershipHint;

  /// No description provided for @opsEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get opsEmail;

  /// No description provided for @opsRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get opsRole;

  /// No description provided for @opsStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get opsStatus;

  /// No description provided for @opsAllTransporters.
  ///
  /// In en, this message translates to:
  /// **'All transporters'**
  String get opsAllTransporters;

  /// No description provided for @opsReadOnlyTransporters.
  ///
  /// In en, this message translates to:
  /// **'Read-only list for assigning bids and checking responsibility.'**
  String get opsReadOnlyTransporters;

  /// No description provided for @opsAllVehicles.
  ///
  /// In en, this message translates to:
  /// **'All vehicles'**
  String get opsAllVehicles;

  /// No description provided for @opsVehiclesOwnedHint.
  ///
  /// In en, this message translates to:
  /// **'Vehicles are added by transporters. Managers verify what arrives.'**
  String get opsVehiclesOwnedHint;

  /// No description provided for @opsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get opsAdd;

  /// No description provided for @opsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get opsEdit;

  /// No description provided for @opsPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get opsPhone;

  /// No description provided for @opsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get opsConfirm;

  /// No description provided for @opsRaiseIssue.
  ///
  /// In en, this message translates to:
  /// **'Raise issue'**
  String get opsRaiseIssue;

  /// No description provided for @opsConfirmVehicleArrived.
  ///
  /// In en, this message translates to:
  /// **'Confirm vehicle arrived'**
  String get opsConfirmVehicleArrived;

  /// No description provided for @opsRaiseVehicleIssue.
  ///
  /// In en, this message translates to:
  /// **'Raise vehicle issue'**
  String get opsRaiseVehicleIssue;

  /// No description provided for @opsLastDriverLocation.
  ///
  /// In en, this message translates to:
  /// **'Last location from driver update'**
  String get opsLastDriverLocation;

  /// No description provided for @opsLorryPhoto.
  ///
  /// In en, this message translates to:
  /// **'Lorry photo'**
  String get opsLorryPhoto;

  /// No description provided for @opsDriverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Driver photo'**
  String get opsDriverPhoto;

  /// No description provided for @opsDriverAadhaar.
  ///
  /// In en, this message translates to:
  /// **'Driver Aadhaar'**
  String get opsDriverAadhaar;

  /// No description provided for @opsInvoicePhoto.
  ///
  /// In en, this message translates to:
  /// **'Invoice photo'**
  String get opsInvoicePhoto;

  /// No description provided for @opsSitePhoto.
  ///
  /// In en, this message translates to:
  /// **'Site photo'**
  String get opsSitePhoto;

  /// No description provided for @opsProofOfDelivery.
  ///
  /// In en, this message translates to:
  /// **'Proof of delivery'**
  String get opsProofOfDelivery;

  /// No description provided for @opsBillPhoto.
  ///
  /// In en, this message translates to:
  /// **'Bill photo'**
  String get opsBillPhoto;

  /// No description provided for @opsTollTax.
  ///
  /// In en, this message translates to:
  /// **'Toll tax'**
  String get opsTollTax;

  /// No description provided for @opsPointCharge.
  ///
  /// In en, this message translates to:
  /// **'Point charge'**
  String get opsPointCharge;

  /// No description provided for @opsExtraFreight.
  ///
  /// In en, this message translates to:
  /// **'Extra freight'**
  String get opsExtraFreight;

  /// No description provided for @opsLabour.
  ///
  /// In en, this message translates to:
  /// **'Labour'**
  String get opsLabour;

  /// No description provided for @opsDetention.
  ///
  /// In en, this message translates to:
  /// **'Detention'**
  String get opsDetention;

  /// No description provided for @opsOutRoute.
  ///
  /// In en, this message translates to:
  /// **'Out route'**
  String get opsOutRoute;

  /// No description provided for @opsDeduction.
  ///
  /// In en, this message translates to:
  /// **'Deduction'**
  String get opsDeduction;

  /// No description provided for @opsOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get opsOther;

  /// No description provided for @opsDispatched.
  ///
  /// In en, this message translates to:
  /// **'Dispatched'**
  String get opsDispatched;

  /// No description provided for @opsPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get opsPickup;

  /// No description provided for @opsDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get opsDelivered;

  /// No description provided for @adminFreightLedger.
  ///
  /// In en, this message translates to:
  /// **'Freight ledger'**
  String get adminFreightLedger;

  /// No description provided for @adminExportReports.
  ///
  /// In en, this message translates to:
  /// **'Export reports'**
  String get adminExportReports;

  /// No description provided for @adminTransporterMonthlyCsv.
  ///
  /// In en, this message translates to:
  /// **'Transporter monthly CSV'**
  String get adminTransporterMonthlyCsv;

  /// No description provided for @adminPlaceWiseCsv.
  ///
  /// In en, this message translates to:
  /// **'Place-wise CSV'**
  String get adminPlaceWiseCsv;

  /// No description provided for @adminInvoiceWiseCsv.
  ///
  /// In en, this message translates to:
  /// **'Invoice-wise CSV'**
  String get adminInvoiceWiseCsv;

  /// No description provided for @adminPodPendingCsv.
  ///
  /// In en, this message translates to:
  /// **'POD pending CSV'**
  String get adminPodPendingCsv;

  /// No description provided for @adminVehicleTonnageCsv.
  ///
  /// In en, this message translates to:
  /// **'Vehicle tonnage CSV'**
  String get adminVehicleTonnageCsv;

  /// No description provided for @adminRouteWiseCsv.
  ///
  /// In en, this message translates to:
  /// **'Route-wise CSV'**
  String get adminRouteWiseCsv;

  /// No description provided for @adminUploadCsv.
  ///
  /// In en, this message translates to:
  /// **'Upload CSV'**
  String get adminUploadCsv;

  /// No description provided for @adminEntry.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get adminEntry;

  /// No description provided for @adminCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get adminCompany;

  /// No description provided for @adminDestinationPlace.
  ///
  /// In en, this message translates to:
  /// **'Destination / Place'**
  String get adminDestinationPlace;

  /// No description provided for @adminInvoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice Number'**
  String get adminInvoiceNumber;

  /// No description provided for @adminSearchInvoice.
  ///
  /// In en, this message translates to:
  /// **'Search invoice'**
  String get adminSearchInvoice;

  /// No description provided for @adminFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get adminFilters;

  /// No description provided for @adminClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get adminClearFilters;

  /// No description provided for @adminPodAcknowledgement.
  ///
  /// In en, this message translates to:
  /// **'POD / Acknowledgement'**
  String get adminPodAcknowledgement;

  /// No description provided for @adminVehicleTonnage.
  ///
  /// In en, this message translates to:
  /// **'Vehicle tonnage'**
  String get adminVehicleTonnage;

  /// No description provided for @adminPlaceSearch.
  ///
  /// In en, this message translates to:
  /// **'Place search'**
  String get adminPlaceSearch;

  /// No description provided for @adminOriginDestinationParty.
  ///
  /// In en, this message translates to:
  /// **'Origin, destination, party'**
  String get adminOriginDestinationParty;

  /// No description provided for @adminEwayNumber.
  ///
  /// In en, this message translates to:
  /// **'E-way Bill Number'**
  String get adminEwayNumber;

  /// No description provided for @adminSearchEway.
  ///
  /// In en, this message translates to:
  /// **'Search e-way bill'**
  String get adminSearchEway;

  /// No description provided for @adminDelayedOnly.
  ///
  /// In en, this message translates to:
  /// **'Delayed only'**
  String get adminDelayedOnly;

  /// No description provided for @adminLatePod.
  ///
  /// In en, this message translates to:
  /// **'Late POD'**
  String get adminLatePod;

  /// No description provided for @adminNoLedgerRows.
  ///
  /// In en, this message translates to:
  /// **'No ledger rows match this filter.'**
  String get adminNoLedgerRows;

  /// No description provided for @adminSummaryReport.
  ///
  /// In en, this message translates to:
  /// **'Summary report'**
  String get adminSummaryReport;

  /// No description provided for @adminPlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get adminPlace;

  /// No description provided for @adminRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get adminRoute;

  /// No description provided for @adminVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get adminVehicle;

  /// No description provided for @adminShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing'**
  String get adminShowing;

  /// No description provided for @adminOf.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get adminOf;

  /// No description provided for @adminRows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get adminRows;

  /// No description provided for @adminPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get adminPreviousPage;

  /// No description provided for @adminNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get adminNextPage;

  /// No description provided for @adminScrollLeft.
  ///
  /// In en, this message translates to:
  /// **'Scroll table left'**
  String get adminScrollLeft;

  /// No description provided for @adminScrollRight.
  ///
  /// In en, this message translates to:
  /// **'Scroll table right'**
  String get adminScrollRight;

  /// No description provided for @adminInvoiceRows.
  ///
  /// In en, this message translates to:
  /// **'Invoice rows'**
  String get adminInvoiceRows;

  /// No description provided for @adminTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get adminTrips;

  /// No description provided for @adminVehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get adminVehicles;

  /// No description provided for @adminFreight.
  ///
  /// In en, this message translates to:
  /// **'Freight'**
  String get adminFreight;

  /// No description provided for @adminPodPending.
  ///
  /// In en, this message translates to:
  /// **'POD pending'**
  String get adminPodPending;

  /// No description provided for @adminOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get adminOverview;

  /// No description provided for @adminLoadingPeriod.
  ///
  /// In en, this message translates to:
  /// **'Loading latest period'**
  String get adminLoadingPeriod;

  /// No description provided for @adminLatestPeriod.
  ///
  /// In en, this message translates to:
  /// **'Latest period'**
  String get adminLatestPeriod;

  /// No description provided for @adminDashboardLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the dashboard'**
  String get adminDashboardLoadFailed;

  /// No description provided for @adminRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminRetry;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @adminWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get adminWelcome;

  /// No description provided for @adminMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get adminMonth;

  /// No description provided for @adminFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get adminFrom;

  /// No description provided for @adminTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get adminTo;

  /// No description provided for @adminLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get adminLatest;

  /// No description provided for @adminMetricTons.
  ///
  /// In en, this message translates to:
  /// **'Metric Tons'**
  String get adminMetricTons;

  /// No description provided for @adminReviewValue.
  ///
  /// In en, this message translates to:
  /// **'Review Value'**
  String get adminReviewValue;

  /// No description provided for @adminNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs Attention'**
  String get adminNeedsAttention;

  /// No description provided for @adminNoPriorityItems.
  ///
  /// In en, this message translates to:
  /// **'No priority review items in this period.'**
  String get adminNoPriorityItems;

  /// No description provided for @adminOpenLedger.
  ///
  /// In en, this message translates to:
  /// **'Open ledger'**
  String get adminOpenLedger;

  /// No description provided for @adminAskClawd.
  ///
  /// In en, this message translates to:
  /// **'Ask Clawd'**
  String get adminAskClawd;

  /// No description provided for @adminReviewRoutes.
  ///
  /// In en, this message translates to:
  /// **'Review routes'**
  String get adminReviewRoutes;

  /// No description provided for @adminOpenClawd.
  ///
  /// In en, this message translates to:
  /// **'Open Clawd'**
  String get adminOpenClawd;

  /// No description provided for @adminDocumentReview.
  ///
  /// In en, this message translates to:
  /// **'Review document-wise before payment release.'**
  String get adminDocumentReview;

  /// No description provided for @adminExtraChargesHelp.
  ///
  /// In en, this message translates to:
  /// **'Check labour, detention, toll, and out-route charges.'**
  String get adminExtraChargesHelp;

  /// No description provided for @adminTransporterPerformance.
  ///
  /// In en, this message translates to:
  /// **'Transporter Performance'**
  String get adminTransporterPerformance;

  /// No description provided for @adminRoutesDestinations.
  ///
  /// In en, this message translates to:
  /// **'Routes & Destinations'**
  String get adminRoutesDestinations;

  /// No description provided for @adminFreightPerMt.
  ///
  /// In en, this message translates to:
  /// **'Freight/MT'**
  String get adminFreightPerMt;

  /// No description provided for @adminTrends.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get adminTrends;

  /// No description provided for @adminHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get adminHide;

  /// No description provided for @adminShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get adminShow;

  /// No description provided for @adminNoTrendData.
  ///
  /// In en, this message translates to:
  /// **'No trend data'**
  String get adminNoTrendData;

  /// No description provided for @adminTrendHelp.
  ///
  /// In en, this message translates to:
  /// **'Daily freight trend is available here for a deeper view.'**
  String get adminTrendHelp;

  /// No description provided for @adminNoRecordsPeriod.
  ///
  /// In en, this message translates to:
  /// **'No records in this period.'**
  String get adminNoRecordsPeriod;

  /// No description provided for @adminNoDashboardData.
  ///
  /// In en, this message translates to:
  /// **'No dashboard data found.'**
  String get adminNoDashboardData;

  /// No description provided for @adminAckFollowUp.
  ///
  /// In en, this message translates to:
  /// **'needs acknowledgement follow-up'**
  String get adminAckFollowUp;

  /// No description provided for @adminDuplicateEwayRisk.
  ///
  /// In en, this message translates to:
  /// **'duplicate e-way risk(s)'**
  String get adminDuplicateEwayRisk;

  /// No description provided for @adminRouteCostSpike.
  ///
  /// In en, this message translates to:
  /// **'route cost spike(s)'**
  String get adminRouteCostSpike;

  /// No description provided for @adminCompareFreight.
  ///
  /// In en, this message translates to:
  /// **'needs freight/MT comparison'**
  String get adminCompareFreight;

  /// No description provided for @adminHighExtraCharge.
  ///
  /// In en, this message translates to:
  /// **'high extra charge case(s)'**
  String get adminHighExtraCharge;

  /// No description provided for @adminSelectMonth.
  ///
  /// In en, this message translates to:
  /// **'Select month'**
  String get adminSelectMonth;

  /// No description provided for @adminYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get adminYear;

  /// No description provided for @adminEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get adminEdit;

  /// No description provided for @adminBill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get adminBill;

  /// No description provided for @adminDispatch.
  ///
  /// In en, this message translates to:
  /// **'Dispatch'**
  String get adminDispatch;

  /// No description provided for @adminDelay.
  ///
  /// In en, this message translates to:
  /// **'Delay'**
  String get adminDelay;

  /// No description provided for @adminInvoiceShort.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get adminInvoiceShort;

  /// No description provided for @adminInvoiceCount.
  ///
  /// In en, this message translates to:
  /// **'Inv Count'**
  String get adminInvoiceCount;

  /// No description provided for @adminEway.
  ///
  /// In en, this message translates to:
  /// **'E-way'**
  String get adminEway;

  /// No description provided for @adminEwayCount.
  ///
  /// In en, this message translates to:
  /// **'E-way Count'**
  String get adminEwayCount;

  /// No description provided for @adminDel.
  ///
  /// In en, this message translates to:
  /// **'DEL'**
  String get adminDel;

  /// No description provided for @adminParty.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get adminParty;

  /// No description provided for @adminPartyCount.
  ///
  /// In en, this message translates to:
  /// **'Party Count'**
  String get adminPartyCount;

  /// No description provided for @adminOrigin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get adminOrigin;

  /// No description provided for @adminTown.
  ///
  /// In en, this message translates to:
  /// **'Town'**
  String get adminTown;

  /// No description provided for @adminTon.
  ///
  /// In en, this message translates to:
  /// **'Ton'**
  String get adminTon;

  /// No description provided for @adminCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get adminCapacity;

  /// No description provided for @adminDispatchGr.
  ///
  /// In en, this message translates to:
  /// **'Dispatch GR'**
  String get adminDispatchGr;

  /// No description provided for @adminTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get adminTotal;

  /// No description provided for @adminBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get adminBalance;

  /// No description provided for @adminPodStatus.
  ///
  /// In en, this message translates to:
  /// **'POD Status'**
  String get adminPodStatus;

  /// No description provided for @adminPodDate.
  ///
  /// In en, this message translates to:
  /// **'POD Date'**
  String get adminPodDate;

  /// No description provided for @adminPodFile.
  ///
  /// In en, this message translates to:
  /// **'POD File'**
  String get adminPodFile;

  /// No description provided for @adminPodRemark.
  ///
  /// In en, this message translates to:
  /// **'POD Remark'**
  String get adminPodRemark;

  /// No description provided for @adminReceivedBy.
  ///
  /// In en, this message translates to:
  /// **'Received By'**
  String get adminReceivedBy;

  /// No description provided for @adminPodReceived.
  ///
  /// In en, this message translates to:
  /// **'POD Received'**
  String get adminPodReceived;

  /// No description provided for @adminFreightPerCase.
  ///
  /// In en, this message translates to:
  /// **'Freight/Case'**
  String get adminFreightPerCase;

  /// No description provided for @adminAvgFreightPerMt.
  ///
  /// In en, this message translates to:
  /// **'Avg Freight/MT'**
  String get adminAvgFreightPerMt;

  /// No description provided for @adminTransporterBreakup.
  ///
  /// In en, this message translates to:
  /// **'Transporter breakup'**
  String get adminTransporterBreakup;

  /// No description provided for @adminTransporterSummary.
  ///
  /// In en, this message translates to:
  /// **'Transporter summary'**
  String get adminTransporterSummary;

  /// No description provided for @tpLocationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ambala bypass'**
  String get tpLocationHint;

  /// No description provided for @tpApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get tpApproved;

  /// No description provided for @tpPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get tpPending;

  /// No description provided for @tpRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get tpRejected;

  /// No description provided for @tpSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get tpSuspended;

  /// No description provided for @tpCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tpCompleted;

  /// No description provided for @tpAwarded.
  ///
  /// In en, this message translates to:
  /// **'Awarded'**
  String get tpAwarded;

  /// No description provided for @tpLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get tpLocked;

  /// No description provided for @adminCompanyRequired.
  ///
  /// In en, this message translates to:
  /// **'Company is required.'**
  String get adminCompanyRequired;

  /// No description provided for @adminUploadLedgerCsv.
  ///
  /// In en, this message translates to:
  /// **'Upload ledger CSV'**
  String get adminUploadLedgerCsv;

  /// No description provided for @adminCompanySheetName.
  ///
  /// In en, this message translates to:
  /// **'Company / sheet name *'**
  String get adminCompanySheetName;

  /// No description provided for @adminUploadTag.
  ///
  /// In en, this message translates to:
  /// **'Upload tag'**
  String get adminUploadTag;

  /// No description provided for @adminCsvHelp.
  ///
  /// In en, this message translates to:
  /// **'Use an Excel-exported CSV. Direct .xlsx upload is not enabled in this version.'**
  String get adminCsvHelp;

  /// No description provided for @adminCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get adminCancel;

  /// No description provided for @adminChooseCsv.
  ///
  /// In en, this message translates to:
  /// **'Choose CSV'**
  String get adminChooseCsv;

  /// No description provided for @adminCsvUploadComplete.
  ///
  /// In en, this message translates to:
  /// **'CSV upload complete'**
  String get adminCsvUploadComplete;

  /// No description provided for @adminRowsImported.
  ///
  /// In en, this message translates to:
  /// **'Rows imported'**
  String get adminRowsImported;

  /// No description provided for @adminChargeRowsImported.
  ///
  /// In en, this message translates to:
  /// **'Charge rows imported'**
  String get adminChargeRowsImported;

  /// No description provided for @adminMissingTransportersHelp.
  ///
  /// In en, this message translates to:
  /// **'These transporters were not found in approved profiles, so their names were saved in remarks:'**
  String get adminMissingTransportersHelp;

  /// No description provided for @adminMore.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get adminMore;

  /// No description provided for @adminDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get adminDone;

  /// No description provided for @adminLedgerEntry.
  ///
  /// In en, this message translates to:
  /// **'Ledger entry'**
  String get adminLedgerEntry;

  /// No description provided for @adminCompanyRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Company *'**
  String get adminCompanyRequiredLabel;

  /// No description provided for @adminBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get adminBranch;

  /// No description provided for @adminVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get adminVehicleType;

  /// No description provided for @adminDispatchGrBilty.
  ///
  /// In en, this message translates to:
  /// **'Dispatch GR/Bilty'**
  String get adminDispatchGrBilty;

  /// No description provided for @adminAckStatus.
  ///
  /// In en, this message translates to:
  /// **'Ack status'**
  String get adminAckStatus;

  /// No description provided for @adminReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get adminReceived;

  /// No description provided for @adminNotRequired.
  ///
  /// In en, this message translates to:
  /// **'Not required'**
  String get adminNotRequired;

  /// No description provided for @adminPodReceivedDate.
  ///
  /// In en, this message translates to:
  /// **'POD received yyyy-mm-dd'**
  String get adminPodReceivedDate;

  /// No description provided for @adminInvoiceLines.
  ///
  /// In en, this message translates to:
  /// **'Invoice lines'**
  String get adminInvoiceLines;

  /// No description provided for @adminCharges.
  ///
  /// In en, this message translates to:
  /// **'Charges'**
  String get adminCharges;

  /// No description provided for @adminSettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get adminSettlement;

  /// No description provided for @adminLastMonthBalance.
  ///
  /// In en, this message translates to:
  /// **'Last month balance'**
  String get adminLastMonthBalance;

  /// No description provided for @adminPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get adminPayment;

  /// No description provided for @adminSettlementDeduction.
  ///
  /// In en, this message translates to:
  /// **'Settlement deduction'**
  String get adminSettlementDeduction;

  /// No description provided for @adminSettlementRemarks.
  ///
  /// In en, this message translates to:
  /// **'Settlement remarks'**
  String get adminSettlementRemarks;

  /// No description provided for @adminProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get adminProducts;

  /// No description provided for @adminOptionalProductsHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional product/category quantities for Karnal-style reports.'**
  String get adminOptionalProductsHelp;

  /// No description provided for @adminRemarks.
  ///
  /// In en, this message translates to:
  /// **'Remarks'**
  String get adminRemarks;

  /// No description provided for @adminSaveEntry.
  ///
  /// In en, this message translates to:
  /// **'Save entry'**
  String get adminSaveEntry;

  /// No description provided for @adminEditLedgerEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit ledger entry'**
  String get adminEditLedgerEntry;

  /// No description provided for @adminDestinationSummary.
  ///
  /// In en, this message translates to:
  /// **'Destination summary'**
  String get adminDestinationSummary;

  /// No description provided for @adminRouteSummary.
  ///
  /// In en, this message translates to:
  /// **'Route summary'**
  String get adminRouteSummary;

  /// No description provided for @adminVehicleTonnageSummary.
  ///
  /// In en, this message translates to:
  /// **'Vehicle tonnage summary'**
  String get adminVehicleTonnageSummary;

  /// No description provided for @adminClearMonth.
  ///
  /// In en, this message translates to:
  /// **'Clear month'**
  String get adminClearMonth;

  /// No description provided for @adminLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get adminLoadFailed;

  /// No description provided for @adminExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get adminExportFailed;

  /// No description provided for @adminCsvUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'CSV upload failed'**
  String get adminCsvUploadFailed;

  /// No description provided for @adminCompanyTownRequired.
  ///
  /// In en, this message translates to:
  /// **'Company and first invoice town are required.'**
  String get adminCompanyTownRequired;

  /// No description provided for @adminPodFileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read POD file'**
  String get adminPodFileReadFailed;

  /// No description provided for @adminAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get adminAdd;

  /// No description provided for @adminOverrideApproval.
  ///
  /// In en, this message translates to:
  /// **'Admin approval to override duplicate lock'**
  String get adminOverrideApproval;

  /// No description provided for @adminReasonRemarkRequired.
  ///
  /// In en, this message translates to:
  /// **'Reason and remark are mandatory.'**
  String get adminReasonRemarkRequired;

  /// No description provided for @adminRemoveInvoice.
  ///
  /// In en, this message translates to:
  /// **'Remove invoice'**
  String get adminRemoveInvoice;

  /// No description provided for @adminVehicleCapacity.
  ///
  /// In en, this message translates to:
  /// **'Vehicle capacity'**
  String get adminVehicleCapacity;

  /// No description provided for @adminKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get adminKind;

  /// No description provided for @adminRemoveCharge.
  ///
  /// In en, this message translates to:
  /// **'Remove charge'**
  String get adminRemoveCharge;

  /// No description provided for @adminRemoveProduct.
  ///
  /// In en, this message translates to:
  /// **'Remove product'**
  String get adminRemoveProduct;

  /// No description provided for @adminTransporterWiseSummary.
  ///
  /// In en, this message translates to:
  /// **'Transporter-wise summary'**
  String get adminTransporterWiseSummary;

  /// No description provided for @adminPlaceWiseSummary.
  ///
  /// In en, this message translates to:
  /// **'Place-wise summary'**
  String get adminPlaceWiseSummary;

  /// No description provided for @adminRouteWiseSummary.
  ///
  /// In en, this message translates to:
  /// **'Route-wise summary'**
  String get adminRouteWiseSummary;

  /// No description provided for @adminTransporterSummaryHelp.
  ///
  /// In en, this message translates to:
  /// **'Trips, distinct vehicles, freight efficiency, and POD status by transporter.'**
  String get adminTransporterSummaryHelp;

  /// No description provided for @adminPlaceSummaryHelp.
  ///
  /// In en, this message translates to:
  /// **'Destination movement with transporter breakup.'**
  String get adminPlaceSummaryHelp;

  /// No description provided for @adminRouteSummaryHelp.
  ///
  /// In en, this message translates to:
  /// **'From-to route freight comparison.'**
  String get adminRouteSummaryHelp;

  /// No description provided for @adminVehicleSummaryHelp.
  ///
  /// In en, this message translates to:
  /// **'Vehicle capacity category usage.'**
  String get adminVehicleSummaryHelp;

  /// No description provided for @adminDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get adminDestination;

  /// No description provided for @adminFromTo.
  ///
  /// In en, this message translates to:
  /// **'From → To'**
  String get adminFromTo;

  /// No description provided for @adminCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get adminCategory;

  /// No description provided for @adminEwayBill.
  ///
  /// In en, this message translates to:
  /// **'E-way bill'**
  String get adminEwayBill;

  /// No description provided for @adminDelRef.
  ///
  /// In en, this message translates to:
  /// **'DEL ref'**
  String get adminDelRef;

  /// No description provided for @adminLrGr.
  ///
  /// In en, this message translates to:
  /// **'LR/GR'**
  String get adminLrGr;

  /// No description provided for @adminTownRequired.
  ///
  /// In en, this message translates to:
  /// **'Town *'**
  String get adminTownRequired;

  /// No description provided for @adminBillDate.
  ///
  /// In en, this message translates to:
  /// **'Bill date yyyy-mm-dd'**
  String get adminBillDate;

  /// No description provided for @adminDispatchDate.
  ///
  /// In en, this message translates to:
  /// **'Dispatch date yyyy-mm-dd'**
  String get adminDispatchDate;

  /// No description provided for @adminFreightShare.
  ///
  /// In en, this message translates to:
  /// **'Freight share'**
  String get adminFreightShare;

  /// No description provided for @adminAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get adminAmount;

  /// No description provided for @adminChargeRemarks.
  ///
  /// In en, this message translates to:
  /// **'Charge remarks'**
  String get adminChargeRemarks;

  /// No description provided for @adminProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get adminProduct;

  /// No description provided for @adminPodFileUploaded.
  ///
  /// In en, this message translates to:
  /// **'POD file uploaded'**
  String get adminPodFileUploaded;

  /// No description provided for @adminDuplicateFreightLock.
  ///
  /// In en, this message translates to:
  /// **'Duplicate freight lock'**
  String get adminDuplicateFreightLock;

  /// No description provided for @adminOnlyAdminOverride.
  ///
  /// In en, this message translates to:
  /// **'Only an admin can approve duplicate freight.'**
  String get adminOnlyAdminOverride;

  /// No description provided for @adminOverrideReason.
  ///
  /// In en, this message translates to:
  /// **'Override reason *'**
  String get adminOverrideReason;

  /// No description provided for @adminOverrideRemark.
  ///
  /// In en, this message translates to:
  /// **'Override remark *'**
  String get adminOverrideRemark;

  /// No description provided for @adminSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get adminSaveFailed;

  /// No description provided for @opsDeliveryPodStatus.
  ///
  /// In en, this message translates to:
  /// **'Delivery and POD status'**
  String get opsDeliveryPodStatus;

  /// No description provided for @opsDestinationsDelivered.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} destinations delivered'**
  String opsDestinationsDelivered(int count, int total);

  /// No description provided for @opsDeliveryProofsUploaded.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} delivery proofs uploaded'**
  String opsDeliveryProofsUploaded(int count, int total);

  /// No description provided for @opsGoodsInvoiceChallans.
  ///
  /// In en, this message translates to:
  /// **'Goods invoices / challans'**
  String get opsGoodsInvoiceChallans;

  /// No description provided for @opsGrBilty.
  ///
  /// In en, this message translates to:
  /// **'GR / Bilty'**
  String get opsGrBilty;

  /// No description provided for @opsEwayBills.
  ///
  /// In en, this message translates to:
  /// **'E-way bills'**
  String get opsEwayBills;

  /// No description provided for @opsViewDeliveryProof.
  ///
  /// In en, this message translates to:
  /// **'View proof of delivery'**
  String get opsViewDeliveryProof;

  /// No description provided for @opsDeliveryProofPending.
  ///
  /// In en, this message translates to:
  /// **'Proof of delivery pending'**
  String get opsDeliveryProofPending;

  /// No description provided for @opsDuplicateDeliveryDestination.
  ///
  /// In en, this message translates to:
  /// **'That delivery destination is already on the route.'**
  String get opsDuplicateDeliveryDestination;

  /// No description provided for @opsEnterDeliveryQuantities.
  ///
  /// In en, this message translates to:
  /// **'Enter valid cases and metric tonnes for every delivery.'**
  String get opsEnterDeliveryQuantities;

  /// No description provided for @opsBidAwardedDuringEdit.
  ///
  /// In en, this message translates to:
  /// **'This bid was awarded while you were editing it.'**
  String get opsBidAwardedDuringEdit;

  /// No description provided for @opsRemoveDestination.
  ///
  /// In en, this message translates to:
  /// **'Remove destination'**
  String get opsRemoveDestination;

  /// No description provided for @uiQuickLinks.
  ///
  /// In en, this message translates to:
  /// **'Quick links'**
  String get uiQuickLinks;

  /// No description provided for @uiViewDirectory.
  ///
  /// In en, this message translates to:
  /// **'View directory'**
  String get uiViewDirectory;

  /// No description provided for @uiReadOnlyList.
  ///
  /// In en, this message translates to:
  /// **'Read-only list'**
  String get uiReadOnlyList;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
