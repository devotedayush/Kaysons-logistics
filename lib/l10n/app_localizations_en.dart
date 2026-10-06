// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get hindi => 'हिंदी';

  @override
  String get profile => 'Profile';

  @override
  String get accountPrivacy => 'Account & privacy';

  @override
  String get logout => 'Log out';

  @override
  String get home => 'Home';

  @override
  String get more => 'More';

  @override
  String get moreOptions => 'More options';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get users => 'Users';

  @override
  String get bids => 'Bids';

  @override
  String get ledger => 'Ledger';

  @override
  String get fleet => 'Fleet';

  @override
  String get dispatch => 'Dispatch';

  @override
  String get insights => 'Insights';

  @override
  String get analytics => 'Analytics';

  @override
  String get today => 'Today';

  @override
  String dateWindowDays(int days) {
    return '$days days';
  }

  @override
  String get dateWindowCustomDates => 'Custom dates';

  @override
  String get dateWindowFrom => 'From';

  @override
  String get dateWindowTo => 'To';

  @override
  String get dateWindowUsePreset => 'Use preset';

  @override
  String get deliveries => 'Deliveries';

  @override
  String get adminConsole => 'Admin console';

  @override
  String get adminSubtitle =>
      'Review users, oversee freight activity, and keep the network healthy.';

  @override
  String get accountant => 'Accountant';

  @override
  String get accountantSubtitle =>
      'Manage ledgers, reports, and Clawd analysis.';

  @override
  String get logisticsManager => 'Logistics manager';

  @override
  String get logisticsSubtitle =>
      'Publish freights, monitor bids, and track deliveries.';

  @override
  String get dispatchManager => 'Dispatch manager';

  @override
  String get dispatchSubtitle =>
      'Track accepted deliveries and keep movement details current.';

  @override
  String get transporter => 'Transporter';

  @override
  String get transporterSubtitle =>
      'Find freight, manage bids, and review fleet progress.';

  @override
  String get welcomeTitle => 'Never miss a freight';

  @override
  String get welcomeSubtitle => 'Get regular updates on the latest freight';

  @override
  String get loginEmailMobile => 'Log in with email / mobile';

  @override
  String get registerWithUs => 'Register with us';

  @override
  String get or => 'OR';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInInstruction =>
      'Sign in with your registered email and password.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signingIn => 'Signing in...';

  @override
  String get noAccountRegister => 'No account? Register';

  @override
  String get loginFailed => 'Sign in failed';

  @override
  String get clawd => 'Clawd';

  @override
  String get next => 'Next';

  @override
  String stepOfFive(int step) {
    return 'Step $step of 5';
  }

  @override
  String get alreadyAccount => 'Already have an account?';

  @override
  String get goBack => 'Go back';

  @override
  String get registerEmailTitle => 'Enter your email address';

  @override
  String get registerEmailSubtitle =>
      'Sign in with your email. If you don\'t have a Kaysons account yet, we\'ll set one up.';

  @override
  String get yourEmail => 'Your email';

  @override
  String get createPassword => 'Create password';

  @override
  String get passwordLength => 'Must be at least 8 characters';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm new password';

  @override
  String get termsAgreement =>
      'I agree to Kaysons Terms of Use and Privacy Policy and to receive emails from Kaysons.';

  @override
  String get registerNameTitle => 'What is your name?';

  @override
  String get registerProfileSubtitle =>
      'This is used to build your profile on our platform.';

  @override
  String get fullName => 'Full name';

  @override
  String get companyName => 'Company name';

  @override
  String get registerBankTitle => 'What is your bank name?';

  @override
  String get accountHolderName => 'Full name on bank account';

  @override
  String get bankAccountNumber => 'Bank account number';

  @override
  String get photoUpload => 'Photo upload';

  @override
  String get imageReadFailed => 'Could not read selected image';

  @override
  String get registerContactTitle => 'How do we contact you?';

  @override
  String get mobileNumber => 'Mobile number';

  @override
  String get landlineNumber => 'Company landline number';

  @override
  String get businessRegistrationNumber => 'Business registration number';

  @override
  String get lorryRcNumber => 'Lorry RC number';

  @override
  String get lorryInsuranceNumber => 'Lorry insurance number';

  @override
  String get gstinOptional => 'GSTIN (optional)';

  @override
  String get registerRestart =>
      'Restart registration: email or password is missing';

  @override
  String get invalidMobile => 'Enter a valid 10-digit Indian mobile number';

  @override
  String get registrationFailed => 'Registration failed';

  @override
  String get contactSubtitle =>
      'Give us your number and business details. You will be signed in after submitting.';

  @override
  String get submit => 'Submit';

  @override
  String get submitting => 'Submitting...';

  @override
  String get uploadBlankCheque => 'Upload a photo of a blank cheque';

  @override
  String get selectedReplace => 'Selected - tap to replace';

  @override
  String get privacyDeleteTitle => 'Request account deletion?';

  @override
  String get privacyDeleteWarning =>
      'We will verify the request using your registered email. Your account and associated personal data will be deleted or de-identified, except records we must retain for legal, accounting, fraud-prevention or active contractual reasons.';

  @override
  String get privacyReason => 'Reason (optional)';

  @override
  String get privacyReasonHint => 'Tell us anything we should know';

  @override
  String get privacyConfirm =>
      'I understand this requests permanent deletion of my account and associated data.';

  @override
  String get privacyKeepAccount => 'Keep account';

  @override
  String get privacySubmit => 'Submit request';

  @override
  String get privacyReceivedMessage =>
      'Deletion request received. We will verify it by email.';

  @override
  String get privacyCancelledMessage => 'Deletion request cancelled.';

  @override
  String get privacyYourPrivacy => 'Your privacy';

  @override
  String get privacySummary =>
      'See what Kaysons Logistics collects, why it is used, how long it is kept, and how to contact us.';

  @override
  String get privacyReadPolicy => 'Read privacy policy';

  @override
  String get privacyWebRequest => 'Request from the web';

  @override
  String get privacyWebSummary =>
      'You can also request deletion after uninstalling the app. The public form does not require a login.';

  @override
  String get privacyOpenWeb => 'Open deletion webpage';

  @override
  String get privacyHelp => 'Need help?';

  @override
  String privacyContact(String email) {
    return 'Contact $email for privacy, access, correction or account questions.';
  }

  @override
  String get privacyEmailSupport => 'Email support';

  @override
  String get privacyReceivedTitle => 'Deletion request received';

  @override
  String privacyStatusRequested(String status, String date) {
    return 'Status: $status\nRequested: $date';
  }

  @override
  String get privacyThirtyDays =>
      'We normally complete a verified request within 30 days. We may contact your registered email to confirm identity or explain records that must be retained.';

  @override
  String get privacyCancelRequest => 'Cancel deletion request';

  @override
  String get privacyDeleteData => 'Delete account and data';

  @override
  String get privacyDeleteSummary =>
      'Submit a permanent deletion request for your Kaysons Logistics account and associated personal data. Verification protects your account from unauthorized requests.';

  @override
  String get privacyRequestDeletion => 'Request account deletion';

  @override
  String get privacyVerifying => 'Identity verification';

  @override
  String get privacyApproved => 'Approved for deletion';

  @override
  String get privacyPending => 'Pending review';

  @override
  String get privacyLoadError => 'Could not load deletion status';

  @override
  String get privacyOpenError => 'Could not open the webpage';

  @override
  String get privacySubmitError => 'Could not submit request';

  @override
  String get privacyCancelError => 'Could not cancel request';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get tpWelcome => 'Welcome';

  @override
  String tpWelcomeName(String name) {
    return 'Welcome, $name';
  }

  @override
  String get tpLatestBids => 'Latest bids';

  @override
  String get tpNoOpenBidsSoon => 'No open bids right now. Check back soon.';

  @override
  String get tpWonBids => 'Won bids';

  @override
  String get tpQuickOptions => 'Quick options';

  @override
  String get tpVehicles => 'Vehicles';

  @override
  String get tpAddOrDelete => 'Add or delete';

  @override
  String get tpBidHistory => 'Bid history';

  @override
  String get tpWonAndActive => 'Won and active';

  @override
  String get tpDrivers => 'Drivers';

  @override
  String get tpPerVehicle => 'Per vehicle';

  @override
  String get tpWonBidsEmpty =>
      'Won bids will appear here after a freight is awarded.';

  @override
  String get tpAwaitingVehicle => 'Awaiting vehicle';

  @override
  String get tpClosed => 'Closed';

  @override
  String tpTimeHoursLeft(int hours, int minutes) {
    return '$hours hr $minutes min left';
  }

  @override
  String tpTimeMinutesLeft(int minutes) {
    return '$minutes min left';
  }

  @override
  String tpCasesWeight(String cases, String weight) {
    return '$cases Cases · $weight MT';
  }

  @override
  String get tpOpenBids => 'Open bids';

  @override
  String tpOpenBidsCount(int count) {
    return 'Open bids ($count)';
  }

  @override
  String get tpNoOpenBids => 'No open bids right now.';

  @override
  String tpBidHistoryCount(int count) {
    return 'Bid history ($count)';
  }

  @override
  String get tpStatusCompleted => 'Status: Completed';

  @override
  String get tpStatusOpen => 'Status: Open';

  @override
  String get tpStatusExpired => 'Status: Expired';

  @override
  String get tpStatusAwarded => 'Status: Awarded';

  @override
  String get tpStatusDispatched => 'Status: Dispatched';

  @override
  String get tpStatusLocked => 'Status: Locked';

  @override
  String get tpStatusClosed => 'Status: Closed';

  @override
  String get tpMyFleet => 'My fleet';

  @override
  String get tpManageVehicles => 'Manage vehicles';

  @override
  String get tpManageFleetPrompt =>
      'Add, edit, or delete vehicle and driver details';

  @override
  String get tpNoWonBids =>
      'You haven\'t won any bids yet. Slide over to Bids.';

  @override
  String get opsNewRequirement => 'New requirement';

  @override
  String get opsEditRequirement => 'Edit requirement';

  @override
  String get opsDeliveryTracking => 'Delivery tracking';

  @override
  String get opsLockFreight => 'Lock freight';

  @override
  String get opsTransporters => 'Transporters';

  @override
  String get opsVehicles => 'Vehicles';

  @override
  String get opsRefresh => 'Refresh';

  @override
  String get opsPublishBid => 'Publish bid';

  @override
  String get opsActiveBids => 'Active bids';

  @override
  String get opsInTransit => 'In transit';

  @override
  String get opsLockedDone => 'Locked / done';

  @override
  String get opsVehicleChecks => 'Vehicle checks';

  @override
  String get opsNotifications => 'Notifications';

  @override
  String get opsFrom => 'From';

  @override
  String get opsStopsOptional => 'Stops in between (optional)';

  @override
  String get opsStopCity => 'Stop city';

  @override
  String get opsStopCases => 'Stop cases';

  @override
  String get opsStopMetricTon => 'Stop metric ton';

  @override
  String get opsFinalDestination => 'Final destination';

  @override
  String get opsDestinationCity => 'Destination city';

  @override
  String get opsDestinationCases => 'Destination cases';

  @override
  String get opsDestinationMetricTon => 'Destination metric ton';

  @override
  String get opsBaseFreight => 'Base Freight';

  @override
  String get opsOpenForBidding => 'Open for bidding';

  @override
  String get opsCompeteUntilClose =>
      'Transporters compete on price until the close time.';

  @override
  String get opsAssignDirectlyHint =>
      'Assign directly to one transporter, skip the bidding window.';

  @override
  String get opsOpensAt => 'Opens at';

  @override
  String get opsClosesAt => 'Closes at';

  @override
  String get opsInternalCallingBid => 'Reference price (optional)';

  @override
  String get opsReferencePriceHint =>
      'Used for estimates. Do not enter a confidential target price here.';

  @override
  String get opsAnonymousInternalBid => 'Anonymous internal bid';

  @override
  String get opsHideCallingBid => 'Hide your calling bid from transporters';

  @override
  String get opsTransporterAccess => 'Transporter access';

  @override
  String get opsWhoCanBid => 'Who can bid?';

  @override
  String get opsAllApprovedTransporters => 'All approved transporters';

  @override
  String get opsAllApprovedHint =>
      'Everyone approved can see this bid, except anyone you exclude.';

  @override
  String get opsOnlySelectedTransporters => 'Only selected transporters';

  @override
  String get opsOnlySelectedHint =>
      'Only the transporters you choose can see and bid.';

  @override
  String get opsChooseTransporters => 'Choose transporters';

  @override
  String get opsExcludeTransporters => 'Exclude transporters (optional)';

  @override
  String get opsExcludeHint => 'Checked transporters cannot see this bid.';

  @override
  String opsSelectedCount(int count) {
    return 'Selected: $count';
  }

  @override
  String opsExcludedCount(int count) {
    return 'Excluded: $count';
  }

  @override
  String get opsChooseAtLeastOneTransporter =>
      'Choose at least one transporter for a selected-only bid.';

  @override
  String get opsReviewAndPublish => 'Review & publish';

  @override
  String get opsVisibleTo => 'Visible to';

  @override
  String get opsBidCloses => 'Bidding closes';

  @override
  String get opsPrefer => 'Prefer';

  @override
  String get opsBlock => 'Block';

  @override
  String get opsAssignToTransporter => 'Assign to transporter';

  @override
  String get opsAssignDispatch => 'Assign & dispatch';

  @override
  String get opsNoApprovedTransporters => 'No approved transporters yet.';

  @override
  String get opsSaveChanges => 'Save changes';

  @override
  String get opsSaved => 'Saved';

  @override
  String get opsTrack => 'Track';

  @override
  String get opsLockInvoices => 'Invoices';

  @override
  String get opsEditStopsWindow => 'Edit stops / extend window';

  @override
  String get opsAddAnotherInvoice => 'Add another invoice';

  @override
  String get opsAddAnotherGrBilty => 'Add another GR / Bilty';

  @override
  String get opsAddAnotherEwayBill => 'Add another e-way bill';

  @override
  String get opsRemoveDocument => 'Remove document number';

  @override
  String get tpGoodsInvoiceChallanNumbers => 'Goods invoice / challan numbers';

  @override
  String get tpMultiStopDocumentsHint =>
      'Add invoice, GR/Bilty and e-way bill references under each delivery destination below.';

  @override
  String tpAddReference(String label) {
    return 'Add $label';
  }

  @override
  String tpRemoveReference(String label) {
    return 'Remove $label';
  }

  @override
  String get opsAddCharge => 'Add charge';

  @override
  String get opsRemoveInvoice => 'Remove invoice';

  @override
  String get opsRemoveCharge => 'Remove charge';

  @override
  String get opsWholeDispatch => 'Whole dispatch';

  @override
  String get opsConfirmArrived => 'Confirm arrived';

  @override
  String get opsWrongDetails => 'Wrong details';

  @override
  String get opsOptionalNote => 'Optional note';

  @override
  String get opsWhatIsWrong => 'What is wrong?';

  @override
  String get opsVehicleConfirmed => 'Vehicle confirmed';

  @override
  String get opsIssueRaised => 'Issue raised';

  @override
  String get opsLocationUpdated => 'Location updated';

  @override
  String get opsDeliveryCheckSaved => 'Delivery check saved';

  @override
  String get opsCancel => 'Cancel';

  @override
  String get opsSave => 'Save';

  @override
  String get opsPhotoUploaded => 'Photo uploaded';

  @override
  String get opsProfileUpdated => 'Profile updated';

  @override
  String get opsInvoiceLocked => 'Invoice details saved.';

  @override
  String get opsFromToRequired => 'From and To are required';

  @override
  String get opsPickTransporter =>
      'Pick a transporter to assign the freight to';

  @override
  String get opsAmountsValid => 'Freight amounts must be valid numbers';

  @override
  String get opsAmountsPositive => 'Freight amounts must be greater than zero';

  @override
  String get opsCloseAfterOpen => 'Close time must be after open time';

  @override
  String get opsInvalidPhone =>
      'Phone number must be a valid Indian mobile number';

  @override
  String get opsCouldNotReadImage => 'Could not read selected image';

  @override
  String tpCouldNotLoadDrivers(String error) {
    return 'Could not load drivers: $error';
  }

  @override
  String get tpDeleteDriverQuestion => 'Delete driver?';

  @override
  String get tpThisDriver => 'This driver';

  @override
  String tpDriverWillBeRemoved(String name) {
    return '$name will be removed.';
  }

  @override
  String get tpCancel => 'Cancel';

  @override
  String get tpDelete => 'Delete';

  @override
  String get tpAddDriver => 'Add driver';

  @override
  String get tpDriverNameMissing => 'Driver name missing';

  @override
  String tpPhoneLicence(String phone, String licence) {
    return '$phone · Licence $licence';
  }

  @override
  String get tpEdit => 'Edit';

  @override
  String get tpNoDrivers => 'No drivers added yet';

  @override
  String get tpAddDriversHint =>
      'Add drivers separately, then choose one during dispatch.';

  @override
  String get tpEnterDriverName => 'Enter driver name';

  @override
  String get tpEnterValidPhone => 'Enter a valid Indian mobile number';

  @override
  String tpSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get tpEditDriver => 'Edit driver';

  @override
  String get tpDriverName => 'Driver name';

  @override
  String get tpDriverPhone => 'Driver phone';

  @override
  String get tpLicenceNumber => 'Licence number';

  @override
  String get tpSaving => 'Saving...';

  @override
  String get tpSaveDriver => 'Save driver';

  @override
  String tpCouldNotLoadVehicles(String error) {
    return 'Could not load vehicles: $error';
  }

  @override
  String get tpThisVehicle => 'this vehicle';

  @override
  String get tpDeleteVehicleQuestion => 'Delete vehicle?';

  @override
  String tpVehicleWillBeRemoved(String vehicle) {
    return '$vehicle will be removed from your fleet records.';
  }

  @override
  String get tpVehicleDeleted => 'Vehicle deleted';

  @override
  String tpDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get tpAddVehicle => 'Add vehicle';

  @override
  String get tpVehicleNumberMissing => 'Vehicle number missing';

  @override
  String get tpTruck => 'Truck';

  @override
  String get tpRc => 'RC';

  @override
  String get tpInsurance => 'Insurance';

  @override
  String get tpStatus => 'Status';

  @override
  String get tpActive => 'Active';

  @override
  String get tpNoVehicles => 'No vehicles added yet';

  @override
  String get tpAddVehiclesHint =>
      'Add each truck with RC, insurance, and capacity details.';

  @override
  String get tpEnterVehicleNumber => 'Enter a vehicle number';

  @override
  String get tpEditVehicle => 'Edit vehicle';

  @override
  String get tpVehicleNumber => 'Vehicle number';

  @override
  String get tpVehicleType => 'Vehicle type';

  @override
  String get tpTruckTrailer => 'Truck / Trailer';

  @override
  String get tpCapacityCases => 'Capacity Cases';

  @override
  String get tpMetricMt => 'Metric MT';

  @override
  String get tpRcNumber => 'RC number';

  @override
  String get tpInsuranceNumber => 'Insurance number';

  @override
  String get tpSaveVehicle => 'Save vehicle';

  @override
  String tpCases(String cases) {
    return '$cases Cases';
  }

  @override
  String get opsNoActiveBids => 'No active bids right now.';

  @override
  String get opsAllBids => 'All bids';

  @override
  String get opsNoBidsDate => 'No bids found for this date window.';

  @override
  String get opsFleetDeliveries => 'Fleet - deliveries';

  @override
  String get opsNoAwardedFreights => 'No awarded freights yet.';

  @override
  String get opsNoDataDate => 'No data in this date window.';

  @override
  String get opsManagerProfile => 'Manager profile';

  @override
  String get opsName => 'Name';

  @override
  String get opsPhoneNumber => 'Phone number';

  @override
  String get opsAreaCovered => 'Area covered';

  @override
  String get opsNoTransporters => 'No transporters found.';

  @override
  String get opsNoVehicles => 'No vehicles found.';

  @override
  String get opsDeliveryStages => 'Delivery stages';

  @override
  String get opsVehicleVerification => 'Vehicle verification';

  @override
  String get opsWaitingVehicle =>
      'Waiting for transporter to submit vehicle and driver details.';

  @override
  String get opsNotSubmittedYet => 'Not submitted yet';

  @override
  String get opsNoSubContractors => 'No sub-contractors recorded';

  @override
  String get opsSubContractorOptional => 'Sub-contractor, if used';

  @override
  String get opsLorryNumber => 'Lorry number';

  @override
  String get opsDriverName => 'Driver name';

  @override
  String get opsDriverPhone => 'Driver phone';

  @override
  String get opsInvoiceNumber => 'Invoice number';

  @override
  String get opsGrBiltyNumber => 'GR / Bilty number';

  @override
  String get opsEwayBillNumber => 'E-way bill number';

  @override
  String get opsCurrentLocation => 'Current location';

  @override
  String get opsReceiverName => 'Receiver name';

  @override
  String get opsReceiverPhone => 'Receiver phone';

  @override
  String get opsGrNumber => 'GR number';

  @override
  String get opsAdditionalBillReason => 'Additional bill reason';

  @override
  String get opsExtendWindow => 'Extend bidding window';

  @override
  String get opsStopsInBetween => 'Stops in between';

  @override
  String get opsAccessLegend =>
      'Green = preferred; red = blocked; unselected = open';

  @override
  String get opsDispatchTeam => 'Dispatch team';

  @override
  String get opsAssignRegisteredUsers =>
      'Assign registered users to track your accepted deliveries.';

  @override
  String get opsInvoicesGrLinking => 'Invoice records';

  @override
  String get opsAddEveryInvoice =>
      'Record the invoice, GR/Bilty and e-way bill details for this trip. This does not create a PDF or send a bill.';

  @override
  String get opsCompletedInvoiceNote =>
      'Delivery is complete. You can still add missing invoice details; the delivery will stay complete.';

  @override
  String get opsSavedInvoiceDetails => 'Saved invoice details';

  @override
  String get opsInvoiceReadOnlyNote =>
      'These are the recorded details for this trip. Ask an office administrator to correct a saved invoice.';

  @override
  String get opsInvoiceUnavailable =>
      'Invoice entry is unavailable for this bid. Ask an office administrator to review it.';

  @override
  String get opsCharges => 'Charges';

  @override
  String get opsChargeScopeHint =>
      'Choose whether each charge applies to the whole dispatch or one invoice.';

  @override
  String get opsBiddersLive => 'Bidders (live)';

  @override
  String get opsNoBidsReceived => 'No bids received yet.';

  @override
  String get opsWinnerConfirmed =>
      'Winner confirmed. Transporter will now dispatch.';

  @override
  String get opsTransporterFillDetails =>
      'The transporter will fill in vehicle, driver and pickup details themselves from their Fleet tab.';

  @override
  String get opsTotalRequirement => 'Total requirement';

  @override
  String get opsAgreedFreightPositive =>
      'Enter a positive agreed freight for direct assignment';

  @override
  String get opsVehicleListUnavailable =>
      'Vehicle list is unavailable until manager read access is applied.';

  @override
  String get adminAllBids => 'All bids';

  @override
  String get adminNoBids => 'No bids found for this date window.';

  @override
  String get adminCases => 'Cases';

  @override
  String get adminStatus => 'Status';

  @override
  String get adminCompleted => 'Completed';

  @override
  String get adminOpen => 'Open';

  @override
  String get adminClosed => 'Closed';

  @override
  String get adminNotifications => 'Notifications';

  @override
  String get adminAlertNotifications => 'Alert notifications';

  @override
  String get adminNotificationsHelp =>
      'Review POD, document mismatch, vehicle, and registration alerts from one place.';

  @override
  String get adminResolved => 'Resolved';

  @override
  String get adminAll => 'All';

  @override
  String get adminNoNotifications => 'No notifications here right now.';

  @override
  String get adminProfileUpdated => 'Profile updated';

  @override
  String get adminUpdateFailed => 'Update failed';

  @override
  String get adminAccountantProfile => 'Accountant profile';

  @override
  String get adminAdminProfile => 'Admin profile';

  @override
  String get adminAccountantProfileHelp =>
      'This profile is used across the accounting workspace.';

  @override
  String get adminProfileHelp =>
      'This profile is used across your logistics workspace.';

  @override
  String get adminLogout => 'Log out';

  @override
  String get adminAccountDetails => 'Account details';

  @override
  String get adminFullName => 'Full name';

  @override
  String get adminNameHint => 'Admin name';

  @override
  String get adminSaving => 'Saving...';

  @override
  String get adminSaveProfile => 'Save profile';

  @override
  String get adminUserManagement => 'User management';

  @override
  String get adminPending => 'Pending';

  @override
  String get adminNoUsers => 'No users';

  @override
  String get adminUnnamed => 'Unnamed';

  @override
  String get adminNoManager => 'No manager';

  @override
  String get adminRole => 'Role';

  @override
  String get adminRoleAdmin => 'Admin';

  @override
  String get adminError => 'Error';

  @override
  String get adminReportsTo => 'Reports to';

  @override
  String get adminAccessHelp =>
      'Access follows the assigned role and approval status.';

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminReject => 'Reject';

  @override
  String get adminRemove => 'Remove';

  @override
  String get adminManagerFirst =>
      'Create or approve a logistics manager first.';

  @override
  String get adminRoleUpdateFailed => 'Role update failed';

  @override
  String get adminManagerUpdateFailed => 'Manager update failed';

  @override
  String get adminDeleteFailed => 'Delete failed';

  @override
  String get adminRefresh => 'Refresh';

  @override
  String get adminTotalFreight => 'Total freight';

  @override
  String get adminMetricMt => 'Metric MT';

  @override
  String get adminPendingAcknowledgements => 'Pending acknowledgements';

  @override
  String get adminTransporterVolume => 'Transporter business volume';

  @override
  String get adminCompanyFreight => 'Company-wise freight';

  @override
  String get adminTownFreight => 'Town-wise freight';

  @override
  String get adminNoDataRange => 'No data in range';

  @override
  String get adminDelayAlerts => 'Delay and acknowledgement alerts';

  @override
  String get adminNoDelayedRows => 'No delayed dispatch rows in this window.';

  @override
  String get adminDelayed => 'delayed';

  @override
  String get adminDays => 'day(s)';

  @override
  String get adminInvoice => 'Invoice';

  @override
  String get adminAck => 'ack';

  @override
  String get adminUnassigned => 'Unassigned';

  @override
  String get tpProfileAndLogout => 'Profile and logout';

  @override
  String tpBidPlaced(String amount) {
    return 'Bid placed: ₹$amount. You can revise it until bidding closes.';
  }

  @override
  String tpBidFailed(String error) {
    return 'Bid failed: $error';
  }

  @override
  String get tpBidClosed => 'Bid closed';

  @override
  String get tpBidClosedHint =>
      'Only bids you win stay available in your past bids and fleet.';

  @override
  String get tpBackToOpenBids => 'Back to open bids';

  @override
  String get tpLiveBidding => 'Live Bidding';

  @override
  String get tpNoBidsYet => 'No bids yet';

  @override
  String tpAnonymousBidders(int count) {
    return '$count anonymous bidder(s)';
  }

  @override
  String get tpPlacing => 'Placing...';

  @override
  String get tpUpdateBid => 'Update bid';

  @override
  String get tpPlaceBid => 'Place bid';

  @override
  String get tpYou => 'You';

  @override
  String get tpAnonymousBidder => 'Anonymous bidder';

  @override
  String get tpTransporterBrowserHint =>
      'Manage bids, fleet, and delivery updates from the browser.';

  @override
  String tpBiddingOpenHours(int hours, int minutes) {
    return 'Bidding open · ${hours}h ${minutes}m left';
  }

  @override
  String tpBiddingOpenMinutes(int minutes) {
    return 'Bidding open · ${minutes}m left';
  }

  @override
  String get tpBiddingOpen => 'Bidding open';

  @override
  String get tpYouWonBid => 'You won this bid';

  @override
  String get tpAwardedOther => 'Awarded to another transporter';

  @override
  String tpDeliveryStatus(String status) {
    return 'Delivery $status';
  }

  @override
  String get tpTrackArrow => 'Track →';

  @override
  String get tpProfileUpdated => 'Profile updated';

  @override
  String tpUpdateFailed(String error) {
    return 'Update failed: $error';
  }

  @override
  String get tpAdmin => 'Admin';

  @override
  String get tpLogisticsManager => 'Logistics Manager';

  @override
  String get tpDispatchManager => 'Dispatch Manager';

  @override
  String get tpSignedIn => 'Signed in';

  @override
  String get tpProfileDetails => 'Profile details';

  @override
  String get tpProfileDetailsHint =>
      'Keep your contact and compliance information updated for smoother bidding and dispatch.';

  @override
  String get tpBusinessInformation => 'Business information';

  @override
  String get tpFullName => 'Full name';

  @override
  String get tpBusinessName => 'Business name';

  @override
  String get tpPhoneNumber => 'Phone number';

  @override
  String get tpBusinessRegistration => 'Business registration no.';

  @override
  String get tpSavingEllipsis => 'Saving…';

  @override
  String get tpSaveChanges => 'Save changes';

  @override
  String get tpAccountOverview => 'Account overview';

  @override
  String get tpAccountOverviewHint =>
      'Quick reference for your account status and sign-in details.';

  @override
  String get tpNotAvailable => 'Not available';

  @override
  String get tpRole => 'Role';

  @override
  String get tpUnknown => 'Unknown';

  @override
  String get tpPassword => 'Password';

  @override
  String get tpManagedCredentials => 'Managed from login credentials';

  @override
  String get tpFleetSetup => 'Fleet setup';

  @override
  String get tpFleetSetupHint =>
      'Add vehicles and drivers separately for dispatch.';

  @override
  String get tpActions => 'Actions';

  @override
  String get tpActionsHint =>
      'Common account options and quick maintenance tasks.';

  @override
  String get tpReloadProfile => 'Reload profile data';

  @override
  String get tpFetchLatest => 'Fetch latest account information';

  @override
  String get tpPrivacyDeletion => 'Privacy policy and account deletion';

  @override
  String get tpSignOutHint => 'Sign out and return to welcome screen';

  @override
  String get tpProfileSyncHint =>
      'Profile changes reflect across the mobile app and web dashboard.';

  @override
  String get tpEditableProfile => 'Editable profile';

  @override
  String get tpDeliveryProgress => 'Delivery progress';

  @override
  String get tpDeliveredCaps => 'DELIVERED';

  @override
  String get tpInTransitCaps => 'IN TRANSIT';

  @override
  String get tpPickupCaps => 'PICKUP';

  @override
  String get tpDispatchedCaps => 'DISPATCHED';

  @override
  String get tpLmConfirmedVehicle => 'LM confirmed vehicle';

  @override
  String get tpLmRaisedIssue => 'LM raised an issue';

  @override
  String get tpWaitingVehicleConfirmation =>
      'Waiting for LM vehicle confirmation';

  @override
  String get tpVehicleConfirmedHint =>
      'The logistics manager has confirmed the vehicle details.';

  @override
  String get tpDispatchUpdateHint =>
      'Update the dispatch details and submit again for confirmation.';

  @override
  String get tpDispatchChangeHint =>
      'If you change dispatch details, LM will need to confirm again.';

  @override
  String get tpCouldNotReadImage => 'Could not read selected image';

  @override
  String get tpPhotoUploaded => 'Photo uploaded';

  @override
  String tpUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get tpUploading => 'Uploading...';

  @override
  String get tpUploadedPreview => 'Uploaded - tap to preview';

  @override
  String get tpSaved => 'Saved';

  @override
  String get tpDispatched => 'Dispatched';

  @override
  String get tpLorryProof => 'Lorry proof';

  @override
  String get tpAddLorryPhotograph => 'Add Lorry Photograph';

  @override
  String get tpUploadLorryPhoto => 'Upload a photo of Lorry';

  @override
  String get tpDriverProof => 'Driver proof';

  @override
  String get tpEnterDriverPhotograph => 'Enter Driver Photograph';

  @override
  String get tpUploadDriverPhoto => 'Upload a photo of Driver';

  @override
  String get tpDriverAadhaarPhoto => 'Enter Driver Aadhaar Card Photograph';

  @override
  String get tpUploadDriverAadhaar => 'Upload a photo of Driver Aadhaar Card';

  @override
  String get tpSubmitLorryDetails => 'Submit Lorry details';

  @override
  String get tpSelectVehicle => 'Select vehicle';

  @override
  String get tpNoSavedVehicles => 'No saved vehicles yet';

  @override
  String get tpChooseSavedFleet => 'Choose from your saved fleet';

  @override
  String get tpUseSavedVehicle =>
      'Use a vehicle you already added, or add one first.';

  @override
  String get tpRcSaved => 'RC saved';

  @override
  String get tpInsuranceSaved => 'Insurance saved';

  @override
  String get tpSelectDriver => 'Select driver';

  @override
  String get tpNoSavedDrivers => 'No saved drivers yet';

  @override
  String get tpChooseSavedDrivers => 'Choose from your saved drivers';

  @override
  String get tpUseSavedDriver =>
      'Use a driver you already added, or add one first.';

  @override
  String get tpLicenceSaved => 'Licence saved';

  @override
  String get tpPickup => 'Pickup';

  @override
  String get tpPickupDetails => 'Pickup details';

  @override
  String get tpEnterDriverPhone => 'Enter Driver Phone Number';

  @override
  String get tpEnterSitePhoto => 'Enter on site photo';

  @override
  String get tpUploadPresence => 'Upload a photo of your presence';

  @override
  String get tpSubmitPickup => 'Submit Pickup details';

  @override
  String get tpInTransit => 'In Transit';

  @override
  String get tpSubcontractors => 'Sub-contractors';

  @override
  String get tpAddContractor => 'Add contractor';

  @override
  String get tpVerificationDetails => 'Verification details';

  @override
  String get tpGrBiltyNumber => 'GR / Bilty number';

  @override
  String get tpEwayBillNumber => 'E-way bill number';

  @override
  String get tpCurrentLocation => 'Current location';

  @override
  String get tpEnterCurrentLocation => 'Enter the current location';

  @override
  String get tpLocationUpdated => 'Location updated';

  @override
  String tpLocationUpdateFailed(String error) {
    return 'Location update failed: $error';
  }

  @override
  String get tpUpdating => 'Updating...';

  @override
  String get tpUpdateLocation => 'Update location';

  @override
  String get tpTransitSitePhoto => 'Transit site photo';

  @override
  String get tpShareTransit => 'Share transit details';

  @override
  String tpContractorNumber(int number) {
    return 'Contractor $number';
  }

  @override
  String get tpName => 'Name';

  @override
  String get tpPhone => 'Phone';

  @override
  String get tpFrom => 'From';

  @override
  String get tpTo => 'To';

  @override
  String get tpSelectCity => 'Select city';

  @override
  String get tpDelivered => 'Delivered';

  @override
  String get tpDeliverySiteDetails => 'Enter Delivery site details';

  @override
  String get tpEnterReceiverName => 'Enter receiver name';

  @override
  String get tpEnterReceiverNumber => 'Enter Receiver number';

  @override
  String get tpEnterGrNumber => 'Enter GR Number';

  @override
  String get tpEnterEwayBill => 'Enter E-way Bill Number';

  @override
  String get tpProofOfDelivery => 'Proof of Delivery (POD)';

  @override
  String get tpUploadPod => 'Upload Proof of Delivery';

  @override
  String get tpAdditionalChargesReason =>
      'Additional Charges (if any) — bill reason';

  @override
  String get tpLoadingChargesHint => 'e.g. loading charges';

  @override
  String get tpBillPhoto => 'Bill photo';

  @override
  String get tpUploadBillPhoto => 'Upload a photo of the bill';

  @override
  String get tpOnSitePhoto => 'On-site photo';

  @override
  String get tpShareDelivery => 'Share delivery details';

  @override
  String get opsInvoice => 'Invoice';

  @override
  String get opsLrOptional => 'LR number (optional)';

  @override
  String get opsDeliveryRefOptional => 'Delivery reference (optional)';

  @override
  String get opsPartyName => 'Party name';

  @override
  String get opsTown => 'Town';

  @override
  String get opsCases => 'Cases';

  @override
  String get opsMetricTons => 'Metric tons';

  @override
  String get opsFreightShare => 'Freight share';

  @override
  String get opsBillDate => 'Bill date';

  @override
  String get opsDispatchDate => 'Dispatch date';

  @override
  String get opsVehicleNumber => 'Vehicle number';

  @override
  String get opsVehicleType => 'Vehicle type';

  @override
  String get opsChargeType => 'Charge type';

  @override
  String get opsAmount => 'Amount';

  @override
  String get opsChargeAllocation => 'Charge allocation';

  @override
  String get opsRemarksOptional => 'Remarks (optional)';

  @override
  String get opsSubmitLockFreight => 'Save invoice details';

  @override
  String get opsSaving => 'Saving...';

  @override
  String get opsWorkDetails => 'Work details';

  @override
  String get opsManagerIdentityHint =>
      'Only manager identity and operating area are needed here.';

  @override
  String get opsAccount => 'Account';

  @override
  String get opsTransporterOwnershipHint =>
      'Business, GST and vehicle ownership stay with transporters.';

  @override
  String get opsEmail => 'Email';

  @override
  String get opsRole => 'Role';

  @override
  String get opsStatus => 'Status';

  @override
  String get opsAllTransporters => 'All transporters';

  @override
  String get opsReadOnlyTransporters =>
      'Read-only list for assigning bids and checking responsibility.';

  @override
  String get opsAllVehicles => 'All vehicles';

  @override
  String get opsVehiclesOwnedHint =>
      'Vehicles are added by transporters. Managers verify what arrives.';

  @override
  String get opsAdd => 'Add';

  @override
  String get opsEdit => 'Edit';

  @override
  String get opsPhone => 'Phone';

  @override
  String get opsConfirm => 'Confirm';

  @override
  String get opsRaiseIssue => 'Raise issue';

  @override
  String get opsConfirmVehicleArrived => 'Confirm vehicle arrived';

  @override
  String get opsRaiseVehicleIssue => 'Raise vehicle issue';

  @override
  String get opsLastDriverLocation => 'Last location from driver update';

  @override
  String get opsLorryPhoto => 'Lorry photo';

  @override
  String get opsDriverPhoto => 'Driver photo';

  @override
  String get opsDriverAadhaar => 'Driver Aadhaar';

  @override
  String get opsInvoicePhoto => 'Invoice photo';

  @override
  String get opsSitePhoto => 'Site photo';

  @override
  String get opsProofOfDelivery => 'Proof of delivery';

  @override
  String get opsBillPhoto => 'Bill photo';

  @override
  String get opsTollTax => 'Toll tax';

  @override
  String get opsPointCharge => 'Point charge';

  @override
  String get opsExtraFreight => 'Extra freight';

  @override
  String get opsLabour => 'Labour';

  @override
  String get opsDetention => 'Detention';

  @override
  String get opsOutRoute => 'Out route';

  @override
  String get opsDeduction => 'Deduction';

  @override
  String get opsOther => 'Other';

  @override
  String get opsDispatched => 'Dispatched';

  @override
  String get opsPickup => 'Pickup';

  @override
  String get opsDelivered => 'Delivered';

  @override
  String get adminFreightLedger => 'Freight ledger';

  @override
  String get adminExportReports => 'Export reports';

  @override
  String get adminTransporterMonthlyCsv => 'Transporter monthly CSV';

  @override
  String get adminPlaceWiseCsv => 'Place-wise CSV';

  @override
  String get adminInvoiceWiseCsv => 'Invoice-wise CSV';

  @override
  String get adminPodPendingCsv => 'POD pending CSV';

  @override
  String get adminVehicleTonnageCsv => 'Vehicle tonnage CSV';

  @override
  String get adminRouteWiseCsv => 'Route-wise CSV';

  @override
  String get adminUploadCsv => 'Upload CSV';

  @override
  String get adminEntry => 'Entry';

  @override
  String get adminCompany => 'Company';

  @override
  String get adminDestinationPlace => 'Destination / Place';

  @override
  String get adminInvoiceNumber => 'Invoice Number';

  @override
  String get adminSearchInvoice => 'Search invoice';

  @override
  String get adminFilters => 'Filters';

  @override
  String get adminClearFilters => 'Clear filters';

  @override
  String get adminPodAcknowledgement => 'POD / Acknowledgement';

  @override
  String get adminVehicleTonnage => 'Vehicle tonnage';

  @override
  String get adminPlaceSearch => 'Place search';

  @override
  String get adminOriginDestinationParty => 'Origin, destination, party';

  @override
  String get adminEwayNumber => 'E-way Bill Number';

  @override
  String get adminSearchEway => 'Search e-way bill';

  @override
  String get adminDelayedOnly => 'Delayed only';

  @override
  String get adminLatePod => 'Late POD';

  @override
  String get adminNoLedgerRows => 'No ledger rows match this filter.';

  @override
  String get adminSummaryReport => 'Summary report';

  @override
  String get adminPlace => 'Place';

  @override
  String get adminRoute => 'Route';

  @override
  String get adminVehicle => 'Vehicle';

  @override
  String get adminShowing => 'Showing';

  @override
  String get adminOf => 'of';

  @override
  String get adminRows => 'Rows';

  @override
  String get adminPreviousPage => 'Previous page';

  @override
  String get adminNextPage => 'Next page';

  @override
  String get adminScrollLeft => 'Scroll table left';

  @override
  String get adminScrollRight => 'Scroll table right';

  @override
  String get adminInvoiceRows => 'Invoice rows';

  @override
  String get adminTrips => 'Trips';

  @override
  String get adminVehicles => 'Vehicles';

  @override
  String get adminFreight => 'Freight';

  @override
  String get adminPodPending => 'POD pending';

  @override
  String get adminOverview => 'Overview';

  @override
  String get adminLoadingPeriod => 'Loading latest period';

  @override
  String get adminLatestPeriod => 'Latest period';

  @override
  String get adminDashboardLoadFailed => 'Could not load the dashboard';

  @override
  String get adminRetry => 'Retry';

  @override
  String get adminDashboard => 'Admin Dashboard';

  @override
  String get adminWelcome => 'Welcome';

  @override
  String get adminMonth => 'Month';

  @override
  String get adminFrom => 'From';

  @override
  String get adminTo => 'To';

  @override
  String get adminLatest => 'Latest';

  @override
  String get adminMetricTons => 'Metric Tons';

  @override
  String get adminReviewValue => 'Review Value';

  @override
  String get adminNeedsAttention => 'Needs Attention';

  @override
  String get adminNoPriorityItems => 'No priority review items in this period.';

  @override
  String get adminOpenLedger => 'Open ledger';

  @override
  String get adminAskClawd => 'Ask Clawd';

  @override
  String get adminReviewRoutes => 'Review routes';

  @override
  String get adminOpenClawd => 'Open Clawd';

  @override
  String get adminDocumentReview =>
      'Review document-wise before payment release.';

  @override
  String get adminExtraChargesHelp =>
      'Check labour, detention, toll, and out-route charges.';

  @override
  String get adminTransporterPerformance => 'Transporter Performance';

  @override
  String get adminRoutesDestinations => 'Routes & Destinations';

  @override
  String get adminFreightPerMt => 'Freight/MT';

  @override
  String get adminTrends => 'Trends';

  @override
  String get adminHide => 'Hide';

  @override
  String get adminShow => 'Show';

  @override
  String get adminNoTrendData => 'No trend data';

  @override
  String get adminTrendHelp =>
      'Daily freight trend is available here for a deeper view.';

  @override
  String get adminNoRecordsPeriod => 'No records in this period.';

  @override
  String get adminNoDashboardData => 'No dashboard data found.';

  @override
  String get adminAckFollowUp => 'needs acknowledgement follow-up';

  @override
  String get adminDuplicateEwayRisk => 'duplicate e-way risk(s)';

  @override
  String get adminRouteCostSpike => 'route cost spike(s)';

  @override
  String get adminCompareFreight => 'needs freight/MT comparison';

  @override
  String get adminHighExtraCharge => 'high extra charge case(s)';

  @override
  String get adminSelectMonth => 'Select month';

  @override
  String get adminYear => 'Year';

  @override
  String get adminEdit => 'Edit';

  @override
  String get adminBill => 'Bill';

  @override
  String get adminDispatch => 'Dispatch';

  @override
  String get adminDelay => 'Delay';

  @override
  String get adminInvoiceShort => 'Invoice';

  @override
  String get adminInvoiceCount => 'Inv Count';

  @override
  String get adminEway => 'E-way';

  @override
  String get adminEwayCount => 'E-way Count';

  @override
  String get adminDel => 'DEL';

  @override
  String get adminParty => 'Party';

  @override
  String get adminPartyCount => 'Party Count';

  @override
  String get adminOrigin => 'Origin';

  @override
  String get adminTown => 'Town';

  @override
  String get adminTon => 'Ton';

  @override
  String get adminCapacity => 'Capacity';

  @override
  String get adminDispatchGr => 'Dispatch GR';

  @override
  String get adminTotal => 'Total';

  @override
  String get adminBalance => 'Balance';

  @override
  String get adminPodStatus => 'POD Status';

  @override
  String get adminPodDate => 'POD Date';

  @override
  String get adminPodFile => 'POD File';

  @override
  String get adminPodRemark => 'POD Remark';

  @override
  String get adminReceivedBy => 'Received By';

  @override
  String get adminPodReceived => 'POD Received';

  @override
  String get adminFreightPerCase => 'Freight/Case';

  @override
  String get adminAvgFreightPerMt => 'Avg Freight/MT';

  @override
  String get adminTransporterBreakup => 'Transporter breakup';

  @override
  String get adminTransporterSummary => 'Transporter summary';

  @override
  String get tpLocationHint => 'e.g. Ambala bypass';

  @override
  String get tpApproved => 'Approved';

  @override
  String get tpPending => 'Pending';

  @override
  String get tpRejected => 'Rejected';

  @override
  String get tpSuspended => 'Suspended';

  @override
  String get tpCompleted => 'Completed';

  @override
  String get tpAwarded => 'Awarded';

  @override
  String get tpLocked => 'Locked';

  @override
  String get adminCompanyRequired => 'Company is required.';

  @override
  String get adminUploadLedgerCsv => 'Upload ledger CSV';

  @override
  String get adminCompanySheetName => 'Company / sheet name *';

  @override
  String get adminUploadTag => 'Upload tag';

  @override
  String get adminCsvHelp =>
      'Use an Excel-exported CSV. Direct .xlsx upload is not enabled in this version.';

  @override
  String get adminCancel => 'Cancel';

  @override
  String get adminChooseCsv => 'Choose CSV';

  @override
  String get adminCsvUploadComplete => 'CSV upload complete';

  @override
  String get adminRowsImported => 'Rows imported';

  @override
  String get adminChargeRowsImported => 'Charge rows imported';

  @override
  String get adminMissingTransportersHelp =>
      'These transporters were not found in approved profiles, so their names were saved in remarks:';

  @override
  String get adminMore => 'more';

  @override
  String get adminDone => 'Done';

  @override
  String get adminLedgerEntry => 'Ledger entry';

  @override
  String get adminCompanyRequiredLabel => 'Company *';

  @override
  String get adminBranch => 'Branch';

  @override
  String get adminVehicleType => 'Vehicle type';

  @override
  String get adminDispatchGrBilty => 'Dispatch GR/Bilty';

  @override
  String get adminAckStatus => 'Ack status';

  @override
  String get adminReceived => 'Received';

  @override
  String get adminNotRequired => 'Not required';

  @override
  String get adminPodReceivedDate => 'POD received yyyy-mm-dd';

  @override
  String get adminInvoiceLines => 'Invoice lines';

  @override
  String get adminCharges => 'Charges';

  @override
  String get adminSettlement => 'Settlement';

  @override
  String get adminLastMonthBalance => 'Last month balance';

  @override
  String get adminPayment => 'Payment';

  @override
  String get adminSettlementDeduction => 'Settlement deduction';

  @override
  String get adminSettlementRemarks => 'Settlement remarks';

  @override
  String get adminProducts => 'Products';

  @override
  String get adminOptionalProductsHelp =>
      'Optional product/category quantities for Karnal-style reports.';

  @override
  String get adminRemarks => 'Remarks';

  @override
  String get adminSaveEntry => 'Save entry';

  @override
  String get adminEditLedgerEntry => 'Edit ledger entry';

  @override
  String get adminDestinationSummary => 'Destination summary';

  @override
  String get adminRouteSummary => 'Route summary';

  @override
  String get adminVehicleTonnageSummary => 'Vehicle tonnage summary';

  @override
  String get adminClearMonth => 'Clear month';

  @override
  String get adminLoadFailed => 'Load failed';

  @override
  String get adminExportFailed => 'Export failed';

  @override
  String get adminCsvUploadFailed => 'CSV upload failed';

  @override
  String get adminCompanyTownRequired =>
      'Company and first invoice town are required.';

  @override
  String get adminPodFileReadFailed => 'Could not read POD file';

  @override
  String get adminAdd => 'Add';

  @override
  String get adminOverrideApproval =>
      'Admin approval to override duplicate lock';

  @override
  String get adminReasonRemarkRequired => 'Reason and remark are mandatory.';

  @override
  String get adminRemoveInvoice => 'Remove invoice';

  @override
  String get adminVehicleCapacity => 'Vehicle capacity';

  @override
  String get adminKind => 'Kind';

  @override
  String get adminRemoveCharge => 'Remove charge';

  @override
  String get adminRemoveProduct => 'Remove product';

  @override
  String get adminTransporterWiseSummary => 'Transporter-wise summary';

  @override
  String get adminPlaceWiseSummary => 'Place-wise summary';

  @override
  String get adminRouteWiseSummary => 'Route-wise summary';

  @override
  String get adminTransporterSummaryHelp =>
      'Trips, distinct vehicles, freight efficiency, and POD status by transporter.';

  @override
  String get adminPlaceSummaryHelp =>
      'Destination movement with transporter breakup.';

  @override
  String get adminRouteSummaryHelp => 'From-to route freight comparison.';

  @override
  String get adminVehicleSummaryHelp => 'Vehicle capacity category usage.';

  @override
  String get adminDestination => 'Destination';

  @override
  String get adminFromTo => 'From → To';

  @override
  String get adminCategory => 'Category';

  @override
  String get adminEwayBill => 'E-way bill';

  @override
  String get adminDelRef => 'DEL ref';

  @override
  String get adminLrGr => 'LR/GR';

  @override
  String get adminTownRequired => 'Town *';

  @override
  String get adminBillDate => 'Bill date yyyy-mm-dd';

  @override
  String get adminDispatchDate => 'Dispatch date yyyy-mm-dd';

  @override
  String get adminFreightShare => 'Freight share';

  @override
  String get adminAmount => 'Amount';

  @override
  String get adminChargeRemarks => 'Charge remarks';

  @override
  String get adminProduct => 'Product';

  @override
  String get adminPodFileUploaded => 'POD file uploaded';

  @override
  String get adminDuplicateFreightLock => 'Duplicate freight lock';

  @override
  String get adminOnlyAdminOverride =>
      'Only an admin can approve duplicate freight.';

  @override
  String get adminOverrideReason => 'Override reason *';

  @override
  String get adminOverrideRemark => 'Override remark *';

  @override
  String get adminSaveFailed => 'Save failed';

  @override
  String get opsDeliveryPodStatus => 'Delivery and POD status';

  @override
  String opsDestinationsDelivered(int count, int total) {
    return '$count of $total destinations delivered';
  }

  @override
  String opsDeliveryProofsUploaded(int count, int total) {
    return '$count of $total delivery proofs uploaded';
  }

  @override
  String get opsGoodsInvoiceChallans => 'Goods invoices / challans';

  @override
  String get opsGrBilty => 'GR / Bilty';

  @override
  String get opsEwayBills => 'E-way bills';

  @override
  String get opsViewDeliveryProof => 'View proof of delivery';

  @override
  String get opsDeliveryProofPending => 'Proof of delivery pending';

  @override
  String get opsDuplicateDeliveryDestination =>
      'That delivery destination is already on the route.';

  @override
  String get opsEnterDeliveryQuantities =>
      'Enter valid cases and metric tonnes for every delivery.';

  @override
  String get opsBidAwardedDuringEdit =>
      'This bid was awarded while you were editing it.';

  @override
  String get opsRemoveDestination => 'Remove destination';

  @override
  String get uiQuickLinks => 'Quick links';

  @override
  String get uiViewDirectory => 'View directory';

  @override
  String get uiReadOnlyList => 'Read-only list';
}
