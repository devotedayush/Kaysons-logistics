// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get language => 'भाषा';

  @override
  String get english => 'English';

  @override
  String get hindi => 'हिंदी';

  @override
  String get profile => 'प्रोफ़ाइल';

  @override
  String get accountPrivacy => 'खाता और गोपनीयता';

  @override
  String get logout => 'लॉग आउट करें';

  @override
  String get home => 'होम';

  @override
  String get more => 'अधिक';

  @override
  String get moreOptions => 'अधिक विकल्प';

  @override
  String get dashboard => 'डैशबोर्ड';

  @override
  String get users => 'उपयोगकर्ता';

  @override
  String get bids => 'बोलियाँ';

  @override
  String get ledger => 'खाता बही';

  @override
  String get fleet => 'वाहन और ड्राइवर';

  @override
  String get dispatch => 'डिस्पैच';

  @override
  String get insights => 'विश्लेषण';

  @override
  String get analytics => 'विश्लेषण';

  @override
  String get today => 'आज';

  @override
  String dateWindowDays(int days) {
    return '$days दिन';
  }

  @override
  String get dateWindowCustomDates => 'अपनी तारीखें चुनें';

  @override
  String get dateWindowFrom => 'शुरू';

  @override
  String get dateWindowTo => 'अंत';

  @override
  String get dateWindowUsePreset => 'तय अवधि चुनें';

  @override
  String get deliveries => 'डिलीवरी';

  @override
  String get adminConsole => 'एडमिन पैनल';

  @override
  String get adminSubtitle =>
      'उपयोगकर्ताओं और माल ढुलाई की गतिविधि पर नज़र रखें।';

  @override
  String get accountant => 'लेखाकार';

  @override
  String get accountantSubtitle => 'खाता बही, रिपोर्ट और Clawd विश्लेषण देखें।';

  @override
  String get logisticsManager => 'लॉजिस्टिक्स प्रबंधक';

  @override
  String get logisticsSubtitle =>
      'माल ढुलाई प्रकाशित करें, बोलियाँ और डिलीवरी देखें।';

  @override
  String get dispatchManager => 'डिस्पैच प्रबंधक';

  @override
  String get dispatchSubtitle =>
      'स्वीकृत डिलीवरी और माल की आवाजाही पर नज़र रखें।';

  @override
  String get transporter => 'ट्रांसपोर्टर';

  @override
  String get transporterSubtitle =>
      'माल ढुलाई खोजें, बोलियाँ और वाहनों की प्रगति देखें।';

  @override
  String get welcomeTitle => 'कोई माल ढुलाई न छूटे';

  @override
  String get welcomeSubtitle => 'नई माल ढुलाई की नियमित जानकारी पाएँ';

  @override
  String get loginEmailMobile => 'ईमेल / मोबाइल से लॉग इन करें';

  @override
  String get registerWithUs => 'पंजीकरण करें';

  @override
  String get or => 'या';

  @override
  String get welcomeBack => 'वापसी पर स्वागत है';

  @override
  String get signInInstruction =>
      'अपने पंजीकृत ईमेल और पासवर्ड से साइन इन करें।';

  @override
  String get email => 'ईमेल';

  @override
  String get password => 'पासवर्ड';

  @override
  String get signIn => 'साइन इन करें';

  @override
  String get signingIn => 'साइन इन हो रहा है...';

  @override
  String get noAccountRegister => 'खाता नहीं है? पंजीकरण करें';

  @override
  String get loginFailed => 'साइन इन नहीं हो पाया';

  @override
  String get clawd => 'Clawd';

  @override
  String get next => 'आगे';

  @override
  String stepOfFive(int step) {
    return 'चरण $step / 5';
  }

  @override
  String get alreadyAccount => 'पहले से खाता है?';

  @override
  String get goBack => 'वापस जाएँ';

  @override
  String get registerEmailTitle => 'अपना ईमेल पता दर्ज करें';

  @override
  String get registerEmailSubtitle =>
      'ईमेल से साइन इन करें। यदि आपका Kaysons खाता नहीं है, तो हम नया खाता बनाएँगे।';

  @override
  String get yourEmail => 'आपका ईमेल';

  @override
  String get createPassword => 'पासवर्ड बनाएँ';

  @override
  String get passwordLength => 'कम से कम 8 अक्षर होने चाहिए';

  @override
  String get newPassword => 'नया पासवर्ड';

  @override
  String get confirmPassword => 'नए पासवर्ड की पुष्टि करें';

  @override
  String get termsAgreement =>
      'मैं Kaysons की उपयोग शर्तों और गोपनीयता नीति से सहमत हूँ तथा Kaysons से ईमेल प्राप्त करना चाहता/चाहती हूँ।';

  @override
  String get registerNameTitle => 'आपका नाम क्या है?';

  @override
  String get registerProfileSubtitle =>
      'इससे प्लेटफ़ॉर्म पर आपकी प्रोफ़ाइल बनाई जाएगी।';

  @override
  String get fullName => 'पूरा नाम';

  @override
  String get companyName => 'कंपनी का नाम';

  @override
  String get registerBankTitle => 'आपके बैंक का नाम क्या है?';

  @override
  String get accountHolderName => 'बैंक खाते में दर्ज पूरा नाम';

  @override
  String get bankAccountNumber => 'बैंक खाता संख्या';

  @override
  String get photoUpload => 'फ़ोटो अपलोड करें';

  @override
  String get imageReadFailed => 'चुनी गई फ़ोटो पढ़ी नहीं जा सकी';

  @override
  String get registerContactTitle => 'हम आपसे कैसे संपर्क करें?';

  @override
  String get mobileNumber => 'मोबाइल नंबर';

  @override
  String get landlineNumber => 'कंपनी का लैंडलाइन नंबर';

  @override
  String get businessRegistrationNumber => 'व्यवसाय पंजीकरण संख्या';

  @override
  String get lorryRcNumber => 'लॉरी आरसी नंबर';

  @override
  String get lorryInsuranceNumber => 'लॉरी बीमा नंबर';

  @override
  String get gstinOptional => 'जीएसटीआईएन (वैकल्पिक)';

  @override
  String get registerRestart =>
      'पंजीकरण फिर शुरू करें: ईमेल या पासवर्ड नहीं मिला';

  @override
  String get invalidMobile => 'सही 10 अंकों का भारतीय मोबाइल नंबर दर्ज करें';

  @override
  String get registrationFailed => 'पंजीकरण नहीं हो पाया';

  @override
  String get contactSubtitle =>
      'अपना नंबर और व्यवसाय की जानकारी दें। जमा करने के बाद आप साइन इन हो जाएँगे।';

  @override
  String get submit => 'जमा करें';

  @override
  String get submitting => 'जमा किया जा रहा है...';

  @override
  String get uploadBlankCheque => 'खाली चेक की फ़ोटो अपलोड करें';

  @override
  String get selectedReplace => 'चुना गया - बदलने के लिए टैप करें';

  @override
  String get privacyDeleteTitle => 'खाता हटाने का अनुरोध करें?';

  @override
  String get privacyDeleteWarning =>
      'हम आपके पंजीकृत ईमेल से अनुरोध की पुष्टि करेंगे। कानूनी, लेखा, धोखाधड़ी रोकथाम या चालू अनुबंध के लिए ज़रूरी रिकॉर्ड छोड़कर, आपका खाता और उससे जुड़ा व्यक्तिगत डेटा हटाया जाएगा या पहचान रहित किया जाएगा।';

  @override
  String get privacyReason => 'कारण (वैकल्पिक)';

  @override
  String get privacyReasonHint => 'यदि कुछ बताना चाहते हैं तो यहाँ लिखें';

  @override
  String get privacyConfirm =>
      'मैं समझता/समझती हूँ कि इससे मेरे खाते और संबंधित डेटा को स्थायी रूप से हटाने का अनुरोध होगा।';

  @override
  String get privacyKeepAccount => 'खाता रखें';

  @override
  String get privacySubmit => 'अनुरोध जमा करें';

  @override
  String get privacyReceivedMessage =>
      'खाता हटाने का अनुरोध मिला। हम ईमेल से पुष्टि करेंगे।';

  @override
  String get privacyCancelledMessage => 'खाता हटाने का अनुरोध रद्द किया गया।';

  @override
  String get privacyYourPrivacy => 'आपकी गोपनीयता';

  @override
  String get privacySummary =>
      'जानें कि Kaysons Logistics कौन सा डेटा एकत्र करता है, उसका उपयोग और संग्रह अवधि क्या है, और हमसे कैसे संपर्क करें।';

  @override
  String get privacyReadPolicy => 'गोपनीयता नीति पढ़ें';

  @override
  String get privacyWebRequest => 'वेब से अनुरोध करें';

  @override
  String get privacyWebSummary =>
      'ऐप हटाने के बाद भी खाता हटाने का अनुरोध किया जा सकता है। सार्वजनिक फ़ॉर्म के लिए लॉग इन ज़रूरी नहीं है।';

  @override
  String get privacyOpenWeb => 'खाता हटाने का वेबपेज खोलें';

  @override
  String get privacyHelp => 'मदद चाहिए?';

  @override
  String privacyContact(String email) {
    return 'गोपनीयता, पहुँच, सुधार या खाते से जुड़े सवालों के लिए $email पर संपर्क करें।';
  }

  @override
  String get privacyEmailSupport => 'सहायता को ईमेल करें';

  @override
  String get privacyReceivedTitle => 'खाता हटाने का अनुरोध मिला';

  @override
  String privacyStatusRequested(String status, String date) {
    return 'स्थिति: $status\nअनुरोध की तारीख: $date';
  }

  @override
  String get privacyThirtyDays =>
      'पुष्टि किए गए अनुरोध सामान्यतः 30 दिनों में पूरे होते हैं। पहचान की पुष्टि या रखे जाने वाले रिकॉर्ड समझाने के लिए हम आपके पंजीकृत ईमेल पर संपर्क कर सकते हैं।';

  @override
  String get privacyCancelRequest => 'खाता हटाने का अनुरोध रद्द करें';

  @override
  String get privacyDeleteData => 'खाता और डेटा हटाएँ';

  @override
  String get privacyDeleteSummary =>
      'अपने Kaysons Logistics खाते और संबंधित व्यक्तिगत डेटा को स्थायी रूप से हटाने का अनुरोध करें। पहचान की पुष्टि आपके खाते को अनधिकृत अनुरोधों से बचाती है।';

  @override
  String get privacyRequestDeletion => 'खाता हटाने का अनुरोध करें';

  @override
  String get privacyVerifying => 'पहचान की पुष्टि';

  @override
  String get privacyApproved => 'हटाने की स्वीकृति मिली';

  @override
  String get privacyPending => 'समीक्षा लंबित';

  @override
  String get privacyLoadError => 'खाता हटाने की स्थिति नहीं खुल सकी';

  @override
  String get privacyOpenError => 'वेबपेज नहीं खुल सका';

  @override
  String get privacySubmitError => 'अनुरोध जमा नहीं हो सका';

  @override
  String get privacyCancelError => 'अनुरोध रद्द नहीं हो सका';

  @override
  String get showPassword => 'पासवर्ड दिखाएँ';

  @override
  String get hidePassword => 'पासवर्ड छिपाएँ';

  @override
  String get tpWelcome => 'स्वागत है';

  @override
  String tpWelcomeName(String name) {
    return 'स्वागत है, $name';
  }

  @override
  String get tpLatestBids => 'नई बोलियाँ';

  @override
  String get tpNoOpenBidsSoon =>
      'अभी कोई खुली बोली नहीं है। थोड़ी देर बाद फिर देखें।';

  @override
  String get tpWonBids => 'जीती हुई बोलियाँ';

  @override
  String get tpQuickOptions => 'त्वरित विकल्प';

  @override
  String get tpVehicles => 'वाहन';

  @override
  String get tpAddOrDelete => 'जोड़ें या हटाएँ';

  @override
  String get tpBidHistory => 'बोली का इतिहास';

  @override
  String get tpWonAndActive => 'जीती और चालू बोलियाँ';

  @override
  String get tpDrivers => 'ड्राइवर';

  @override
  String get tpPerVehicle => 'प्रत्येक वाहन के लिए';

  @override
  String get tpWonBidsEmpty =>
      'माल ढुलाई आवंटित होने पर जीती हुई बोलियाँ यहाँ दिखेंगी।';

  @override
  String get tpAwaitingVehicle => 'वाहन की प्रतीक्षा है';

  @override
  String get tpClosed => 'बंद';

  @override
  String tpTimeHoursLeft(int hours, int minutes) {
    return '$hours घंटा $minutes मिनट शेष';
  }

  @override
  String tpTimeMinutesLeft(int minutes) {
    return '$minutes मिनट शेष';
  }

  @override
  String tpCasesWeight(String cases, String weight) {
    return '$cases पेटियाँ · $weight MT';
  }

  @override
  String get tpOpenBids => 'खुली बोलियाँ';

  @override
  String tpOpenBidsCount(int count) {
    return 'खुली बोलियाँ ($count)';
  }

  @override
  String get tpNoOpenBids => 'अभी कोई खुली बोली नहीं है।';

  @override
  String tpBidHistoryCount(int count) {
    return 'बोली का इतिहास ($count)';
  }

  @override
  String get tpStatusCompleted => 'स्थिति: पूरी हुई';

  @override
  String get tpStatusOpen => 'स्थिति: खुली';

  @override
  String get tpStatusExpired => 'स्थिति: समय समाप्त';

  @override
  String get tpStatusAwarded => 'स्थिति: आवंटित';

  @override
  String get tpStatusDispatched => 'स्थिति: रवाना';

  @override
  String get tpStatusLocked => 'स्थिति: लॉक';

  @override
  String get tpStatusClosed => 'स्थिति: बंद';

  @override
  String get tpMyFleet => 'मेरे वाहन';

  @override
  String get tpManageVehicles => 'वाहन प्रबंधित करें';

  @override
  String get tpManageFleetPrompt =>
      'वाहन और ड्राइवर की जानकारी जोड़ें, बदलें या हटाएँ';

  @override
  String get tpNoWonBids => 'आपने अभी कोई बोली नहीं जीती है। बोलियाँ देखें।';

  @override
  String get opsNewRequirement => 'नई आवश्यकता';

  @override
  String get opsEditRequirement => 'आवश्यकता संपादित करें';

  @override
  String get opsDeliveryTracking => 'डिलीवरी ट्रैकिंग';

  @override
  String get opsLockFreight => 'फ्रेट लॉक करें';

  @override
  String get opsTransporters => 'ट्रांसपोर्टर';

  @override
  String get opsVehicles => 'वाहन';

  @override
  String get opsRefresh => 'रीफ़्रेश करें';

  @override
  String get opsPublishBid => 'बोली प्रकाशित करें';

  @override
  String get opsActiveBids => 'सक्रिय बोलियाँ';

  @override
  String get opsInTransit => 'रास्ते में';

  @override
  String get opsLockedDone => 'लॉक / पूरा';

  @override
  String get opsVehicleChecks => 'वाहन जाँच';

  @override
  String get opsNotifications => 'सूचनाएँ';

  @override
  String get opsFrom => 'कहाँ से';

  @override
  String get opsStopsOptional => 'बीच के पड़ाव (वैकल्पिक)';

  @override
  String get opsStopCity => 'पड़ाव का शहर';

  @override
  String get opsStopCases => 'पड़ाव के केस';

  @override
  String get opsStopMetricTon => 'पड़ाव के मीट्रिक टन';

  @override
  String get opsFinalDestination => 'अंतिम गंतव्य';

  @override
  String get opsDestinationCity => 'गंतव्य शहर';

  @override
  String get opsDestinationCases => 'गंतव्य के केस';

  @override
  String get opsDestinationMetricTon => 'गंतव्य के मीट्रिक टन';

  @override
  String get opsBaseFreight => 'मूल भाड़ा';

  @override
  String get opsOpenForBidding => 'बोली के लिए खुला';

  @override
  String get opsCompeteUntilClose =>
      'बंद होने के समय तक ट्रांसपोर्टर कीमत पर बोली लगाएंगे।';

  @override
  String get opsAssignDirectlyHint =>
      'बोली प्रक्रिया छोड़कर सीधे एक ट्रांसपोर्टर को सौंपें।';

  @override
  String get opsOpensAt => 'खुलने का समय';

  @override
  String get opsClosesAt => 'बंद होने का समय';

  @override
  String get opsInternalCallingBid => 'संदर्भ कीमत (वैकल्पिक)';

  @override
  String get opsReferencePriceHint =>
      'अनुमान के लिए। यहाँ गोपनीय लक्ष्य कीमत न डालें।';

  @override
  String get opsAnonymousInternalBid => 'गोपनीय आंतरिक बोली';

  @override
  String get opsHideCallingBid => 'अपनी संदर्भ बोली ट्रांसपोर्टरों से छिपाएँ';

  @override
  String get opsTransporterAccess => 'ट्रांसपोर्टर की पहुँच';

  @override
  String get opsWhoCanBid => 'कौन बोली लगा सकता है?';

  @override
  String get opsAllApprovedTransporters => 'सभी स्वीकृत ट्रांसपोर्टर';

  @override
  String get opsAllApprovedHint =>
      'स्वीकृत सभी ट्रांसपोर्टर यह बोली देख सकते हैं, सिवाय जिन्हें आप हटाएँ।';

  @override
  String get opsOnlySelectedTransporters => 'केवल चुने गए ट्रांसपोर्टर';

  @override
  String get opsOnlySelectedHint =>
      'केवल आपके चुने ट्रांसपोर्टर यह बोली देख और लगा सकते हैं।';

  @override
  String get opsChooseTransporters => 'ट्रांसपोर्टर चुनें';

  @override
  String get opsExcludeTransporters => 'ट्रांसपोर्टर हटाएँ (वैकल्पिक)';

  @override
  String get opsExcludeHint => 'चिह्नित ट्रांसपोर्टर यह बोली नहीं देख पाएँगे।';

  @override
  String opsSelectedCount(int count) {
    return 'चुने गए: $count';
  }

  @override
  String opsExcludedCount(int count) {
    return 'हटाए गए: $count';
  }

  @override
  String get opsChooseAtLeastOneTransporter =>
      'केवल चुने गए विकल्प के लिए कम से कम एक ट्रांसपोर्टर चुनें।';

  @override
  String get opsReviewAndPublish => 'जाँचें और प्रकाशित करें';

  @override
  String get opsVisibleTo => 'इन्हें दिखेगी';

  @override
  String get opsBidCloses => 'बोली बंद होगी';

  @override
  String get opsPrefer => 'प्राथमिकता दें';

  @override
  String get opsBlock => 'रोकें';

  @override
  String get opsAssignToTransporter => 'ट्रांसपोर्टर को सौंपें';

  @override
  String get opsAssignDispatch => 'सौंपें और डिस्पैच करें';

  @override
  String get opsNoApprovedTransporters =>
      'अभी कोई स्वीकृत ट्रांसपोर्टर नहीं है।';

  @override
  String get opsSaveChanges => 'बदलाव सहेजें';

  @override
  String get opsSaved => 'सहेजा गया';

  @override
  String get opsTrack => 'ट्रैक करें';

  @override
  String get opsLockInvoices => 'इनवॉइस';

  @override
  String get opsEditStopsWindow => 'पड़ाव / बोली अवधि संपादित करें';

  @override
  String get opsAddAnotherInvoice => 'एक और इनवॉइस जोड़ें';

  @override
  String get opsAddAnotherGrBilty => 'एक और GR / बिल्टी जोड़ें';

  @override
  String get opsAddAnotherEwayBill => 'एक और ई-वे बिल जोड़ें';

  @override
  String get opsRemoveDocument => 'दस्तावेज़ नंबर हटाएं';

  @override
  String get tpGoodsInvoiceChallanNumbers => 'माल के इनवॉइस / चालान नंबर';

  @override
  String get tpMultiStopDocumentsHint =>
      'हर डिलीवरी स्थान के नीचे इनवॉइस, GR/बिल्टी और ई-वे बिल के नंबर जोड़ें।';

  @override
  String tpAddReference(String label) {
    return '$label जोड़ें';
  }

  @override
  String tpRemoveReference(String label) {
    return '$label हटाएं';
  }

  @override
  String get opsAddCharge => 'शुल्क जोड़ें';

  @override
  String get opsRemoveInvoice => 'इनवॉइस हटाएँ';

  @override
  String get opsRemoveCharge => 'शुल्क हटाएँ';

  @override
  String get opsWholeDispatch => 'पूरा डिस्पैच';

  @override
  String get opsConfirmArrived => 'पहुँचने की पुष्टि करें';

  @override
  String get opsWrongDetails => 'गलत विवरण';

  @override
  String get opsOptionalNote => 'वैकल्पिक टिप्पणी';

  @override
  String get opsWhatIsWrong => 'क्या गलत है?';

  @override
  String get opsVehicleConfirmed => 'वाहन की पुष्टि हुई';

  @override
  String get opsIssueRaised => 'समस्या दर्ज हुई';

  @override
  String get opsLocationUpdated => 'स्थान अपडेट हुआ';

  @override
  String get opsDeliveryCheckSaved => 'डिलीवरी जाँच सहेजी गई';

  @override
  String get opsCancel => 'रद्द करें';

  @override
  String get opsSave => 'सहेजें';

  @override
  String get opsPhotoUploaded => 'फ़ोटो अपलोड हुई';

  @override
  String get opsProfileUpdated => 'प्रोफ़ाइल अपडेट हुई';

  @override
  String get opsInvoiceLocked => 'इनवॉइस की जानकारी सेव हो गई।';

  @override
  String get opsFromToRequired => 'कहाँ से और कहाँ तक भरना ज़रूरी है';

  @override
  String get opsPickTransporter => 'फ्रेट सौंपने के लिए ट्रांसपोर्टर चुनें';

  @override
  String get opsAmountsValid => 'भाड़े की राशि सही संख्या में भरें';

  @override
  String get opsAmountsPositive => 'भाड़े की राशि शून्य से अधिक होनी चाहिए';

  @override
  String get opsCloseAfterOpen =>
      'बंद होने का समय खुलने के समय के बाद होना चाहिए';

  @override
  String get opsInvalidPhone => 'सही भारतीय मोबाइल नंबर भरें';

  @override
  String get opsCouldNotReadImage => 'चुनी गई तस्वीर पढ़ी नहीं जा सकी';

  @override
  String tpCouldNotLoadDrivers(String error) {
    return 'ड्राइवर लोड नहीं हो पाए: $error';
  }

  @override
  String get tpDeleteDriverQuestion => 'ड्राइवर हटाएँ?';

  @override
  String get tpThisDriver => 'यह ड्राइवर';

  @override
  String tpDriverWillBeRemoved(String name) {
    return '$name को हटाया जाएगा।';
  }

  @override
  String get tpCancel => 'रद्द करें';

  @override
  String get tpDelete => 'हटाएँ';

  @override
  String get tpAddDriver => 'ड्राइवर जोड़ें';

  @override
  String get tpDriverNameMissing => 'ड्राइवर का नाम नहीं है';

  @override
  String tpPhoneLicence(String phone, String licence) {
    return '$phone · लाइसेंस $licence';
  }

  @override
  String get tpEdit => 'बदलें';

  @override
  String get tpNoDrivers => 'अभी कोई ड्राइवर नहीं जोड़ा गया है';

  @override
  String get tpAddDriversHint =>
      'ड्राइवर अलग से जोड़ें, फिर डिस्पैच के समय चुनें।';

  @override
  String get tpEnterDriverName => 'ड्राइवर का नाम दर्ज करें';

  @override
  String get tpEnterValidPhone => 'मान्य भारतीय मोबाइल नंबर दर्ज करें';

  @override
  String tpSaveFailed(String error) {
    return 'सहेजना विफल रहा: $error';
  }

  @override
  String get tpEditDriver => 'ड्राइवर की जानकारी बदलें';

  @override
  String get tpDriverName => 'ड्राइवर का नाम';

  @override
  String get tpDriverPhone => 'ड्राइवर का फोन';

  @override
  String get tpLicenceNumber => 'लाइसेंस नंबर';

  @override
  String get tpSaving => 'सहेजा जा रहा है...';

  @override
  String get tpSaveDriver => 'ड्राइवर सहेजें';

  @override
  String tpCouldNotLoadVehicles(String error) {
    return 'वाहन लोड नहीं हो पाए: $error';
  }

  @override
  String get tpThisVehicle => 'यह वाहन';

  @override
  String get tpDeleteVehicleQuestion => 'वाहन हटाएँ?';

  @override
  String tpVehicleWillBeRemoved(String vehicle) {
    return '$vehicle को आपके वाहन रिकॉर्ड से हटाया जाएगा।';
  }

  @override
  String get tpVehicleDeleted => 'वाहन हटा दिया गया';

  @override
  String tpDeleteFailed(String error) {
    return 'हटाना विफल रहा: $error';
  }

  @override
  String get tpAddVehicle => 'वाहन जोड़ें';

  @override
  String get tpVehicleNumberMissing => 'वाहन नंबर नहीं है';

  @override
  String get tpTruck => 'ट्रक';

  @override
  String get tpRc => 'आरसी';

  @override
  String get tpInsurance => 'बीमा';

  @override
  String get tpStatus => 'स्थिति';

  @override
  String get tpActive => 'सक्रिय';

  @override
  String get tpNoVehicles => 'अभी कोई वाहन नहीं जोड़ा गया है';

  @override
  String get tpAddVehiclesHint =>
      'हर ट्रक की आरसी, बीमा और क्षमता की जानकारी जोड़ें।';

  @override
  String get tpEnterVehicleNumber => 'वाहन नंबर दर्ज करें';

  @override
  String get tpEditVehicle => 'वाहन की जानकारी बदलें';

  @override
  String get tpVehicleNumber => 'वाहन नंबर';

  @override
  String get tpVehicleType => 'वाहन का प्रकार';

  @override
  String get tpTruckTrailer => 'ट्रक / ट्रेलर';

  @override
  String get tpCapacityCases => 'क्षमता (पेटियाँ)';

  @override
  String get tpMetricMt => 'क्षमता (MT)';

  @override
  String get tpRcNumber => 'आरसी नंबर';

  @override
  String get tpInsuranceNumber => 'बीमा नंबर';

  @override
  String get tpSaveVehicle => 'वाहन सहेजें';

  @override
  String tpCases(String cases) {
    return '$cases पेटियाँ';
  }

  @override
  String get opsNoActiveBids => 'अभी कोई सक्रिय बोली नहीं है।';

  @override
  String get opsAllBids => 'सभी बोलियाँ';

  @override
  String get opsNoBidsDate => 'चुनी गई अवधि में कोई बोली नहीं मिली।';

  @override
  String get opsFleetDeliveries => 'फ्लीट - डिलीवरी';

  @override
  String get opsNoAwardedFreights => 'अभी कोई आवंटित फ्रेट नहीं है।';

  @override
  String get opsNoDataDate => 'चुनी गई अवधि में कोई डेटा नहीं है।';

  @override
  String get opsManagerProfile => 'मैनेजर प्रोफ़ाइल';

  @override
  String get opsName => 'नाम';

  @override
  String get opsPhoneNumber => 'फ़ोन नंबर';

  @override
  String get opsAreaCovered => 'कार्य क्षेत्र';

  @override
  String get opsNoTransporters => 'कोई ट्रांसपोर्टर नहीं मिला।';

  @override
  String get opsNoVehicles => 'कोई वाहन नहीं मिला।';

  @override
  String get opsDeliveryStages => 'डिलीवरी के चरण';

  @override
  String get opsVehicleVerification => 'वाहन सत्यापन';

  @override
  String get opsWaitingVehicle =>
      'ट्रांसपोर्टर से वाहन और चालक का विवरण मिलने की प्रतीक्षा है।';

  @override
  String get opsNotSubmittedYet => 'अभी जमा नहीं हुआ';

  @override
  String get opsNoSubContractors => 'कोई उपठेकेदार दर्ज नहीं है';

  @override
  String get opsSubContractorOptional => 'उपठेकेदार, यदि हो';

  @override
  String get opsLorryNumber => 'लॉरी नंबर';

  @override
  String get opsDriverName => 'चालक का नाम';

  @override
  String get opsDriverPhone => 'चालक का फ़ोन';

  @override
  String get opsInvoiceNumber => 'इनवॉइस नंबर';

  @override
  String get opsGrBiltyNumber => 'GR / बिल्टी नंबर';

  @override
  String get opsEwayBillNumber => 'ई-वे बिल नंबर';

  @override
  String get opsCurrentLocation => 'वर्तमान स्थान';

  @override
  String get opsReceiverName => 'प्राप्तकर्ता का नाम';

  @override
  String get opsReceiverPhone => 'प्राप्तकर्ता का फ़ोन';

  @override
  String get opsGrNumber => 'GR नंबर';

  @override
  String get opsAdditionalBillReason => 'अतिरिक्त बिल का कारण';

  @override
  String get opsExtendWindow => 'बोली की अवधि बढ़ाएँ';

  @override
  String get opsStopsInBetween => 'बीच के पड़ाव';

  @override
  String get opsAccessLegend =>
      'हरा = प्राथमिकता; लाल = रोका गया; बिना चयन = खुला';

  @override
  String get opsDispatchTeam => 'डिस्पैच टीम';

  @override
  String get opsAssignRegisteredUsers =>
      'स्वीकृत डिलीवरी ट्रैक करने के लिए पंजीकृत उपयोगकर्ताओं को नियुक्त करें।';

  @override
  String get opsInvoicesGrLinking => 'इनवॉइस रिकॉर्ड';

  @override
  String get opsAddEveryInvoice =>
      'इस यात्रा के इनवॉइस, GR/बिल्टी और ई-वे बिल की जानकारी दर्ज करें। इससे PDF नहीं बनती और बिल नहीं भेजा जाता।';

  @override
  String get opsCompletedInvoiceNote =>
      'डिलीवरी पूरी हो चुकी है। आप छूटी हुई इनवॉइस जानकारी अब भी जोड़ सकते हैं; डिलीवरी पूरी ही रहेगी।';

  @override
  String get opsSavedInvoiceDetails => 'सेव की गई इनवॉइस जानकारी';

  @override
  String get opsInvoiceReadOnlyNote =>
      'यह इस यात्रा की दर्ज जानकारी है। सेव की गई इनवॉइस में सुधार के लिए ऑफिस एडमिन से कहें।';

  @override
  String get opsInvoiceUnavailable =>
      'इस बिड के लिए इनवॉइस दर्ज नहीं की जा सकती। ऑफिस एडमिन से जाँच करवाएँ।';

  @override
  String get opsCharges => 'शुल्क';

  @override
  String get opsChargeScopeHint =>
      'चुनें कि शुल्क पूरे डिस्पैच पर लागू है या एक इनवॉइस पर।';

  @override
  String get opsBiddersLive => 'बोलीदाता (लाइव)';

  @override
  String get opsNoBidsReceived => 'अभी कोई बोली प्राप्त नहीं हुई।';

  @override
  String get opsWinnerConfirmed =>
      'विजेता की पुष्टि हुई। ट्रांसपोर्टर अब डिस्पैच करेगा।';

  @override
  String get opsTransporterFillDetails =>
      'ट्रांसपोर्टर अपनी फ्लीट स्क्रीन में वाहन, चालक और पिकअप विवरण भरेगा।';

  @override
  String get opsTotalRequirement => 'कुल आवश्यकता';

  @override
  String get opsAgreedFreightPositive =>
      'सीधे आवंटन के लिए शून्य से अधिक सहमत भाड़ा भरें';

  @override
  String get opsVehicleListUnavailable =>
      'मैनेजर को पढ़ने की अनुमति मिलने तक वाहन सूची उपलब्ध नहीं है।';

  @override
  String get adminAllBids => 'सभी बोलियाँ';

  @override
  String get adminNoBids => 'इस अवधि में कोई बोली नहीं मिली।';

  @override
  String get adminCases => 'केस';

  @override
  String get adminStatus => 'स्थिति';

  @override
  String get adminCompleted => 'पूरा हुआ';

  @override
  String get adminOpen => 'खुला';

  @override
  String get adminClosed => 'बंद';

  @override
  String get adminNotifications => 'सूचनाएँ';

  @override
  String get adminAlertNotifications => 'जोखिम सूचनाएँ';

  @override
  String get adminNotificationsHelp =>
      'POD, दस्तावेज़ अंतर, वाहन और पंजीकरण की सूचनाएँ एक जगह देखें।';

  @override
  String get adminResolved => 'सुलझा';

  @override
  String get adminAll => 'सभी';

  @override
  String get adminNoNotifications => 'अभी कोई सूचना नहीं है।';

  @override
  String get adminProfileUpdated => 'प्रोफ़ाइल अपडेट हुई';

  @override
  String get adminUpdateFailed => 'अपडेट नहीं हुआ';

  @override
  String get adminAccountantProfile => 'अकाउंटेंट प्रोफ़ाइल';

  @override
  String get adminAdminProfile => 'एडमिन प्रोफ़ाइल';

  @override
  String get adminAccountantProfileHelp =>
      'यह प्रोफ़ाइल अकाउंटिंग कार्यक्षेत्र में उपयोग होती है।';

  @override
  String get adminProfileHelp =>
      'यह प्रोफ़ाइल आपके लॉजिस्टिक्स कार्यक्षेत्र में उपयोग होती है।';

  @override
  String get adminLogout => 'लॉग आउट';

  @override
  String get adminAccountDetails => 'खाते का विवरण';

  @override
  String get adminFullName => 'पूरा नाम';

  @override
  String get adminNameHint => 'एडमिन का नाम';

  @override
  String get adminSaving => 'सहेजा जा रहा है...';

  @override
  String get adminSaveProfile => 'प्रोफ़ाइल सहेजें';

  @override
  String get adminUserManagement => 'उपयोगकर्ता प्रबंधन';

  @override
  String get adminPending => 'लंबित';

  @override
  String get adminNoUsers => 'कोई उपयोगकर्ता नहीं';

  @override
  String get adminUnnamed => 'नाम उपलब्ध नहीं';

  @override
  String get adminNoManager => 'कोई प्रबंधक नहीं';

  @override
  String get adminRole => 'भूमिका';

  @override
  String get adminRoleAdmin => 'एडमिन';

  @override
  String get adminError => 'त्रुटि';

  @override
  String get adminReportsTo => 'रिपोर्ट करता है';

  @override
  String get adminAccessHelp =>
      'पहुँच निर्धारित भूमिका और मंज़ूरी की स्थिति के अनुसार मिलती है।';

  @override
  String get adminApprove => 'मंज़ूर करें';

  @override
  String get adminReject => 'अस्वीकार करें';

  @override
  String get adminRemove => 'हटाएँ';

  @override
  String get adminManagerFirst =>
      'पहले लॉजिस्टिक्स प्रबंधक बनाएँ या मंज़ूर करें।';

  @override
  String get adminRoleUpdateFailed => 'भूमिका अपडेट नहीं हुई';

  @override
  String get adminManagerUpdateFailed => 'प्रबंधक अपडेट नहीं हुआ';

  @override
  String get adminDeleteFailed => 'हटाया नहीं जा सका';

  @override
  String get adminRefresh => 'रीफ़्रेश करें';

  @override
  String get adminTotalFreight => 'कुल भाड़ा';

  @override
  String get adminMetricMt => 'मेट्रिक MT';

  @override
  String get adminPendingAcknowledgements => 'लंबित पावती';

  @override
  String get adminTransporterVolume => 'ट्रांसपोर्टर कारोबार';

  @override
  String get adminCompanyFreight => 'कंपनी अनुसार भाड़ा';

  @override
  String get adminTownFreight => 'शहर अनुसार भाड़ा';

  @override
  String get adminNoDataRange => 'इस अवधि का डेटा नहीं है';

  @override
  String get adminDelayAlerts => 'देरी और पावती की सूचनाएँ';

  @override
  String get adminNoDelayedRows => 'इस अवधि में देरी वाला कोई डिस्पैच नहीं है।';

  @override
  String get adminDelayed => 'देरी';

  @override
  String get adminDays => 'दिन';

  @override
  String get adminInvoice => 'इनवॉइस';

  @override
  String get adminAck => 'पावती';

  @override
  String get adminUnassigned => 'आवंटित नहीं';

  @override
  String get tpProfileAndLogout => 'प्रोफ़ाइल और लॉग आउट';

  @override
  String tpBidPlaced(String amount) {
    return '₹$amount की बोली लग गई। बोली बंद होने तक आप इसे बदल सकते हैं।';
  }

  @override
  String tpBidFailed(String error) {
    return 'बोली नहीं लग पाई: $error';
  }

  @override
  String get tpBidClosed => 'बोली बंद है';

  @override
  String get tpBidClosedHint =>
      'केवल जीती हुई बोलियाँ आपके इतिहास और वाहन अनुभाग में उपलब्ध रहेंगी।';

  @override
  String get tpBackToOpenBids => 'खुली बोलियों पर वापस जाएँ';

  @override
  String get tpLiveBidding => 'चालू बोली';

  @override
  String get tpNoBidsYet => 'अभी कोई बोली नहीं लगी है';

  @override
  String tpAnonymousBidders(int count) {
    return '$count गुमनाम बोलीदाता';
  }

  @override
  String get tpPlacing => 'बोली लग रही है...';

  @override
  String get tpUpdateBid => 'बोली बदलें';

  @override
  String get tpPlaceBid => 'बोली लगाएँ';

  @override
  String get tpYou => 'आप';

  @override
  String get tpAnonymousBidder => 'गुमनाम बोलीदाता';

  @override
  String get tpTransporterBrowserHint =>
      'ब्राउज़र से बोलियाँ, वाहन और डिलीवरी की जानकारी प्रबंधित करें।';

  @override
  String tpBiddingOpenHours(int hours, int minutes) {
    return 'बोली खुली है · $hours घंटे $minutes मिनट शेष';
  }

  @override
  String tpBiddingOpenMinutes(int minutes) {
    return 'बोली खुली है · $minutes मिनट शेष';
  }

  @override
  String get tpBiddingOpen => 'बोली खुली है';

  @override
  String get tpYouWonBid => 'आपने यह बोली जीती है';

  @override
  String get tpAwardedOther => 'दूसरे ट्रांसपोर्टर को आवंटित';

  @override
  String tpDeliveryStatus(String status) {
    return 'डिलीवरी: $status';
  }

  @override
  String get tpTrackArrow => 'ट्रैक करें →';

  @override
  String get tpProfileUpdated => 'प्रोफ़ाइल अपडेट हुई';

  @override
  String tpUpdateFailed(String error) {
    return 'अपडेट विफल रहा: $error';
  }

  @override
  String get tpAdmin => 'एडमिन';

  @override
  String get tpLogisticsManager => 'लॉजिस्टिक्स प्रबंधक';

  @override
  String get tpDispatchManager => 'डिस्पैच प्रबंधक';

  @override
  String get tpSignedIn => 'साइन इन है';

  @override
  String get tpProfileDetails => 'प्रोफ़ाइल विवरण';

  @override
  String get tpProfileDetailsHint =>
      'बोली और डिस्पैच सुचारू रखने के लिए संपर्क और दस्तावेज़ की जानकारी अपडेट रखें।';

  @override
  String get tpBusinessInformation => 'व्यवसाय की जानकारी';

  @override
  String get tpFullName => 'पूरा नाम';

  @override
  String get tpBusinessName => 'व्यवसाय का नाम';

  @override
  String get tpPhoneNumber => 'फोन नंबर';

  @override
  String get tpBusinessRegistration => 'व्यवसाय पंजीकरण नंबर';

  @override
  String get tpSavingEllipsis => 'सहेजा जा रहा है…';

  @override
  String get tpSaveChanges => 'बदलाव सहेजें';

  @override
  String get tpAccountOverview => 'खाते का विवरण';

  @override
  String get tpAccountOverviewHint =>
      'खाते की स्थिति और साइन इन की जानकारी देखें।';

  @override
  String get tpNotAvailable => 'उपलब्ध नहीं';

  @override
  String get tpRole => 'भूमिका';

  @override
  String get tpUnknown => 'अज्ञात';

  @override
  String get tpPassword => 'पासवर्ड';

  @override
  String get tpManagedCredentials => 'लॉग इन जानकारी से प्रबंधित';

  @override
  String get tpFleetSetup => 'वाहन और ड्राइवर सेटअप';

  @override
  String get tpFleetSetupHint =>
      'डिस्पैच के लिए वाहन और ड्राइवर अलग से जोड़ें।';

  @override
  String get tpActions => 'कार्रवाइयाँ';

  @override
  String get tpActionsHint => 'खाते के सामान्य विकल्प और त्वरित कार्य।';

  @override
  String get tpReloadProfile => 'प्रोफ़ाइल फिर लोड करें';

  @override
  String get tpFetchLatest => 'खाते की ताज़ा जानकारी लाएँ';

  @override
  String get tpPrivacyDeletion => 'गोपनीयता नीति और खाता हटाना';

  @override
  String get tpSignOutHint => 'लॉग आउट कर स्वागत स्क्रीन पर लौटें';

  @override
  String get tpProfileSyncHint =>
      'प्रोफ़ाइल में बदलाव मोबाइल ऐप और वेब डैशबोर्ड पर दिखेंगे।';

  @override
  String get tpEditableProfile => 'बदली जा सकने वाली प्रोफ़ाइल';

  @override
  String get tpDeliveryProgress => 'डिलीवरी की प्रगति';

  @override
  String get tpDeliveredCaps => 'डिलीवर हो गया';

  @override
  String get tpInTransitCaps => 'रास्ते में';

  @override
  String get tpPickupCaps => 'पिकअप';

  @override
  String get tpDispatchedCaps => 'रवाना';

  @override
  String get tpLmConfirmedVehicle => 'लॉजिस्टिक्स प्रबंधक ने वाहन की पुष्टि की';

  @override
  String get tpLmRaisedIssue => 'लॉजिस्टिक्स प्रबंधक ने समस्या बताई';

  @override
  String get tpWaitingVehicleConfirmation => 'वाहन की पुष्टि का इंतज़ार है';

  @override
  String get tpVehicleConfirmedHint =>
      'लॉजिस्टिक्स प्रबंधक ने वाहन की जानकारी की पुष्टि की है।';

  @override
  String get tpDispatchUpdateHint =>
      'डिस्पैच की जानकारी बदलकर पुष्टि के लिए फिर भेजें।';

  @override
  String get tpDispatchChangeHint =>
      'डिस्पैच की जानकारी बदलने पर फिर से पुष्टि करानी होगी।';

  @override
  String get tpCouldNotReadImage => 'चुनी हुई फ़ोटो पढ़ी नहीं जा सकी';

  @override
  String get tpPhotoUploaded => 'फ़ोटो अपलोड हो गई';

  @override
  String tpUploadFailed(String error) {
    return 'अपलोड विफल रहा: $error';
  }

  @override
  String get tpUploading => 'अपलोड हो रहा है...';

  @override
  String get tpUploadedPreview => 'अपलोड हो गया — देखने के लिए टैप करें';

  @override
  String get tpSaved => 'सहेजा गया';

  @override
  String get tpDispatched => 'रवाना';

  @override
  String get tpLorryProof => 'लॉरी का प्रमाण';

  @override
  String get tpAddLorryPhotograph => 'लॉरी की फ़ोटो जोड़ें';

  @override
  String get tpUploadLorryPhoto => 'लॉरी की फ़ोटो अपलोड करें';

  @override
  String get tpDriverProof => 'ड्राइवर का प्रमाण';

  @override
  String get tpEnterDriverPhotograph => 'ड्राइवर की फ़ोटो जोड़ें';

  @override
  String get tpUploadDriverPhoto => 'ड्राइवर की फ़ोटो अपलोड करें';

  @override
  String get tpDriverAadhaarPhoto => 'ड्राइवर के आधार कार्ड की फ़ोटो जोड़ें';

  @override
  String get tpUploadDriverAadhaar =>
      'ड्राइवर के आधार कार्ड की फ़ोटो अपलोड करें';

  @override
  String get tpSubmitLorryDetails => 'लॉरी की जानकारी भेजें';

  @override
  String get tpSelectVehicle => 'वाहन चुनें';

  @override
  String get tpNoSavedVehicles => 'अभी कोई वाहन सहेजा नहीं गया है';

  @override
  String get tpChooseSavedFleet => 'अपने सहेजे हुए वाहनों में से चुनें';

  @override
  String get tpUseSavedVehicle =>
      'पहले से जोड़ा हुआ वाहन चुनें या नया वाहन जोड़ें।';

  @override
  String get tpRcSaved => 'आरसी सहेजी गई';

  @override
  String get tpInsuranceSaved => 'बीमा सहेजा गया';

  @override
  String get tpSelectDriver => 'ड्राइवर चुनें';

  @override
  String get tpNoSavedDrivers => 'अभी कोई ड्राइवर सहेजा नहीं गया है';

  @override
  String get tpChooseSavedDrivers => 'अपने सहेजे हुए ड्राइवरों में से चुनें';

  @override
  String get tpUseSavedDriver =>
      'पहले से जोड़ा हुआ ड्राइवर चुनें या नया ड्राइवर जोड़ें।';

  @override
  String get tpLicenceSaved => 'लाइसेंस सहेजा गया';

  @override
  String get tpPickup => 'पिकअप';

  @override
  String get tpPickupDetails => 'पिकअप की जानकारी';

  @override
  String get tpEnterDriverPhone => 'ड्राइवर का फोन नंबर दर्ज करें';

  @override
  String get tpEnterSitePhoto => 'साइट की फ़ोटो जोड़ें';

  @override
  String get tpUploadPresence => 'मौके पर मौजूदगी की फ़ोटो अपलोड करें';

  @override
  String get tpSubmitPickup => 'पिकअप की जानकारी भेजें';

  @override
  String get tpInTransit => 'रास्ते में';

  @override
  String get tpSubcontractors => 'सब कॉन्ट्रैक्टर';

  @override
  String get tpAddContractor => 'कॉन्ट्रैक्टर जोड़ें';

  @override
  String get tpVerificationDetails => 'सत्यापन की जानकारी';

  @override
  String get tpGrBiltyNumber => 'जीआर / बिल्टी नंबर';

  @override
  String get tpEwayBillNumber => 'ई-वे बिल नंबर';

  @override
  String get tpCurrentLocation => 'वर्तमान स्थान';

  @override
  String get tpEnterCurrentLocation => 'वर्तमान स्थान दर्ज करें';

  @override
  String get tpLocationUpdated => 'स्थान अपडेट हुआ';

  @override
  String tpLocationUpdateFailed(String error) {
    return 'स्थान अपडेट नहीं हुआ: $error';
  }

  @override
  String get tpUpdating => 'अपडेट हो रहा है...';

  @override
  String get tpUpdateLocation => 'स्थान अपडेट करें';

  @override
  String get tpTransitSitePhoto => 'रास्ते की साइट फ़ोटो';

  @override
  String get tpShareTransit => 'यात्रा की जानकारी साझा करें';

  @override
  String tpContractorNumber(int number) {
    return 'कॉन्ट्रैक्टर $number';
  }

  @override
  String get tpName => 'नाम';

  @override
  String get tpPhone => 'फोन';

  @override
  String get tpFrom => 'से';

  @override
  String get tpTo => 'तक';

  @override
  String get tpSelectCity => 'शहर चुनें';

  @override
  String get tpDelivered => 'डिलीवर किया';

  @override
  String get tpDeliverySiteDetails => 'डिलीवरी साइट की जानकारी दर्ज करें';

  @override
  String get tpEnterReceiverName => 'प्राप्तकर्ता का नाम दर्ज करें';

  @override
  String get tpEnterReceiverNumber => 'प्राप्तकर्ता का फोन नंबर दर्ज करें';

  @override
  String get tpEnterGrNumber => 'जीआर नंबर दर्ज करें';

  @override
  String get tpEnterEwayBill => 'ई-वे बिल नंबर दर्ज करें';

  @override
  String get tpProofOfDelivery => 'डिलीवरी का प्रमाण (POD)';

  @override
  String get tpUploadPod => 'डिलीवरी का प्रमाण अपलोड करें';

  @override
  String get tpAdditionalChargesReason =>
      'अतिरिक्त शुल्क (यदि हो) — बिल का कारण';

  @override
  String get tpLoadingChargesHint => 'जैसे लोडिंग शुल्क';

  @override
  String get tpBillPhoto => 'बिल की फ़ोटो';

  @override
  String get tpUploadBillPhoto => 'बिल की फ़ोटो अपलोड करें';

  @override
  String get tpOnSitePhoto => 'साइट की फ़ोटो';

  @override
  String get tpShareDelivery => 'डिलीवरी की जानकारी साझा करें';

  @override
  String get opsInvoice => 'इनवॉइस';

  @override
  String get opsLrOptional => 'LR नंबर (वैकल्पिक)';

  @override
  String get opsDeliveryRefOptional => 'डिलीवरी संदर्भ (वैकल्पिक)';

  @override
  String get opsPartyName => 'पार्टी का नाम';

  @override
  String get opsTown => 'शहर';

  @override
  String get opsCases => 'केस';

  @override
  String get opsMetricTons => 'मीट्रिक टन';

  @override
  String get opsFreightShare => 'भाड़े का हिस्सा';

  @override
  String get opsBillDate => 'बिल की तारीख';

  @override
  String get opsDispatchDate => 'डिस्पैच की तारीख';

  @override
  String get opsVehicleNumber => 'वाहन नंबर';

  @override
  String get opsVehicleType => 'वाहन का प्रकार';

  @override
  String get opsChargeType => 'शुल्क का प्रकार';

  @override
  String get opsAmount => 'राशि';

  @override
  String get opsChargeAllocation => 'शुल्क आवंटन';

  @override
  String get opsRemarksOptional => 'टिप्पणी (वैकल्पिक)';

  @override
  String get opsSubmitLockFreight => 'इनवॉइस जानकारी सेव करें';

  @override
  String get opsSaving => 'सहेजा जा रहा है...';

  @override
  String get opsWorkDetails => 'कार्य विवरण';

  @override
  String get opsManagerIdentityHint =>
      'यहाँ केवल मैनेजर की पहचान और कार्य क्षेत्र चाहिए।';

  @override
  String get opsAccount => 'खाता';

  @override
  String get opsTransporterOwnershipHint =>
      'व्यवसाय, GST और वाहन का स्वामित्व ट्रांसपोर्टर के पास रहता है।';

  @override
  String get opsEmail => 'ईमेल';

  @override
  String get opsRole => 'भूमिका';

  @override
  String get opsStatus => 'स्थिति';

  @override
  String get opsAllTransporters => 'सभी ट्रांसपोर्टर';

  @override
  String get opsReadOnlyTransporters =>
      'बोलियाँ सौंपने और ज़िम्मेदारी जाँचने के लिए केवल पढ़ने वाली सूची।';

  @override
  String get opsAllVehicles => 'सभी वाहन';

  @override
  String get opsVehiclesOwnedHint =>
      'वाहन ट्रांसपोर्टर जोड़ते हैं। मैनेजर पहुँचे हुए वाहन की जाँच करते हैं।';

  @override
  String get opsAdd => 'जोड़ें';

  @override
  String get opsEdit => 'संपादित करें';

  @override
  String get opsPhone => 'फ़ोन';

  @override
  String get opsConfirm => 'पुष्टि करें';

  @override
  String get opsRaiseIssue => 'समस्या दर्ज करें';

  @override
  String get opsConfirmVehicleArrived => 'वाहन के पहुँचने की पुष्टि करें';

  @override
  String get opsRaiseVehicleIssue => 'वाहन की समस्या दर्ज करें';

  @override
  String get opsLastDriverLocation => 'चालक के अपडेट से अंतिम स्थान';

  @override
  String get opsLorryPhoto => 'लॉरी की फ़ोटो';

  @override
  String get opsDriverPhoto => 'चालक की फ़ोटो';

  @override
  String get opsDriverAadhaar => 'चालक का आधार';

  @override
  String get opsInvoicePhoto => 'इनवॉइस की फ़ोटो';

  @override
  String get opsSitePhoto => 'स्थल की फ़ोटो';

  @override
  String get opsProofOfDelivery => 'डिलीवरी का प्रमाण';

  @override
  String get opsBillPhoto => 'बिल की फ़ोटो';

  @override
  String get opsTollTax => 'टोल टैक्स';

  @override
  String get opsPointCharge => 'पॉइंट शुल्क';

  @override
  String get opsExtraFreight => 'अतिरिक्त भाड़ा';

  @override
  String get opsLabour => 'मज़दूरी';

  @override
  String get opsDetention => 'रोक शुल्क';

  @override
  String get opsOutRoute => 'मार्ग से बाहर';

  @override
  String get opsDeduction => 'कटौती';

  @override
  String get opsOther => 'अन्य';

  @override
  String get opsDispatched => 'डिस्पैच किया गया';

  @override
  String get opsPickup => 'पिकअप';

  @override
  String get opsDelivered => 'डिलीवर किया गया';

  @override
  String get adminFreightLedger => 'भाड़ा लेजर';

  @override
  String get adminExportReports => 'रिपोर्ट निर्यात करें';

  @override
  String get adminTransporterMonthlyCsv => 'ट्रांसपोर्टर मासिक CSV';

  @override
  String get adminPlaceWiseCsv => 'स्थान अनुसार CSV';

  @override
  String get adminInvoiceWiseCsv => 'इनवॉइस अनुसार CSV';

  @override
  String get adminPodPendingCsv => 'लंबित POD CSV';

  @override
  String get adminVehicleTonnageCsv => 'वाहन टन भार CSV';

  @override
  String get adminRouteWiseCsv => 'मार्ग अनुसार CSV';

  @override
  String get adminUploadCsv => 'CSV अपलोड करें';

  @override
  String get adminEntry => 'एंट्री';

  @override
  String get adminCompany => 'कंपनी';

  @override
  String get adminDestinationPlace => 'गंतव्य / स्थान';

  @override
  String get adminInvoiceNumber => 'इनवॉइस नंबर';

  @override
  String get adminSearchInvoice => 'इनवॉइस खोजें';

  @override
  String get adminFilters => 'फ़िल्टर';

  @override
  String get adminClearFilters => 'फ़िल्टर साफ़ करें';

  @override
  String get adminPodAcknowledgement => 'POD / पावती';

  @override
  String get adminVehicleTonnage => 'वाहन टन भार';

  @override
  String get adminPlaceSearch => 'स्थान खोजें';

  @override
  String get adminOriginDestinationParty => 'आरंभ, गंतव्य, पार्टी';

  @override
  String get adminEwayNumber => 'ई-वे बिल नंबर';

  @override
  String get adminSearchEway => 'ई-वे बिल खोजें';

  @override
  String get adminDelayedOnly => 'केवल देरी वाले';

  @override
  String get adminLatePod => 'देर से आया POD';

  @override
  String get adminNoLedgerRows => 'इस फ़िल्टर से कोई लेजर एंट्री नहीं मिली।';

  @override
  String get adminSummaryReport => 'सारांश रिपोर्ट';

  @override
  String get adminPlace => 'स्थान';

  @override
  String get adminRoute => 'मार्ग';

  @override
  String get adminVehicle => 'वाहन';

  @override
  String get adminShowing => 'दिखाए जा रहे';

  @override
  String get adminOf => 'कुल';

  @override
  String get adminRows => 'पंक्तियाँ';

  @override
  String get adminPreviousPage => 'पिछला पेज';

  @override
  String get adminNextPage => 'अगला पेज';

  @override
  String get adminScrollLeft => 'तालिका बाएँ खिसकाएँ';

  @override
  String get adminScrollRight => 'तालिका दाएँ खिसकाएँ';

  @override
  String get adminInvoiceRows => 'इनवॉइस पंक्तियाँ';

  @override
  String get adminTrips => 'चक्कर';

  @override
  String get adminVehicles => 'वाहन';

  @override
  String get adminFreight => 'भाड़ा';

  @override
  String get adminPodPending => 'लंबित POD';

  @override
  String get adminOverview => 'सारांश';

  @override
  String get adminLoadingPeriod => 'नवीनतम अवधि लोड हो रही है';

  @override
  String get adminLatestPeriod => 'नवीनतम अवधि';

  @override
  String get adminDashboardLoadFailed => 'डैशबोर्ड लोड नहीं हुआ';

  @override
  String get adminRetry => 'फिर कोशिश करें';

  @override
  String get adminDashboard => 'एडमिन डैशबोर्ड';

  @override
  String get adminWelcome => 'स्वागत है';

  @override
  String get adminMonth => 'महीना';

  @override
  String get adminFrom => 'से';

  @override
  String get adminTo => 'तक';

  @override
  String get adminLatest => 'नवीनतम';

  @override
  String get adminMetricTons => 'मेट्रिक टन';

  @override
  String get adminReviewValue => 'समीक्षा राशि';

  @override
  String get adminNeedsAttention => 'ध्यान दें';

  @override
  String get adminNoPriorityItems =>
      'इस अवधि में प्राथमिक समीक्षा आइटम नहीं हैं।';

  @override
  String get adminOpenLedger => 'लेजर खोलें';

  @override
  String get adminAskClawd => 'Clawd से पूछें';

  @override
  String get adminReviewRoutes => 'मार्ग देखें';

  @override
  String get adminOpenClawd => 'Clawd खोलें';

  @override
  String get adminDocumentReview =>
      'भुगतान जारी करने से पहले दस्तावेज़ अनुसार समीक्षा करें।';

  @override
  String get adminExtraChargesHelp =>
      'मज़दूरी, डिटेंशन, टोल और मार्ग से बाहर के शुल्क जाँचें।';

  @override
  String get adminTransporterPerformance => 'ट्रांसपोर्टर प्रदर्शन';

  @override
  String get adminRoutesDestinations => 'मार्ग और गंतव्य';

  @override
  String get adminFreightPerMt => 'भाड़ा/MT';

  @override
  String get adminTrends => 'रुझान';

  @override
  String get adminHide => 'छिपाएँ';

  @override
  String get adminShow => 'दिखाएँ';

  @override
  String get adminNoTrendData => 'रुझान का डेटा नहीं है';

  @override
  String get adminTrendHelp =>
      'विस्तृत जानकारी के लिए दैनिक भाड़े का रुझान यहाँ देखें।';

  @override
  String get adminNoRecordsPeriod => 'इस अवधि में कोई रिकॉर्ड नहीं है।';

  @override
  String get adminNoDashboardData => 'डैशबोर्ड का डेटा नहीं मिला।';

  @override
  String get adminAckFollowUp => 'पावती के लिए फ़ॉलो-अप ज़रूरी है';

  @override
  String get adminDuplicateEwayRisk => 'डुप्लिकेट ई-वे जोखिम';

  @override
  String get adminRouteCostSpike => 'मार्ग लागत वृद्धि';

  @override
  String get adminCompareFreight => 'भाड़ा/MT की तुलना ज़रूरी है';

  @override
  String get adminHighExtraCharge => 'अधिक अतिरिक्त शुल्क वाले मामले';

  @override
  String get adminSelectMonth => 'महीना चुनें';

  @override
  String get adminYear => 'वर्ष';

  @override
  String get adminEdit => 'बदलें';

  @override
  String get adminBill => 'बिल';

  @override
  String get adminDispatch => 'डिस्पैच';

  @override
  String get adminDelay => 'देरी';

  @override
  String get adminInvoiceShort => 'इनवॉइस';

  @override
  String get adminInvoiceCount => 'इनवॉइस संख्या';

  @override
  String get adminEway => 'ई-वे';

  @override
  String get adminEwayCount => 'ई-वे संख्या';

  @override
  String get adminDel => 'DEL';

  @override
  String get adminParty => 'पार्टी';

  @override
  String get adminPartyCount => 'पार्टी संख्या';

  @override
  String get adminOrigin => 'आरंभ स्थान';

  @override
  String get adminTown => 'शहर';

  @override
  String get adminTon => 'टन';

  @override
  String get adminCapacity => 'क्षमता';

  @override
  String get adminDispatchGr => 'डिस्पैच GR';

  @override
  String get adminTotal => 'कुल';

  @override
  String get adminBalance => 'बाकी राशि';

  @override
  String get adminPodStatus => 'POD स्थिति';

  @override
  String get adminPodDate => 'POD तारीख';

  @override
  String get adminPodFile => 'POD फ़ाइल';

  @override
  String get adminPodRemark => 'POD टिप्पणी';

  @override
  String get adminReceivedBy => 'प्राप्तकर्ता';

  @override
  String get adminPodReceived => 'प्राप्त POD';

  @override
  String get adminFreightPerCase => 'भाड़ा/केस';

  @override
  String get adminAvgFreightPerMt => 'औसत भाड़ा/MT';

  @override
  String get adminTransporterBreakup => 'ट्रांसपोर्टर विवरण';

  @override
  String get adminTransporterSummary => 'ट्रांसपोर्टर सारांश';

  @override
  String get tpLocationHint => 'जैसे अंबाला बाईपास';

  @override
  String get tpApproved => 'स्वीकृत';

  @override
  String get tpPending => 'लंबित';

  @override
  String get tpRejected => 'अस्वीकृत';

  @override
  String get tpSuspended => 'निलंबित';

  @override
  String get tpCompleted => 'पूरा हुआ';

  @override
  String get tpAwarded => 'आवंटित';

  @override
  String get tpLocked => 'लॉक';

  @override
  String get adminCompanyRequired => 'कंपनी का नाम ज़रूरी है।';

  @override
  String get adminUploadLedgerCsv => 'लेजर CSV अपलोड करें';

  @override
  String get adminCompanySheetName => 'कंपनी / शीट का नाम *';

  @override
  String get adminUploadTag => 'अपलोड टैग';

  @override
  String get adminCsvHelp =>
      'Excel से निकाली गई CSV का उपयोग करें। इस संस्करण में सीधे .xlsx अपलोड उपलब्ध नहीं है।';

  @override
  String get adminCancel => 'रद्द करें';

  @override
  String get adminChooseCsv => 'CSV चुनें';

  @override
  String get adminCsvUploadComplete => 'CSV अपलोड पूरा हुआ';

  @override
  String get adminRowsImported => 'आयात हुई पंक्तियाँ';

  @override
  String get adminChargeRowsImported => 'आयात हुई शुल्क पंक्तियाँ';

  @override
  String get adminMissingTransportersHelp =>
      'ये ट्रांसपोर्टर मंज़ूर प्रोफ़ाइल में नहीं मिले, इसलिए इनके नाम टिप्पणियों में सहेजे गए:';

  @override
  String get adminMore => 'और';

  @override
  String get adminDone => 'हो गया';

  @override
  String get adminLedgerEntry => 'लेजर एंट्री';

  @override
  String get adminCompanyRequiredLabel => 'कंपनी *';

  @override
  String get adminBranch => 'शाखा';

  @override
  String get adminVehicleType => 'वाहन प्रकार';

  @override
  String get adminDispatchGrBilty => 'डिस्पैच GR/बिल्टी';

  @override
  String get adminAckStatus => 'पावती की स्थिति';

  @override
  String get adminReceived => 'प्राप्त';

  @override
  String get adminNotRequired => 'ज़रूरी नहीं';

  @override
  String get adminPodReceivedDate => 'POD प्राप्त yyyy-mm-dd';

  @override
  String get adminInvoiceLines => 'इनवॉइस पंक्तियाँ';

  @override
  String get adminCharges => 'शुल्क';

  @override
  String get adminSettlement => 'हिसाब निपटान';

  @override
  String get adminLastMonthBalance => 'पिछले महीने की बाकी राशि';

  @override
  String get adminPayment => 'भुगतान';

  @override
  String get adminSettlementDeduction => 'हिसाब कटौती';

  @override
  String get adminSettlementRemarks => 'हिसाब टिप्पणी';

  @override
  String get adminProducts => 'उत्पाद';

  @override
  String get adminOptionalProductsHelp =>
      'करनाल शैली की रिपोर्ट के लिए वैकल्पिक उत्पाद/श्रेणी मात्रा।';

  @override
  String get adminRemarks => 'टिप्पणियाँ';

  @override
  String get adminSaveEntry => 'एंट्री सहेजें';

  @override
  String get adminEditLedgerEntry => 'लेजर एंट्री बदलें';

  @override
  String get adminDestinationSummary => 'गंतव्य सारांश';

  @override
  String get adminRouteSummary => 'मार्ग सारांश';

  @override
  String get adminVehicleTonnageSummary => 'वाहन टन भार सारांश';

  @override
  String get adminClearMonth => 'महीना साफ़ करें';

  @override
  String get adminLoadFailed => 'लोड नहीं हुआ';

  @override
  String get adminExportFailed => 'निर्यात नहीं हुआ';

  @override
  String get adminCsvUploadFailed => 'CSV अपलोड नहीं हुआ';

  @override
  String get adminCompanyTownRequired =>
      'कंपनी और पहली इनवॉइस का शहर ज़रूरी हैं।';

  @override
  String get adminPodFileReadFailed => 'POD फ़ाइल पढ़ी नहीं जा सकी';

  @override
  String get adminAdd => 'जोड़ें';

  @override
  String get adminOverrideApproval =>
      'डुप्लिकेट लॉक हटाने के लिए एडमिन मंज़ूरी';

  @override
  String get adminReasonRemarkRequired => 'कारण और टिप्पणी ज़रूरी हैं।';

  @override
  String get adminRemoveInvoice => 'इनवॉइस हटाएँ';

  @override
  String get adminVehicleCapacity => 'वाहन क्षमता';

  @override
  String get adminKind => 'प्रकार';

  @override
  String get adminRemoveCharge => 'शुल्क हटाएँ';

  @override
  String get adminRemoveProduct => 'उत्पाद हटाएँ';

  @override
  String get adminTransporterWiseSummary => 'ट्रांसपोर्टर अनुसार सारांश';

  @override
  String get adminPlaceWiseSummary => 'स्थान अनुसार सारांश';

  @override
  String get adminRouteWiseSummary => 'मार्ग अनुसार सारांश';

  @override
  String get adminTransporterSummaryHelp =>
      'ट्रांसपोर्टर अनुसार चक्कर, अलग वाहन, भाड़ा दक्षता और POD स्थिति।';

  @override
  String get adminPlaceSummaryHelp =>
      'ट्रांसपोर्टर विवरण सहित गंतव्य अनुसार आवाजाही।';

  @override
  String get adminRouteSummaryHelp => 'आरंभ से गंतव्य तक भाड़े की तुलना।';

  @override
  String get adminVehicleSummaryHelp => 'वाहन क्षमता श्रेणी का उपयोग।';

  @override
  String get adminDestination => 'गंतव्य';

  @override
  String get adminFromTo => 'से → तक';

  @override
  String get adminCategory => 'श्रेणी';

  @override
  String get adminEwayBill => 'ई-वे बिल';

  @override
  String get adminDelRef => 'DEL संदर्भ';

  @override
  String get adminLrGr => 'LR/GR';

  @override
  String get adminTownRequired => 'शहर *';

  @override
  String get adminBillDate => 'बिल तारीख yyyy-mm-dd';

  @override
  String get adminDispatchDate => 'डिस्पैच तारीख yyyy-mm-dd';

  @override
  String get adminFreightShare => 'भाड़ा हिस्सा';

  @override
  String get adminAmount => 'राशि';

  @override
  String get adminChargeRemarks => 'शुल्क टिप्पणी';

  @override
  String get adminProduct => 'उत्पाद';

  @override
  String get adminPodFileUploaded => 'POD फ़ाइल अपलोड हुई';

  @override
  String get adminDuplicateFreightLock => 'डुप्लिकेट भाड़ा लॉक';

  @override
  String get adminOnlyAdminOverride =>
      'डुप्लिकेट भाड़े को केवल एडमिन मंज़ूर कर सकता है।';

  @override
  String get adminOverrideReason => 'लॉक हटाने का कारण *';

  @override
  String get adminOverrideRemark => 'लॉक हटाने की टिप्पणी *';

  @override
  String get adminSaveFailed => 'सहेजा नहीं जा सका';

  @override
  String get opsDeliveryPodStatus => 'डिलीवरी और प्राप्ति प्रमाण की स्थिति';

  @override
  String opsDestinationsDelivered(int count, int total) {
    return '$total में से $count गंतव्यों पर डिलीवरी हुई';
  }

  @override
  String opsDeliveryProofsUploaded(int count, int total) {
    return '$total में से $count डिलीवरी प्रमाण अपलोड हुए';
  }

  @override
  String get opsGoodsInvoiceChallans => 'माल के इनवॉइस / चालान';

  @override
  String get opsGrBilty => 'GR / बिल्टी';

  @override
  String get opsEwayBills => 'ई-वे बिल';

  @override
  String get opsViewDeliveryProof => 'डिलीवरी प्रमाण देखें';

  @override
  String get opsDeliveryProofPending => 'डिलीवरी प्रमाण लंबित है';

  @override
  String get opsDuplicateDeliveryDestination =>
      'यह डिलीवरी गंतव्य पहले से मार्ग में है।';

  @override
  String get opsEnterDeliveryQuantities =>
      'हर डिलीवरी के लिए सही केस संख्या और मीट्रिक टन दर्ज करें।';

  @override
  String get opsBidAwardedDuringEdit =>
      'आपके संपादन के दौरान यह बोली आवंटित हो गई।';

  @override
  String get opsRemoveDestination => 'गंतव्य हटाएँ';

  @override
  String get uiQuickLinks => 'त्वरित कार्य';

  @override
  String get uiViewDirectory => 'सूची देखें';

  @override
  String get uiReadOnlyList => 'केवल देखने के लिए सूची';
}
