import 'package:flutter/material.dart';
import '../localization/generated/app_localizations.dart';

class ErrorMapper {
  /// Translates an error key to a localized string.
  /// If the key is not recognized, it returns the key itself as a fallback.
  ///
  /// FIX P3-05: Replaced 40+ case switch with Map lookup for maintainability.
  static String getErrorMessage(BuildContext context, String errorKey) {
    final l = AppLocalizations.of(context);
    if (l == null) return errorKey;

    final resolver = <String, String Function()>{
      // Auth Errors
      'errorInvalidCredentials': () => l.errorInvalidCredentials,
      'errorEmailRegistered': () => l.errorEmailRegistered,
      'errorConfirmEmail': () => l.errorConfirmEmail,
      'errorPasswordLength': () => l.errorPasswordLength,
      'errorNoInternet': () => l.errorNoInternet,
      'errorRateLimit': () => l.errorRateLimit,
      'errorUserNotFound': () => l.errorUserNotFound,
      'errorUnexpected': () => l.errorUnexpected,
      'errorLoginFailed': () => l.errorLoginFailed,
      'errorCreateAccountFailed': () => l.errorCreateAccountFailed,

      // Trip Errors
      'failedCreateTrip': () => l.failedCreateTrip,
      'failedFetchTrips': () => l.failedFetchTrips,
      'failedCancelTrip': () => l.failedCancelTrip,
      'failedUpdateTrip': () => l.failedUpdateTrip,
      'failedFetchAvailableTrips': () => l.failedFetchAvailableTrips,
      'errorActiveTripExists': () => l.errorActiveTripExists,
      'errorLoadTripDetails': () => l.errorLoadTripDetails,
      'errorAcceptTrip': () => l.errorAcceptTrip,
      'errorRejectTrip': () => l.errorRejectTrip,
      'errorStartTrip': () => l.errorStartTrip,
      'errorCompleteTrip': () => l.errorCompleteTrip,
      'errorNotLoggedIn': () => l.errorNotLoggedIn,
      'errorLoadTrips': () => l.errorLoadTrips,
      'errorNotYourTrip': () => l.errorNotYourTrip,
      'errorCancelStatus': () => l.errorCancelStatus,
      'successTripCancelled': () => l.successTripCancelled,
      'errorCancelTrip': () => l.errorCancelTrip,
      'successComplaintSent': () => l.successComplaintSent,
      'errorSendComplaint': () => l.errorSendComplaint,
      'errorCalculatePrice': () => l.errorCalculatePrice,
      'errorWaitBeforeRetry': () => l.errorWaitBeforeRetry,

      // Coupon Errors
      'errorInvalidCoupon': () => l.errorInvalidCoupon,
      'errorCouponDepleted': () => l.errorCouponDepleted,
      'errorCouponUsed': () => l.errorCouponUsed,
      'errorApplyCoupon': () => l.errorApplyCoupon,
      'errorLoadCoupons': () => l.errorLoadCoupons,
      'errorVerifyCoupon': () => l.errorVerifyCoupon,

      // Other Errors
      'errorNoDriverForTrip': () => l.errorNoDriverForTrip,
      'errorTripAlreadyRated': () => l.errorTripAlreadyRated,
      'errorAlreadyRated': () => l.errorAlreadyRated,
      'errorSubmitRating': () => l.errorSubmitRating,
      'errorGetLocation': () => l.errorGetLocation,
      'errorLocationNotFound': () => l.errorLocationNotFound,
      'errorSearchLocation': () => l.errorSearchLocation,
      'errorLoadProfile': () => l.errorLoadProfile,
      'errorNoValidDataToUpdate': () => l.errorNoValidDataToUpdate,
      'errorUpdateProfile': () => l.errorUpdateProfile,
      'errorDetermineLocation': () => l.errorDetermineLocation,
      'errorFileTooLarge': () => l.errorFileTooLarge,
      'errorFileEmpty': () => l.errorFileEmpty,
      'errorFileUnsupported': () => l.errorFileUnsupported,
    };

    return resolver[errorKey]?.call() ?? errorKey;
  }
}
