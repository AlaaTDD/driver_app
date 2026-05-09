// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Taxi';

  @override
  String get home => 'Home';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get logout => 'Logout';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get notifications => 'Notifications';

  @override
  String get messages => 'Messages';

  @override
  String get help => 'Help';

  @override
  String get smartTransportService => 'Smart & Fast Transport Service';

  @override
  String get skip => 'Skip';

  @override
  String get smartRideService => 'Smart Ride Service';

  @override
  String get smartRideDesc =>
      'Book your ride with one tap and wait for the driver to arrive in minutes';

  @override
  String get realTimeTracking => 'Real-Time Tracking';

  @override
  String get realTimeTrackingDesc =>
      'Track your driver\'s location moment by moment on the map until they reach you precisely';

  @override
  String get safeAndReliable => 'Safe & Reliable';

  @override
  String get safeAndReliableDesc =>
      'All drivers are verified and certified to ensure your safety and comfort on every ride';

  @override
  String get loginTitle => 'Sign in to continue';

  @override
  String get email => 'Email';

  @override
  String get enterEmail => 'Please enter your email';

  @override
  String get password => 'Password';

  @override
  String get enterPassword => 'Please enter your password';

  @override
  String get noAccount => 'Don\'t have an account? ';

  @override
  String get registerNow => 'Register now';

  @override
  String get chooseAccountType => 'Choose your account type';

  @override
  String get chooseRoleDesc => 'Select the role that suits you to get started';

  @override
  String get user => 'User';

  @override
  String get userDesc =>
      'Book your rides easily and travel safely and comfortably';

  @override
  String get driver => 'Driver';

  @override
  String get driverDesc => 'Join the Snapix driver team and earn more';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get createUserAccount => 'Create User Account';

  @override
  String get personalInfo => 'Your Personal Information';

  @override
  String get enterDataToCreateAccount =>
      'Enter your data to create your account';

  @override
  String get basicData => 'Basic Data';

  @override
  String get fullName => 'Full Name';

  @override
  String get enterFullName => 'Please enter your full name';

  @override
  String get phone => 'Phone Number';

  @override
  String get enterPhone => 'Please enter your phone number';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get pleaseConfirmPassword => 'Please confirm your password';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get createAccount => 'Create Account';

  @override
  String get passwordsNotMatch => 'Passwords don\'t match';

  @override
  String get createDriverAccount => 'Create Driver Account';

  @override
  String get personalInformation => 'Personal Information';

  @override
  String get nationalId => 'National ID Number';

  @override
  String get enterNationalId => 'Please enter your national ID';

  @override
  String get nationalIdPhoto => 'National ID Photo';

  @override
  String get licenseNumber => 'License Number';

  @override
  String get enterLicenseNumber => 'Please enter your license number';

  @override
  String get licensePhoto => 'Driving License Photo';

  @override
  String get backgroundCheckPhoto => 'Background Check Photo';

  @override
  String get requiredDocuments => 'Required Documents';

  @override
  String get vehicleType => 'Vehicle Type';

  @override
  String get sedan => 'Sedan';

  @override
  String get suv => 'SUV';

  @override
  String get van => 'Van';

  @override
  String get minibus => 'Minibus';

  @override
  String get motorcycle => 'Motorcycle';

  @override
  String get vehicleBrand => 'Vehicle Brand';

  @override
  String get enterVehicleBrand => 'Please enter vehicle brand';

  @override
  String get vehicleModel => 'Vehicle Model';

  @override
  String get enterVehicleModel => 'Please enter vehicle model';

  @override
  String get vehicleYear => 'Vehicle Year';

  @override
  String get enterVehicleYear => 'Please enter vehicle year';

  @override
  String get vehicleColor => 'Vehicle Color';

  @override
  String get enterVehicleColor => 'Please enter vehicle color';

  @override
  String get plateNumber => 'Plate Number';

  @override
  String get enterPlateNumber => 'Please enter plate number';

  @override
  String get vehiclePhoto => 'Vehicle Photo';

  @override
  String get uploadAllDocuments =>
      'Please upload all required documents and photos';

  @override
  String get accountUnderReview => 'Your account is under review';

  @override
  String get reviewDesc =>
      'We are reviewing your data and will notify you once done';

  @override
  String get rateTrip => 'Rate Trip';

  @override
  String get howWasTrip => 'How was your trip?';

  @override
  String get addComment => 'Add your comment (optional)';

  @override
  String get writeExperience => 'Write your experience with the driver...';

  @override
  String get submitRating => 'Submit Rating';

  @override
  String get chatbotWelcome =>
      'Thank you for contacting us. We\'ll help you soon.';

  @override
  String get typeMessage => 'Type your message...';

  @override
  String get myTrips => 'My Trips';

  @override
  String get aiAssistant => 'AI Assistant';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get complaints => 'Complaints';

  @override
  String get language => 'Language';

  @override
  String get arabic => 'Arabic';

  @override
  String get english => 'English';

  @override
  String get appearance => 'Appearance';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get userDefault => 'User';

  @override
  String get locating => 'Locating your position...';

  @override
  String get availableDriver => 'Available Driver';

  @override
  String get whereToGo => 'Where do you want to go?';

  @override
  String get searchDestination => 'Search for your destination...';

  @override
  String get rideSafely => 'Ride safely and comfortably';

  @override
  String get bookNowEnjoy => 'Book your ride now and enjoy the best service';

  @override
  String get haveCoupon => 'You have a discount coupon!';

  @override
  String discountWithCode(String discount, String code) {
    return '$discount% off — Code: $code';
  }

  @override
  String get car => 'Car';

  @override
  String get price => 'Price';

  @override
  String get discount => 'Discount';

  @override
  String fromPrice(String price) {
    return 'From $price SAR';
  }

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get cash => 'Cash';

  @override
  String get bankCard => 'Bank Card';

  @override
  String get haveDiscountCoupon => 'Have a discount coupon?';

  @override
  String get enterDiscountCode => 'Enter discount code';

  @override
  String get apply => 'Apply';

  @override
  String get basePrice => 'Base Price';

  @override
  String get total => 'Total';

  @override
  String get selectMeetingPoint => 'Select Meeting Point';

  @override
  String get startingPoint => 'Starting Point';

  @override
  String get destination => 'Destination';

  @override
  String get km => 'km';

  @override
  String get currencySar => 'SAR';

  @override
  String get origin => 'Origin';

  @override
  String get searchOrPick => 'Search or pick on map';

  @override
  String get whereToGoQ => 'Where do you want to go?';

  @override
  String get moveMapForOrigin => 'Move the map to set the starting point';

  @override
  String get moveMapForDest => 'Move the map to set the destination';

  @override
  String get confirmAndCalculate => 'Confirm & Calculate Price';

  @override
  String get selectOriginAndDest => 'Select origin and destination';

  @override
  String get pleaseSelectOriginAndDest =>
      'Please select origin and destination';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmOrigin => 'Confirm Origin';

  @override
  String get confirmDest => 'Confirm Destination';

  @override
  String get locatingPosition => 'Locating position...';

  @override
  String get moveMapToSelect => 'Move the map to select';

  @override
  String get meetingPoint => 'Meeting Point';

  @override
  String get tapMapToSelect => 'Tap the map to set the meeting point';

  @override
  String get resetToOrigin => 'Reset to origin';

  @override
  String get searchForDriver => 'Search for driver';

  @override
  String get tripDataIncomplete => 'Trip data is incomplete';

  @override
  String get pleaseLogin => 'Please login first';

  @override
  String get unspecified => 'Unspecified';

  @override
  String get failedCreateTrip =>
      'Failed to create trip, check your connection and try again';

  @override
  String get yourTrip => 'Your Trip';

  @override
  String get minute => 'min';

  @override
  String get searchingForDriver => 'Searching for a nearby driver...';

  @override
  String get willContactOnFind => 'You\'ll be contacted once a driver is found';

  @override
  String get cancelSearch => 'Cancel Search';

  @override
  String get tripAccepted => 'Trip accepted!';

  @override
  String get loadingDriverDetails => 'Loading driver details...';

  @override
  String get noDriversFound => 'No available drivers found';

  @override
  String get tryAgainOrDifferentTime => 'Try again or choose a different time';

  @override
  String get searchCancelled => 'Search cancelled';

  @override
  String get canSearchAnytime => 'You can search for a new ride anytime';

  @override
  String get retry => 'Retry';

  @override
  String get noDriverAvailable => 'No driver available right now';

  @override
  String get tryAgainLater => 'Try again or come back later';

  @override
  String get backToHome => 'Back to Home';

  @override
  String get trackTrip => 'Track Trip';

  @override
  String get theDriver => 'Driver';

  @override
  String get meetingPointLabel => 'Meeting Point';

  @override
  String get cancelTrip => 'Cancel Trip';

  @override
  String get noTrips => 'No trips';

  @override
  String get rate => 'Rate';

  @override
  String get completed => 'Completed';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get inProgress => 'In Progress';

  @override
  String get pending => 'Pending';

  @override
  String get details => 'Details';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get changesSaved => 'Changes saved successfully';

  @override
  String get yourLocation => 'Your current location';

  @override
  String get availableForTrips => 'Available for trips';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get trips => 'Trips';

  @override
  String get earnings => 'Earnings';

  @override
  String get rating => 'Rating';

  @override
  String get newTripRequest => 'New Trip Request';

  @override
  String get reject => 'Reject';

  @override
  String get acceptTrip => 'Accept Trip';

  @override
  String yourRating(String value) {
    return 'Your Rating: $value';
  }

  @override
  String get tripDetails => 'Trip Details';

  @override
  String get startTrip => 'Start Trip';

  @override
  String get completeTrip => 'Complete Trip';

  @override
  String get tripCompleted => 'Trip completed successfully';

  @override
  String get distance => 'Distance';

  @override
  String get failedLoadCoupons => 'Failed to load coupons';

  @override
  String get invalidCouponCode => 'Invalid coupon code';

  @override
  String get failedValidateCoupon => 'Failed to validate coupon';

  @override
  String get failedApplyCoupon => 'Failed to apply coupon';

  @override
  String get errorCreateTrip => 'Error creating trip';

  @override
  String get errorFetchTrips => 'Error fetching trips';

  @override
  String get errorCancelTrip => 'Error cancelling trip';

  @override
  String get errorUpdateTripStatus => 'Error updating trip status';

  @override
  String get errorFetchAvailable => 'Error fetching available trips';

  @override
  String get editProfileLabel => 'Edit Profile';

  @override
  String get totalTrips => 'Total Trips';

  @override
  String get driverHomeDesc => 'Driver Home Screen';

  @override
  String get startWorking => 'Start Working';

  @override
  String get tripLog => 'Trip Log';

  @override
  String get sampleNotification => 'Sample Notification';

  @override
  String get sampleNotificationMsg =>
      'This is a sample notification for the app';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String driverLabel(int index) {
    return 'Driver $index';
  }

  @override
  String get sampleMessage => 'This is a sample message';

  @override
  String get supportReply =>
      'Thank you for your message. Our support team will reply to you soon.';

  @override
  String get supportAssistant => 'Support Assistant';

  @override
  String get welcomeSupport => 'Welcome to Support Assistant';

  @override
  String get howCanHelp => 'How can I help you today?';

  @override
  String get thanksForRating => 'Thanks for your rating!';

  @override
  String get returningHome => 'Returning to home page...';

  @override
  String get addCommentOptional => 'Add a comment (optional)';

  @override
  String get shareExperience => 'Share your experience with us';

  @override
  String get unknownInitial => '?';

  @override
  String get availableCoupons => 'Available Coupons';

  @override
  String get pickupLocation => 'Pickup Location';

  @override
  String get tripRequest => 'Trip Request';

  @override
  String get searchForDriverBtn => 'Search for Driver';

  @override
  String get verified => 'Verified';

  @override
  String get documents => 'Documents';

  @override
  String get vehicleInfo => 'Vehicle Information';

  @override
  String get driverLicense => 'Driver License';

  @override
  String get criminalRecord => 'Criminal Record';

  @override
  String get uploaded => 'Uploaded';

  @override
  String get notUploaded => 'Not Uploaded';

  @override
  String get invalidPhoneFormat => 'Invalid phone format';

  @override
  String get invalidEmailFormat => 'Invalid email format';

  @override
  String get justNow => 'Just now';

  @override
  String hoursAgo(int count) {
    return '$count hours ago';
  }

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get failedLoadNotifications => 'Failed to load notifications';

  @override
  String totalTripsLabel(int total) {
    return '$total trips';
  }

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get thisWeek => 'This Week';

  @override
  String get noActiveTrips => 'No active trips currently';

  @override
  String get tripsWillAppearHere => 'Your trips will appear here';

  @override
  String get newCustomer => 'New Customer';

  @override
  String get passenger => 'Passenger';

  @override
  String get failedLoadMessages => 'Failed to load messages';

  @override
  String get newMessage => 'New message';

  @override
  String newMessageFrom(String name) {
    return 'New message from $name';
  }

  @override
  String get failedSendMessage => 'Failed to send message';

  @override
  String get theChat => 'Chat';

  @override
  String get startChat => 'Start chat';

  @override
  String get noMessages => 'No messages yet';

  @override
  String get online => 'Online';

  @override
  String get areYouSureCancelTrip =>
      'Are you sure you want to cancel this trip?';

  @override
  String get areYouSureRejectTrip =>
      'Are you sure you want to reject this trip?';

  @override
  String get areYouSureCompleteTrip =>
      'Are you sure you want to complete this trip?';

  @override
  String get noLabel => 'No';

  @override
  String get yesCancel => 'Yes, Cancel';

  @override
  String get submitComplaint => 'Submit Complaint';

  @override
  String get send => 'Send';

  @override
  String get errorInvalidCredentials => 'Invalid email or password';

  @override
  String get errorEmailRegistered => 'This email is already registered';

  @override
  String get errorConfirmEmail => 'Please confirm your email first';

  @override
  String get errorPasswordLength => 'Password must be at least 6 characters';

  @override
  String get errorNoInternet =>
      'No internet connection, please check your network';

  @override
  String get errorRateLimit => 'Rate limit exceeded, please try again later';

  @override
  String get errorUserNotFound => 'User data not found';

  @override
  String get errorUnexpected =>
      'An unexpected error occurred, please try again';

  @override
  String get errorLoginFailed => 'Login failed';

  @override
  String get errorCreateAccountFailed => 'Failed to create account';

  @override
  String get failedFetchTrips => 'Failed to fetch trips';

  @override
  String get failedCancelTrip => 'Failed to cancel trip';

  @override
  String get failedUpdateTrip => 'Failed to update trip status';

  @override
  String get failedFetchAvailableTrips => 'Failed to fetch available trips';

  @override
  String get errorActiveTripExists =>
      'You already have an active trip. Please finish or cancel it first.';

  @override
  String get errorLoadTripDetails => 'Failed to load trip details';

  @override
  String get errorAcceptTrip => 'Failed to accept trip';

  @override
  String get errorRejectTrip => 'Failed to reject trip';

  @override
  String get errorStartTrip => 'Failed to start trip';

  @override
  String get errorCompleteTrip => 'Failed to complete trip';

  @override
  String get errorNotLoggedIn => 'Not logged in';

  @override
  String get call => 'Call';

  @override
  String get track => 'Track';

  @override
  String get fareDetails => 'Fare Details';

  @override
  String get paid => 'Paid';

  @override
  String get unpaid => 'Unpaid';

  @override
  String get timeline => 'Timeline';

  @override
  String get tripRated => 'Trip rated';

  @override
  String get complaintSubject => 'Complaint Subject';

  @override
  String get complaintSubjectHint => 'e.g., Driver was late';

  @override
  String get complaintDetails => 'Complaint Details';

  @override
  String get complaintDetailsHint => 'Explain the issue in detail...';

  @override
  String get bookNewTrip => 'Book a new trip';

  @override
  String get yourTripsWillAppearHere => 'Your trips will appear here';

  @override
  String get newTripLabel => 'New Trip';

  @override
  String get trip => 'Trip';

  @override
  String get statusAccepted => 'Accepted';

  @override
  String get statusSearching => 'Searching';

  @override
  String get errorLoadTrips => 'Failed to load trips';

  @override
  String get errorNotYourTrip => 'You cannot cancel a trip that is not yours';

  @override
  String get errorCancelStatus => 'Trip cannot be cancelled in this status';

  @override
  String get successTripCancelled => 'Trip cancelled successfully';

  @override
  String get successComplaintSent => 'Complaint sent successfully';

  @override
  String get errorSendComplaint => 'Failed to send complaint';

  @override
  String get errorCalculatePrice => 'Failed to calculate price';

  @override
  String get errorWaitBeforeRetry => 'Please wait before trying again';

  @override
  String get errorInvalidCoupon => 'Invalid coupon code';

  @override
  String get errorCouponDepleted => 'This coupon has been depleted';

  @override
  String get errorCouponUsed => 'You have already used this coupon';

  @override
  String get errorApplyCoupon => 'Failed to apply coupon';

  @override
  String get errorLoadCoupons => 'Failed to load coupons';

  @override
  String get errorVerifyCoupon => 'Failed to verify coupon';

  @override
  String get errorNoDriverForTrip => 'No driver for this trip';

  @override
  String get errorTripAlreadyRated => 'This trip has already been rated';

  @override
  String get errorAlreadyRated => 'Already rated';

  @override
  String get errorSubmitRating => 'Failed to submit rating';

  @override
  String get currentLocation => 'Your current location';

  @override
  String get errorGetLocation => 'Failed to get location. Check permissions';

  @override
  String get errorLocationNotFound => 'Location not found';

  @override
  String get errorSearchLocation => 'Failed to search for location';

  @override
  String get errorLoadProfile => 'Failed to load profile';

  @override
  String get errorNoValidDataToUpdate => 'No valid data to update';

  @override
  String get errorUpdateProfile => 'Failed to update profile';

  @override
  String get errorDetermineLocation =>
      'Could not determine location. Ensure location services are enabled.';

  @override
  String get errorFileTooLarge => 'File is too large';

  @override
  String get errorFileEmpty => 'File is empty';

  @override
  String get errorFileUnsupported => 'Unsupported file type';

  @override
  String get pleaseFillAllFields => 'Please fill all fields';

  @override
  String get describeIssueDetail => 'Please describe your issue in detail.';

  @override
  String get titleLabel => 'Title';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get editProfileComingSoon => 'Edit Profile coming soon';

  @override
  String get myWallet => 'My Wallet';

  @override
  String get driverWallet => 'Driver Wallet';

  @override
  String get availableBalanceLabel => 'Available Balance';

  @override
  String get availableToWithdraw => 'Available to Withdraw';

  @override
  String get transactionHistory => 'Transaction History';

  @override
  String get noTransactionsYet => 'No transactions yet';

  @override
  String get transactionsWillAppearHere =>
      'All your transaction details will appear here.';

  @override
  String get earningsWillAppearHere =>
      'All your earning details will appear here.';

  @override
  String get egp => 'EGP';

  @override
  String get totalTopUp => 'Total Top-Up';

  @override
  String get totalSpent => 'Total Spent';

  @override
  String get tripEarning => 'Trip Earning';

  @override
  String get withdrawal => 'Withdrawal';

  @override
  String get withdrawalRefund => 'Withdrawal Refund';

  @override
  String get bonus => 'Bonus';

  @override
  String get penalty => 'Penalty';

  @override
  String get topUp => 'Top-Up';

  @override
  String get refund => 'Refund';

  @override
  String get tripPayment => 'Trip Payment';

  @override
  String get adjustment => 'Adjustment';

  @override
  String get balancePrefix => 'Balance: ';

  @override
  String get anErrorOccurred => 'An error occurred';

  @override
  String get retryButton => 'Retry';

  @override
  String get pendingPrefix => 'Pending: ';

  @override
  String get last30Days => 'Last 30 Days';

  @override
  String get requestWithdrawal => 'Request Withdrawal';

  @override
  String get minWithdrawal50 => 'Minimum withdrawal 50 EGP';

  @override
  String get transactions => 'Transactions';

  @override
  String get withdrawalRequests => 'Withdrawal Requests';

  @override
  String get noWithdrawalRequests => 'No withdrawal requests';

  @override
  String get canRequestWithdrawalWhenReachedMin =>
      'You can request to withdraw your earnings when you reach the minimum.';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusProcessing => 'Processing';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusPending => 'Pending';

  @override
  String get vodafoneCash => 'Vodafone Cash';

  @override
  String get instapay => 'InstaPay';

  @override
  String get orangeMoney => 'Orange Money';

  @override
  String get bankTransfer => 'Bank Transfer';

  @override
  String get amountToWithdraw => 'Amount to withdraw';

  @override
  String get enterAmount => 'Enter amount';

  @override
  String get minAmount50 => 'Minimum amount 50 EGP';

  @override
  String get amountGreaterThanBalance =>
      'Amount is greater than available balance';

  @override
  String get withdrawalMethod => 'Withdrawal Method';

  @override
  String get transferDetails => 'Transfer Details';

  @override
  String get mobileNumber => 'Mobile Number';

  @override
  String get invalidMobileNumber => 'Invalid mobile number';

  @override
  String get bankName => 'Bank Name';

  @override
  String get enterBankName => 'Enter bank name';

  @override
  String get accountNumberOrIban => 'Account Number or IBAN';

  @override
  String get enterAccountNumberOrIban => 'Enter Account Number or IBAN';

  @override
  String get confirmWithdrawalRequest => 'Confirm Withdrawal Request';

  @override
  String get todayAtPrefix => 'Today, ';

  @override
  String get onlineStatus => 'Online';

  @override
  String get offlineStatus => 'Offline';

  @override
  String get activeTripWarning =>
      'You already have an active trip. Would you like to cancel it and start a new one?';

  @override
  String get goBack => 'Go Back';

  @override
  String get cancelTripAndSearch => 'Cancel Trip and Search';

  @override
  String get carType => 'Car';

  @override
  String get truckType => 'Truck';

  @override
  String get motorcycleType => 'Motorcycle';

  @override
  String get rideRequests => 'Ride Requests';

  @override
  String get newRideRequestNotifications => 'New ride request notifications';

  @override
  String get newRideAvailableAlert => '🚖 New ride available!';

  @override
  String get newRideRequest => 'New Ride Request';

  @override
  String get fromLabel => 'From';

  @override
  String get toLabel => 'To';

  @override
  String get rejectBtn => 'Reject';

  @override
  String get acceptBtn => 'Accept';

  @override
  String get defaultUser => 'User';

  @override
  String get defaultDriver => 'Driver';

  @override
  String get newTripTitle => 'New Trip';

  @override
  String get newTripBody => 'You have a new trip request near you';

  @override
  String totalTransactionsLabel(int count) {
    return '$count transactions';
  }

  @override
  String balanceAfterLabel(String amount) {
    return 'Balance: $amount';
  }

  @override
  String failedLoadWallet(String error) {
    return 'Failed to load wallet: $error';
  }

  @override
  String todayAtTime(String time) {
    return 'Today, $time';
  }

  @override
  String withdrawalSuccessMsg(String amount) {
    return 'Withdrawal request sent successfully (Amount: $amount EGP)';
  }

  @override
  String withdrawalViaMethod(String method) {
    return 'Withdrawal via $method';
  }

  @override
  String newRideDetails(String pickup, String dest, String price,
      String currency, String distance) {
    return '$pickup → $dest\n💰 $price $currency  ·  📍 $distance km';
  }

  @override
  String priceWithCurrency(String price, String currency) {
    return '$price $currency';
  }

  @override
  String distanceWithKm(String distance) {
    return '$distance km';
  }

  @override
  String get errorCannotGoOnlineDuringTrip =>
      'Cannot go online while on an active trip';

  @override
  String get errorWithdrawalPending =>
      'You already have a pending withdrawal request';

  @override
  String get errorWalletNotFound => 'Wallet not found';

  @override
  String get errorUnauthorizedOperation => 'Operation not authorized';

  @override
  String errorInsufficientBalance(String available) {
    return 'Insufficient balance. Available: $available EGP';
  }

  @override
  String get errorCancelTripFailed => 'Failed to cancel trip';

  @override
  String errorOccurredWithDetails(String error) {
    return 'An error occurred: $error';
  }

  @override
  String get imageAttachment => '📷 Image';

  @override
  String get read => 'Read';

  @override
  String get sent => 'Sent';

  @override
  String sentAndReadAt(String sentTime, String readTime) {
    return 'Sent: $sentTime\nRead: $readTime';
  }

  @override
  String get typing => 'Typing...';

  @override
  String get offline => 'Offline';

  @override
  String get searchMessages => 'Search conversations...';

  @override
  String get noResults => 'No results';

  @override
  String get tryDifferentKeywords => 'Try searching with different keywords';

  @override
  String get deleteMessage => 'Delete message';

  @override
  String get messageDeleted => 'Message deleted';

  @override
  String get imageLoadError => 'Failed to load image';

  @override
  String get sendImage => 'Send image';
}
