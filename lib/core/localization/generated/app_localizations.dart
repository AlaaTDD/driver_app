import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'تاكسي'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get home;

  /// No description provided for @profile.
  ///
  /// In ar, this message translates to:
  /// **'الملف الشخصي'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @logout.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get login;

  /// No description provided for @register.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get register;

  /// No description provided for @notifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get notifications;

  /// No description provided for @messages.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل'**
  String get messages;

  /// No description provided for @help.
  ///
  /// In ar, this message translates to:
  /// **'المساعدة'**
  String get help;

  /// No description provided for @smartTransportService.
  ///
  /// In ar, this message translates to:
  /// **'خدمة نقل ذكية وسريعة'**
  String get smartTransportService;

  /// No description provided for @skip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get skip;

  /// No description provided for @smartRideService.
  ///
  /// In ar, this message translates to:
  /// **'خدمة نقل ذكية'**
  String get smartRideService;

  /// No description provided for @smartRideDesc.
  ///
  /// In ar, this message translates to:
  /// **'احجز رحلتك بنقرة واحدة وانتظر السائق يصل إليك في دقائق معدودة'**
  String get smartRideDesc;

  /// No description provided for @realTimeTracking.
  ///
  /// In ar, this message translates to:
  /// **'تتبع في الوقت الفعلي'**
  String get realTimeTracking;

  /// No description provided for @realTimeTrackingDesc.
  ///
  /// In ar, this message translates to:
  /// **'تابع موقع سائقك لحظة بلحظة على الخريطة حتى وصوله إليك بدقة'**
  String get realTimeTrackingDesc;

  /// No description provided for @safeAndReliable.
  ///
  /// In ar, this message translates to:
  /// **'آمن وموثوق'**
  String get safeAndReliable;

  /// No description provided for @safeAndReliableDesc.
  ///
  /// In ar, this message translates to:
  /// **'جميع السائقين محققون ومعتمدون لضمان سلامتك وراحتك في كل رحلة'**
  String get safeAndReliableDesc;

  /// No description provided for @loginTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل دخولك للمتابعة'**
  String get loginTitle;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get email;

  /// No description provided for @enterEmail.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال البريد الإلكتروني'**
  String get enterEmail;

  /// No description provided for @password.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور'**
  String get password;

  /// No description provided for @enterPassword.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال كلمة المرور'**
  String get enterPassword;

  /// No description provided for @noAccount.
  ///
  /// In ar, this message translates to:
  /// **'ليس لديك حساب؟ '**
  String get noAccount;

  /// No description provided for @registerNow.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الآن'**
  String get registerNow;

  /// No description provided for @chooseAccountType.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع حسابك'**
  String get chooseAccountType;

  /// No description provided for @chooseRoleDesc.
  ///
  /// In ar, this message translates to:
  /// **'حدّد الدور الذي يناسبك للبدء'**
  String get chooseRoleDesc;

  /// No description provided for @user.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم'**
  String get user;

  /// No description provided for @userDesc.
  ///
  /// In ar, this message translates to:
  /// **'احجز رحلاتك بسهولة وسافر بأمان وراحة'**
  String get userDesc;

  /// No description provided for @driver.
  ///
  /// In ar, this message translates to:
  /// **'سائق'**
  String get driver;

  /// No description provided for @driverDesc.
  ///
  /// In ar, this message translates to:
  /// **'انضم إلى فريق سائقي Snapix واكسب أكثر'**
  String get driverDesc;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In ar, this message translates to:
  /// **'لديك حساب بالفعل؟ '**
  String get alreadyHaveAccount;

  /// No description provided for @createUserAccount.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب مستخدم'**
  String get createUserAccount;

  /// No description provided for @personalInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلوماتك الشخصية'**
  String get personalInfo;

  /// No description provided for @enterDataToCreateAccount.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بياناتك لإنشاء حسابك'**
  String get enterDataToCreateAccount;

  /// No description provided for @basicData.
  ///
  /// In ar, this message translates to:
  /// **'البيانات الأساسية'**
  String get basicData;

  /// No description provided for @fullName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم الكامل'**
  String get fullName;

  /// No description provided for @enterFullName.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال الاسم الكامل'**
  String get enterFullName;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get phone;

  /// No description provided for @enterPhone.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال رقم الهاتف'**
  String get enterPhone;

  /// No description provided for @confirmPassword.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد كلمة المرور'**
  String get confirmPassword;

  /// No description provided for @pleaseConfirmPassword.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء تأكيد كلمة المرور'**
  String get pleaseConfirmPassword;

  /// No description provided for @passwordMinLength.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور يجب أن تكون 6 أحرف على الأقل'**
  String get passwordMinLength;

  /// No description provided for @createAccount.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء الحساب'**
  String get createAccount;

  /// No description provided for @passwordsNotMatch.
  ///
  /// In ar, this message translates to:
  /// **'كلمات المرور غير متطابقة'**
  String get passwordsNotMatch;

  /// No description provided for @createDriverAccount.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب سائق'**
  String get createDriverAccount;

  /// No description provided for @personalInformation.
  ///
  /// In ar, this message translates to:
  /// **'المعلومات الشخصية'**
  String get personalInformation;

  /// No description provided for @nationalId.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهوية الوطنية'**
  String get nationalId;

  /// No description provided for @enterNationalId.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال رقم الهوية'**
  String get enterNationalId;

  /// No description provided for @nationalIdPhoto.
  ///
  /// In ar, this message translates to:
  /// **'صورة الهوية الوطنية'**
  String get nationalIdPhoto;

  /// No description provided for @licenseNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم الرخصة'**
  String get licenseNumber;

  /// No description provided for @enterLicenseNumber.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال رقم الرخصة'**
  String get enterLicenseNumber;

  /// No description provided for @licensePhoto.
  ///
  /// In ar, this message translates to:
  /// **'صورة رخصة القيادة'**
  String get licensePhoto;

  /// No description provided for @backgroundCheckPhoto.
  ///
  /// In ar, this message translates to:
  /// **'صورة فحص السوابق'**
  String get backgroundCheckPhoto;

  /// No description provided for @requiredDocuments.
  ///
  /// In ar, this message translates to:
  /// **'الوثائق المطلوبة'**
  String get requiredDocuments;

  /// No description provided for @vehicleType.
  ///
  /// In ar, this message translates to:
  /// **'نوع المركبة'**
  String get vehicleType;

  /// No description provided for @sedan.
  ///
  /// In ar, this message translates to:
  /// **'سيارة عادية'**
  String get sedan;

  /// No description provided for @suv.
  ///
  /// In ar, this message translates to:
  /// **'دفع رباعي'**
  String get suv;

  /// No description provided for @van.
  ///
  /// In ar, this message translates to:
  /// **'فان'**
  String get van;

  /// No description provided for @minibus.
  ///
  /// In ar, this message translates to:
  /// **'ميني باص'**
  String get minibus;

  /// No description provided for @motorcycle.
  ///
  /// In ar, this message translates to:
  /// **'دراجة نارية'**
  String get motorcycle;

  /// No description provided for @vehicleBrand.
  ///
  /// In ar, this message translates to:
  /// **'ماركة المركبة'**
  String get vehicleBrand;

  /// No description provided for @enterVehicleBrand.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال ماركة المركبة'**
  String get enterVehicleBrand;

  /// No description provided for @vehicleModel.
  ///
  /// In ar, this message translates to:
  /// **'موديل المركبة'**
  String get vehicleModel;

  /// No description provided for @enterVehicleModel.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال موديل المركبة'**
  String get enterVehicleModel;

  /// No description provided for @vehicleYear.
  ///
  /// In ar, this message translates to:
  /// **'سنة الصنع'**
  String get vehicleYear;

  /// No description provided for @enterVehicleYear.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال سنة الصنع'**
  String get enterVehicleYear;

  /// No description provided for @vehicleColor.
  ///
  /// In ar, this message translates to:
  /// **'لون المركبة'**
  String get vehicleColor;

  /// No description provided for @enterVehicleColor.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال لون المركبة'**
  String get enterVehicleColor;

  /// No description provided for @plateNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم اللوحة'**
  String get plateNumber;

  /// No description provided for @enterPlateNumber.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء إدخال رقم اللوحة'**
  String get enterPlateNumber;

  /// No description provided for @vehiclePhoto.
  ///
  /// In ar, this message translates to:
  /// **'صورة المركبة'**
  String get vehiclePhoto;

  /// No description provided for @uploadAllDocuments.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء رفع جميع المستندات والصور المطلوبة'**
  String get uploadAllDocuments;

  /// No description provided for @accountUnderReview.
  ///
  /// In ar, this message translates to:
  /// **'حسابك قيد المراجعة'**
  String get accountUnderReview;

  /// No description provided for @reviewDesc.
  ///
  /// In ar, this message translates to:
  /// **'نقوم بمراجعة بياناتك وسيتم إشعارك بمجرد الانتهاء'**
  String get reviewDesc;

  /// No description provided for @rateTrip.
  ///
  /// In ar, this message translates to:
  /// **'قيّم الرحلة'**
  String get rateTrip;

  /// No description provided for @howWasTrip.
  ///
  /// In ar, this message translates to:
  /// **'كيف كانت رحلتك؟'**
  String get howWasTrip;

  /// No description provided for @addComment.
  ///
  /// In ar, this message translates to:
  /// **'أضف تعليقك (اختياري)'**
  String get addComment;

  /// No description provided for @writeExperience.
  ///
  /// In ar, this message translates to:
  /// **'اكتب تجربتك مع السائق...'**
  String get writeExperience;

  /// No description provided for @submitRating.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التقييم'**
  String get submitRating;

  /// No description provided for @chatbotWelcome.
  ///
  /// In ar, this message translates to:
  /// **'شكراً لتواصلك معنا. سنساعدك في أقرب وقت.'**
  String get chatbotWelcome;

  /// No description provided for @typeMessage.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالتك...'**
  String get typeMessage;

  /// No description provided for @myTrips.
  ///
  /// In ar, this message translates to:
  /// **'رحلاتي'**
  String get myTrips;

  /// No description provided for @aiAssistant.
  ///
  /// In ar, this message translates to:
  /// **'المساعد الذكي'**
  String get aiAssistant;

  /// No description provided for @privacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyPolicy;

  /// No description provided for @helpAndSupport.
  ///
  /// In ar, this message translates to:
  /// **'المساعدة والدعم'**
  String get helpAndSupport;

  /// No description provided for @complaints.
  ///
  /// In ar, this message translates to:
  /// **'الشكاوي'**
  String get complaints;

  /// No description provided for @language.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In ar, this message translates to:
  /// **'عربي'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In ar, this message translates to:
  /// **'EN'**
  String get english;

  /// No description provided for @appearance.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get appearance;

  /// No description provided for @dark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get light;

  /// No description provided for @userDefault.
  ///
  /// In ar, this message translates to:
  /// **'مستخدم'**
  String get userDefault;

  /// No description provided for @locating.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحديد موقعك...'**
  String get locating;

  /// No description provided for @availableDriver.
  ///
  /// In ar, this message translates to:
  /// **'سائق متاح'**
  String get availableDriver;

  /// No description provided for @whereToGo.
  ///
  /// In ar, this message translates to:
  /// **'إلى أين تريد الذهاب؟'**
  String get whereToGo;

  /// No description provided for @searchDestination.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن وجهتك...'**
  String get searchDestination;

  /// No description provided for @rideSafely.
  ///
  /// In ar, this message translates to:
  /// **'اركب بأمان وراحة'**
  String get rideSafely;

  /// No description provided for @bookNowEnjoy.
  ///
  /// In ar, this message translates to:
  /// **'احجز رحلتك الآن واستمتع بأفضل خدمة'**
  String get bookNowEnjoy;

  /// No description provided for @haveCoupon.
  ///
  /// In ar, this message translates to:
  /// **'لديك كوبون خصم!'**
  String get haveCoupon;

  /// No description provided for @discountWithCode.
  ///
  /// In ar, this message translates to:
  /// **'{discount}% خصم — كود: {code}'**
  String discountWithCode(String discount, String code);

  /// No description provided for @car.
  ///
  /// In ar, this message translates to:
  /// **'سيارة'**
  String get car;

  /// No description provided for @price.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get price;

  /// No description provided for @discount.
  ///
  /// In ar, this message translates to:
  /// **'الخصم'**
  String get discount;

  /// No description provided for @fromPrice.
  ///
  /// In ar, this message translates to:
  /// **'من {price} ر.س'**
  String fromPrice(String price);

  /// No description provided for @paymentMethod.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الدفع'**
  String get paymentMethod;

  /// No description provided for @cash.
  ///
  /// In ar, this message translates to:
  /// **'نقداً'**
  String get cash;

  /// No description provided for @bankCard.
  ///
  /// In ar, this message translates to:
  /// **'بطاقة بنكية'**
  String get bankCard;

  /// No description provided for @haveDiscountCoupon.
  ///
  /// In ar, this message translates to:
  /// **'لديك كوبون خصم؟'**
  String get haveDiscountCoupon;

  /// No description provided for @enterDiscountCode.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كود الخصم'**
  String get enterDiscountCode;

  /// No description provided for @apply.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get apply;

  /// No description provided for @basePrice.
  ///
  /// In ar, this message translates to:
  /// **'السعر الأساسي'**
  String get basePrice;

  /// No description provided for @total.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get total;

  /// No description provided for @selectMeetingPoint.
  ///
  /// In ar, this message translates to:
  /// **'اختر نقطة التقابل'**
  String get selectMeetingPoint;

  /// No description provided for @startingPoint.
  ///
  /// In ar, this message translates to:
  /// **'نقطة البداية'**
  String get startingPoint;

  /// No description provided for @destination.
  ///
  /// In ar, this message translates to:
  /// **'الوجهة'**
  String get destination;

  /// No description provided for @km.
  ///
  /// In ar, this message translates to:
  /// **'كم'**
  String get km;

  /// No description provided for @currencySar.
  ///
  /// In ar, this message translates to:
  /// **'ر.س'**
  String get currencySar;

  /// No description provided for @origin.
  ///
  /// In ar, this message translates to:
  /// **'البداية'**
  String get origin;

  /// No description provided for @searchOrPick.
  ///
  /// In ar, this message translates to:
  /// **'ابحث أو حدد على الخريطة'**
  String get searchOrPick;

  /// No description provided for @whereToGoQ.
  ///
  /// In ar, this message translates to:
  /// **'أين تريد الذهاب؟'**
  String get whereToGoQ;

  /// No description provided for @moveMapForOrigin.
  ///
  /// In ar, this message translates to:
  /// **'حرّك الخريطة لتحديد نقطة البداية'**
  String get moveMapForOrigin;

  /// No description provided for @moveMapForDest.
  ///
  /// In ar, this message translates to:
  /// **'حرّك الخريطة لتحديد الوجهة'**
  String get moveMapForDest;

  /// No description provided for @confirmAndCalculate.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد وحساب السعر'**
  String get confirmAndCalculate;

  /// No description provided for @selectOriginAndDest.
  ///
  /// In ar, this message translates to:
  /// **'حدد نقطة البداية والوجهة'**
  String get selectOriginAndDest;

  /// No description provided for @pleaseSelectOriginAndDest.
  ///
  /// In ar, this message translates to:
  /// **'الرجاء تحديد نقطة البداية والوجهة'**
  String get pleaseSelectOriginAndDest;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @confirmOrigin.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد البداية'**
  String get confirmOrigin;

  /// No description provided for @confirmDest.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الوجهة'**
  String get confirmDest;

  /// No description provided for @locatingPosition.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحديد الموقع...'**
  String get locatingPosition;

  /// No description provided for @moveMapToSelect.
  ///
  /// In ar, this message translates to:
  /// **'حرّك الخريطة للتحديد'**
  String get moveMapToSelect;

  /// No description provided for @meetingPoint.
  ///
  /// In ar, this message translates to:
  /// **'نقطة التقابل'**
  String get meetingPoint;

  /// No description provided for @tapMapToSelect.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على الخريطة لتحديد نقطة التقابل'**
  String get tapMapToSelect;

  /// No description provided for @resetToOrigin.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إلى نقطة البداية'**
  String get resetToOrigin;

  /// No description provided for @searchForDriver.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن سائق'**
  String get searchForDriver;

  /// No description provided for @tripDataIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'بيانات الرحلة غير مكتملة'**
  String get tripDataIncomplete;

  /// No description provided for @pleaseLogin.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تسجيل الدخول أولاً'**
  String get pleaseLogin;

  /// No description provided for @unspecified.
  ///
  /// In ar, this message translates to:
  /// **'غير محدد'**
  String get unspecified;

  /// No description provided for @failedCreateTrip.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إنشاء الرحلة، تحقق من اتصالك وحاول مجدداً'**
  String get failedCreateTrip;

  /// No description provided for @yourTrip.
  ///
  /// In ar, this message translates to:
  /// **'رحلتك'**
  String get yourTrip;

  /// No description provided for @minute.
  ///
  /// In ar, this message translates to:
  /// **'دقيقة'**
  String get minute;

  /// No description provided for @searchingForDriver.
  ///
  /// In ar, this message translates to:
  /// **'جاري البحث عن سائق قريب...'**
  String get searchingForDriver;

  /// No description provided for @willContactOnFind.
  ///
  /// In ar, this message translates to:
  /// **'سيتم الاتصال بك فور العثور على سائق'**
  String get willContactOnFind;

  /// No description provided for @cancelSearch.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء البحث'**
  String get cancelSearch;

  /// No description provided for @tripAccepted.
  ///
  /// In ar, this message translates to:
  /// **'تم قبول الرحلة!'**
  String get tripAccepted;

  /// No description provided for @loadingDriverDetails.
  ///
  /// In ar, this message translates to:
  /// **'يتم تحميل تفاصيل السائق...'**
  String get loadingDriverDetails;

  /// No description provided for @noDriversFound.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد سائقاً متاحاً'**
  String get noDriversFound;

  /// No description provided for @tryAgainOrDifferentTime.
  ///
  /// In ar, this message translates to:
  /// **'حاول مرة أخرى أو اختر وقتاً مختلفاً'**
  String get tryAgainOrDifferentTime;

  /// No description provided for @searchCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء البحث'**
  String get searchCancelled;

  /// No description provided for @canSearchAnytime.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك البحث عن رحلة جديدة في أي وقت'**
  String get canSearchAnytime;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @noDriverAvailable.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد سائق متاح الآن'**
  String get noDriverAvailable;

  /// No description provided for @tryAgainLater.
  ///
  /// In ar, this message translates to:
  /// **'جرّب مرة أخرى أو عد لاحقاً'**
  String get tryAgainLater;

  /// No description provided for @backToHome.
  ///
  /// In ar, this message translates to:
  /// **'العودة للرئيسية'**
  String get backToHome;

  /// No description provided for @trackTrip.
  ///
  /// In ar, this message translates to:
  /// **'تتبع الرحلة'**
  String get trackTrip;

  /// No description provided for @theDriver.
  ///
  /// In ar, this message translates to:
  /// **'السائق'**
  String get theDriver;

  /// No description provided for @meetingPointLabel.
  ///
  /// In ar, this message translates to:
  /// **'نقطة الالتقاء'**
  String get meetingPointLabel;

  /// No description provided for @cancelTrip.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الرحلة'**
  String get cancelTrip;

  /// No description provided for @noTrips.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات'**
  String get noTrips;

  /// No description provided for @rate.
  ///
  /// In ar, this message translates to:
  /// **'قيّم'**
  String get rate;

  /// No description provided for @completed.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغاة'**
  String get cancelled;

  /// No description provided for @inProgress.
  ///
  /// In ar, this message translates to:
  /// **'جارية'**
  String get inProgress;

  /// No description provided for @pending.
  ///
  /// In ar, this message translates to:
  /// **'معلقة'**
  String get pending;

  /// No description provided for @details.
  ///
  /// In ar, this message translates to:
  /// **'التفاصيل'**
  String get details;

  /// No description provided for @editProfile.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي'**
  String get editProfile;

  /// No description provided for @saveChanges.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التغييرات'**
  String get saveChanges;

  /// No description provided for @changesSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ التغييرات بنجاح'**
  String get changesSaved;

  /// No description provided for @yourLocation.
  ///
  /// In ar, this message translates to:
  /// **'موقعك الحالي'**
  String get yourLocation;

  /// No description provided for @availableForTrips.
  ///
  /// In ar, this message translates to:
  /// **'متاح للرحلات'**
  String get availableForTrips;

  /// No description provided for @unavailable.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح'**
  String get unavailable;

  /// No description provided for @trips.
  ///
  /// In ar, this message translates to:
  /// **'الرحلات'**
  String get trips;

  /// No description provided for @earnings.
  ///
  /// In ar, this message translates to:
  /// **'الإيرادات'**
  String get earnings;

  /// No description provided for @rating.
  ///
  /// In ar, this message translates to:
  /// **'التقييم'**
  String get rating;

  /// No description provided for @newTripRequest.
  ///
  /// In ar, this message translates to:
  /// **'طلب رحلة جديد'**
  String get newTripRequest;

  /// No description provided for @reject.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get reject;

  /// No description provided for @acceptTrip.
  ///
  /// In ar, this message translates to:
  /// **'قبول الرحلة'**
  String get acceptTrip;

  /// No description provided for @yourRating.
  ///
  /// In ar, this message translates to:
  /// **'تقييمك: {value}'**
  String yourRating(String value);

  /// No description provided for @tripDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الرحلة'**
  String get tripDetails;

  /// No description provided for @startTrip.
  ///
  /// In ar, this message translates to:
  /// **'بدء الرحلة'**
  String get startTrip;

  /// No description provided for @completeTrip.
  ///
  /// In ar, this message translates to:
  /// **'إكمال الرحلة'**
  String get completeTrip;

  /// No description provided for @tripCompleted.
  ///
  /// In ar, this message translates to:
  /// **'تم إكمال الرحلة بنجاح'**
  String get tripCompleted;

  /// No description provided for @distance.
  ///
  /// In ar, this message translates to:
  /// **'المسافة'**
  String get distance;

  /// No description provided for @failedLoadCoupons.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تحميل الكوبونات'**
  String get failedLoadCoupons;

  /// No description provided for @invalidCouponCode.
  ///
  /// In ar, this message translates to:
  /// **'كود الكوبون غير صالح'**
  String get invalidCouponCode;

  /// No description provided for @failedValidateCoupon.
  ///
  /// In ar, this message translates to:
  /// **'فشل في التحقق من الكوبون'**
  String get failedValidateCoupon;

  /// No description provided for @failedApplyCoupon.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تطبيق الكوبون'**
  String get failedApplyCoupon;

  /// No description provided for @errorCreateTrip.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء إنشاء الرحلة'**
  String get errorCreateTrip;

  /// No description provided for @errorFetchTrips.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء جلب الرحلات'**
  String get errorFetchTrips;

  /// No description provided for @errorCancelTrip.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء إلغاء الرحلة'**
  String get errorCancelTrip;

  /// No description provided for @errorUpdateTripStatus.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تحديث حالة الرحلة'**
  String get errorUpdateTripStatus;

  /// No description provided for @errorFetchAvailable.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء جلب الرحلات المتاحة'**
  String get errorFetchAvailable;

  /// No description provided for @editProfileLabel.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف'**
  String get editProfileLabel;

  /// No description provided for @totalTrips.
  ///
  /// In ar, this message translates to:
  /// **'عدد الرحلات'**
  String get totalTrips;

  /// No description provided for @driverHomeDesc.
  ///
  /// In ar, this message translates to:
  /// **'شاشة السائق الرئيسية'**
  String get driverHomeDesc;

  /// No description provided for @startWorking.
  ///
  /// In ar, this message translates to:
  /// **'بدء العمل'**
  String get startWorking;

  /// No description provided for @tripLog.
  ///
  /// In ar, this message translates to:
  /// **'سجل الرحلات'**
  String get tripLog;

  /// No description provided for @sampleNotification.
  ///
  /// In ar, this message translates to:
  /// **'إشعار تجريبي'**
  String get sampleNotification;

  /// No description provided for @sampleNotificationMsg.
  ///
  /// In ar, this message translates to:
  /// **'هذا إشعار تجريبي للتطبيق'**
  String get sampleNotificationMsg;

  /// No description provided for @minutesAgo.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} دقيقة'**
  String minutesAgo(int count);

  /// No description provided for @driverLabel.
  ///
  /// In ar, this message translates to:
  /// **'سائق {index}'**
  String driverLabel(int index);

  /// No description provided for @sampleMessage.
  ///
  /// In ar, this message translates to:
  /// **'هذه رسالة تجريبية'**
  String get sampleMessage;

  /// No description provided for @supportReply.
  ///
  /// In ar, this message translates to:
  /// **'شكراً على رسالتك. سيقوم فريق الدعم بالرد عليك قريباً.'**
  String get supportReply;

  /// No description provided for @supportAssistant.
  ///
  /// In ar, this message translates to:
  /// **'مساعد الدعم'**
  String get supportAssistant;

  /// No description provided for @welcomeSupport.
  ///
  /// In ar, this message translates to:
  /// **'مرحباً بك في مساعد الدعم'**
  String get welcomeSupport;

  /// No description provided for @howCanHelp.
  ///
  /// In ar, this message translates to:
  /// **'كيف يمكنني مساعدتك اليوم؟'**
  String get howCanHelp;

  /// No description provided for @thanksForRating.
  ///
  /// In ar, this message translates to:
  /// **'شكراً على تقييمك!'**
  String get thanksForRating;

  /// No description provided for @returningHome.
  ///
  /// In ar, this message translates to:
  /// **'جاري العودة للصفحة الرئيسية...'**
  String get returningHome;

  /// No description provided for @addCommentOptional.
  ///
  /// In ar, this message translates to:
  /// **'أضف تعليقاً (اختياري)'**
  String get addCommentOptional;

  /// No description provided for @shareExperience.
  ///
  /// In ar, this message translates to:
  /// **'شارك تجربتك معنا'**
  String get shareExperience;

  /// No description provided for @unknownInitial.
  ///
  /// In ar, this message translates to:
  /// **'؟'**
  String get unknownInitial;

  /// No description provided for @availableCoupons.
  ///
  /// In ar, this message translates to:
  /// **'الكوبونات المتاحة'**
  String get availableCoupons;

  /// No description provided for @pickupLocation.
  ///
  /// In ar, this message translates to:
  /// **'موقع الاستلام'**
  String get pickupLocation;

  /// No description provided for @tripRequest.
  ///
  /// In ar, this message translates to:
  /// **'طلب رحلة'**
  String get tripRequest;

  /// No description provided for @searchForDriverBtn.
  ///
  /// In ar, this message translates to:
  /// **'بحث عن سائق'**
  String get searchForDriverBtn;

  /// No description provided for @verified.
  ///
  /// In ar, this message translates to:
  /// **'موثّق'**
  String get verified;

  /// No description provided for @documents.
  ///
  /// In ar, this message translates to:
  /// **'الوثائق'**
  String get documents;

  /// No description provided for @vehicleInfo.
  ///
  /// In ar, this message translates to:
  /// **'معلومات المركبة'**
  String get vehicleInfo;

  /// No description provided for @driverLicense.
  ///
  /// In ar, this message translates to:
  /// **'رخصة القيادة'**
  String get driverLicense;

  /// No description provided for @criminalRecord.
  ///
  /// In ar, this message translates to:
  /// **'الفيش والتشبيه'**
  String get criminalRecord;

  /// No description provided for @uploaded.
  ///
  /// In ar, this message translates to:
  /// **'مرفوع'**
  String get uploaded;

  /// No description provided for @notUploaded.
  ///
  /// In ar, this message translates to:
  /// **'غير مرفوع'**
  String get notUploaded;

  /// No description provided for @invalidPhoneFormat.
  ///
  /// In ar, this message translates to:
  /// **'صيغة رقم الهاتف غير صحيحة'**
  String get invalidPhoneFormat;

  /// No description provided for @invalidEmailFormat.
  ///
  /// In ar, this message translates to:
  /// **'صيغة البريد الإلكتروني غير صحيحة'**
  String get invalidEmailFormat;

  /// No description provided for @justNow.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get justNow;

  /// No description provided for @hoursAgo.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} ساعة'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In ar, this message translates to:
  /// **'منذ {count} يوم'**
  String daysAgo(int count);

  /// No description provided for @failedLoadNotifications.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تحميل الإشعارات'**
  String get failedLoadNotifications;

  /// No description provided for @totalTripsLabel.
  ///
  /// In ar, this message translates to:
  /// **'{total} رحلة'**
  String totalTripsLabel(int total);

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get yesterday;

  /// No description provided for @thisWeek.
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get thisWeek;

  /// No description provided for @noActiveTrips.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رحلات نشطة حالياً'**
  String get noActiveTrips;

  /// No description provided for @tripsWillAppearHere.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر رحلاتك هنا'**
  String get tripsWillAppearHere;

  /// No description provided for @newCustomer.
  ///
  /// In ar, this message translates to:
  /// **'عميل جديد'**
  String get newCustomer;

  /// No description provided for @failedLoadMessages.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تحميل الرسائل'**
  String get failedLoadMessages;

  /// No description provided for @newMessage.
  ///
  /// In ar, this message translates to:
  /// **'رسالة جديدة'**
  String get newMessage;

  /// No description provided for @newMessageFrom.
  ///
  /// In ar, this message translates to:
  /// **'رسالة جديدة من {name}'**
  String newMessageFrom(String name);

  /// No description provided for @failedSendMessage.
  ///
  /// In ar, this message translates to:
  /// **'فشل في إرسال الرسالة'**
  String get failedSendMessage;

  /// No description provided for @theChat.
  ///
  /// In ar, this message translates to:
  /// **'المحادثة'**
  String get theChat;

  /// No description provided for @startChat.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ المحادثة'**
  String get startChat;

  /// No description provided for @areYouSureCancelTrip.
  ///
  /// In ar, this message translates to:
  /// **'هل أنت متأكد من إلغاء هذه الرحلة؟'**
  String get areYouSureCancelTrip;

  /// No description provided for @noLabel.
  ///
  /// In ar, this message translates to:
  /// **'لا'**
  String get noLabel;

  /// No description provided for @yesCancel.
  ///
  /// In ar, this message translates to:
  /// **'نعم، إلغاء'**
  String get yesCancel;

  /// No description provided for @submitComplaint.
  ///
  /// In ar, this message translates to:
  /// **'تقديم شكوى'**
  String get submitComplaint;

  /// No description provided for @send.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get send;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني أو كلمة المرور غير صحيحة'**
  String get errorInvalidCredentials;

  /// No description provided for @errorEmailRegistered.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد الإلكتروني مسجّل بالفعل'**
  String get errorEmailRegistered;

  /// No description provided for @errorConfirmEmail.
  ///
  /// In ar, this message translates to:
  /// **'يرجى تأكيد بريدك الإلكتروني أولاً'**
  String get errorConfirmEmail;

  /// No description provided for @errorPasswordLength.
  ///
  /// In ar, this message translates to:
  /// **'كلمة المرور يجب أن تكون 6 أحرف على الأقل'**
  String get errorPasswordLength;

  /// No description provided for @errorNoInternet.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالإنترنت، تحقق من الشبكة'**
  String get errorNoInternet;

  /// No description provided for @errorRateLimit.
  ///
  /// In ar, this message translates to:
  /// **'تم تجاوز الحد المسموح، حاول مجدداً بعد قليل'**
  String get errorRateLimit;

  /// No description provided for @errorUserNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العثور على بيانات المستخدم'**
  String get errorUserNotFound;

  /// No description provided for @errorUnexpected.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع، حاول مجدداً'**
  String get errorUnexpected;

  /// No description provided for @errorLoginFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تسجيل الدخول'**
  String get errorLoginFailed;

  /// No description provided for @errorCreateAccountFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل إنشاء الحساب'**
  String get errorCreateAccountFailed;

  /// No description provided for @failedFetchTrips.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء جلب الرحلات'**
  String get failedFetchTrips;

  /// No description provided for @failedCancelTrip.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء إلغاء الرحلة'**
  String get failedCancelTrip;

  /// No description provided for @failedUpdateTrip.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء تحديث حالة الرحلة'**
  String get failedUpdateTrip;

  /// No description provided for @failedFetchAvailableTrips.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء جلب الرحلات المتاحة'**
  String get failedFetchAvailableTrips;

  /// No description provided for @errorActiveTripExists.
  ///
  /// In ar, this message translates to:
  /// **'لديك رحلة جارية بالفعل. يرجى إنهاؤها أو إلغاؤها أولاً.'**
  String get errorActiveTripExists;

  /// No description provided for @errorLoadTripDetails.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تحميل تفاصيل الرحلة'**
  String get errorLoadTripDetails;

  /// No description provided for @errorAcceptTrip.
  ///
  /// In ar, this message translates to:
  /// **'فشل في قبول الرحلة'**
  String get errorAcceptTrip;

  /// No description provided for @errorRejectTrip.
  ///
  /// In ar, this message translates to:
  /// **'فشل في رفض الرحلة'**
  String get errorRejectTrip;

  /// No description provided for @errorStartTrip.
  ///
  /// In ar, this message translates to:
  /// **'فشل في بدء الرحلة'**
  String get errorStartTrip;

  /// No description provided for @errorCompleteTrip.
  ///
  /// In ar, this message translates to:
  /// **'فشل في إكمال الرحلة'**
  String get errorCompleteTrip;

  /// No description provided for @errorNotLoggedIn.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم تسجيل الدخول'**
  String get errorNotLoggedIn;

  /// No description provided for @call.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get call;

  /// No description provided for @track.
  ///
  /// In ar, this message translates to:
  /// **'تتبع'**
  String get track;

  /// No description provided for @fareDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل السعر'**
  String get fareDetails;

  /// No description provided for @paid.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع'**
  String get paid;

  /// No description provided for @unpaid.
  ///
  /// In ar, this message translates to:
  /// **'غير مدفوع'**
  String get unpaid;

  /// No description provided for @timeline.
  ///
  /// In ar, this message translates to:
  /// **'الجدول الزمني'**
  String get timeline;

  /// No description provided for @tripRated.
  ///
  /// In ar, this message translates to:
  /// **'تم تقييم الرحلة'**
  String get tripRated;

  /// No description provided for @complaintSubject.
  ///
  /// In ar, this message translates to:
  /// **'عنوان الشكوى'**
  String get complaintSubject;

  /// No description provided for @complaintSubjectHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: تأخر السائق'**
  String get complaintSubjectHint;

  /// No description provided for @complaintDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الشكوى'**
  String get complaintDetails;

  /// No description provided for @complaintDetailsHint.
  ///
  /// In ar, this message translates to:
  /// **'اشرح المشكلة بالتفصيل...'**
  String get complaintDetailsHint;

  /// No description provided for @bookNewTrip.
  ///
  /// In ar, this message translates to:
  /// **'حجز رحلة جديدة'**
  String get bookNewTrip;

  /// No description provided for @yourTripsWillAppearHere.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر رحلاتك هنا'**
  String get yourTripsWillAppearHere;

  /// No description provided for @newTripLabel.
  ///
  /// In ar, this message translates to:
  /// **'رحلة جديدة'**
  String get newTripLabel;

  /// No description provided for @trip.
  ///
  /// In ar, this message translates to:
  /// **'رحلة'**
  String get trip;

  /// No description provided for @statusAccepted.
  ///
  /// In ar, this message translates to:
  /// **'تم القبول'**
  String get statusAccepted;

  /// No description provided for @statusSearching.
  ///
  /// In ar, this message translates to:
  /// **'جاري البحث'**
  String get statusSearching;

  /// No description provided for @errorLoadTrips.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تحميل الرحلات'**
  String get errorLoadTrips;

  /// No description provided for @errorNotYourTrip.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك إلغاء رحلة ليست لك'**
  String get errorNotYourTrip;

  /// No description provided for @errorCancelStatus.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إلغاء رحلة في هذه الحالة'**
  String get errorCancelStatus;

  /// No description provided for @successTripCancelled.
  ///
  /// In ar, this message translates to:
  /// **'تم إلغاء الرحلة بنجاح'**
  String get successTripCancelled;

  /// No description provided for @successComplaintSent.
  ///
  /// In ar, this message translates to:
  /// **'تم إرسال الشكوى بنجاح'**
  String get successComplaintSent;

  /// No description provided for @errorSendComplaint.
  ///
  /// In ar, this message translates to:
  /// **'فشل في إرسال الشكوى'**
  String get errorSendComplaint;

  /// No description provided for @errorCalculatePrice.
  ///
  /// In ar, this message translates to:
  /// **'فشل في حساب السعر'**
  String get errorCalculatePrice;

  /// No description provided for @errorWaitBeforeRetry.
  ///
  /// In ar, this message translates to:
  /// **'يرجى الانتظار قبل المحاولة مرة أخرى'**
  String get errorWaitBeforeRetry;

  /// No description provided for @errorInvalidCoupon.
  ///
  /// In ar, this message translates to:
  /// **'كود الكوبون غير صالح'**
  String get errorInvalidCoupon;

  /// No description provided for @errorCouponDepleted.
  ///
  /// In ar, this message translates to:
  /// **'تم استنفاد هذا الكوبون'**
  String get errorCouponDepleted;

  /// No description provided for @errorCouponUsed.
  ///
  /// In ar, this message translates to:
  /// **'لقد استخدمت هذا الكوبون مسبقاً'**
  String get errorCouponUsed;

  /// No description provided for @errorApplyCoupon.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تطبيق الكوبون'**
  String get errorApplyCoupon;

  /// No description provided for @errorLoadCoupons.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تحميل الكوبونات'**
  String get errorLoadCoupons;

  /// No description provided for @errorVerifyCoupon.
  ///
  /// In ar, this message translates to:
  /// **'فشل في التحقق من الكوبون'**
  String get errorVerifyCoupon;

  /// No description provided for @errorNoDriverForTrip.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد سائق لهذه الرحلة'**
  String get errorNoDriverForTrip;

  /// No description provided for @errorTripAlreadyRated.
  ///
  /// In ar, this message translates to:
  /// **'تم تقييم هذه الرحلة مسبقاً'**
  String get errorTripAlreadyRated;

  /// No description provided for @errorAlreadyRated.
  ///
  /// In ar, this message translates to:
  /// **'تم التقييم مسبقاً'**
  String get errorAlreadyRated;

  /// No description provided for @errorSubmitRating.
  ///
  /// In ar, this message translates to:
  /// **'فشل في إرسال التقييم'**
  String get errorSubmitRating;

  /// No description provided for @currentLocation.
  ///
  /// In ar, this message translates to:
  /// **'موقعك الحالي'**
  String get currentLocation;

  /// No description provided for @errorGetLocation.
  ///
  /// In ar, this message translates to:
  /// **'فشل في الحصول على موقعك. تحقق من الصلاحيات'**
  String get errorGetLocation;

  /// No description provided for @errorLocationNotFound.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم العثور على الموقع'**
  String get errorLocationNotFound;

  /// No description provided for @errorSearchLocation.
  ///
  /// In ar, this message translates to:
  /// **'فشل في البحث عن الموقع'**
  String get errorSearchLocation;

  /// No description provided for @errorLoadProfile.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تحميل الملف الشخصي'**
  String get errorLoadProfile;

  /// No description provided for @errorNoValidDataToUpdate.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بيانات صالحة للتحديث'**
  String get errorNoValidDataToUpdate;

  /// No description provided for @errorUpdateProfile.
  ///
  /// In ar, this message translates to:
  /// **'فشل في تحديث الملف الشخصي'**
  String get errorUpdateProfile;

  /// No description provided for @errorDetermineLocation.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحديد موقعك. تأكد من تفعيل خدمات الموقع.'**
  String get errorDetermineLocation;

  /// No description provided for @errorFileTooLarge.
  ///
  /// In ar, this message translates to:
  /// **'حجم الملف كبير جداً'**
  String get errorFileTooLarge;

  /// No description provided for @errorFileEmpty.
  ///
  /// In ar, this message translates to:
  /// **'الملف فارغ'**
  String get errorFileEmpty;

  /// No description provided for @errorFileUnsupported.
  ///
  /// In ar, this message translates to:
  /// **'نوع الملف غير مدعوم'**
  String get errorFileUnsupported;

  /// No description provided for @pleaseFillAllFields.
  ///
  /// In ar, this message translates to:
  /// **'يرجى ملء جميع الحقول'**
  String get pleaseFillAllFields;

  /// No description provided for @describeIssueDetail.
  ///
  /// In ar, this message translates to:
  /// **'يرجى وصف مشكلتك بالتفصيل.'**
  String get describeIssueDetail;

  /// No description provided for @titleLabel.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get titleLabel;

  /// No description provided for @descriptionLabel.
  ///
  /// In ar, this message translates to:
  /// **'الوصف'**
  String get descriptionLabel;

  /// No description provided for @editProfileComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الملف الشخصي قريباً'**
  String get editProfileComingSoon;
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
