import 'package:flutter/material.dart';
import '../localization/generated/app_localizations.dart';

class ErrorMapper {
  
  
  
  
  static String getErrorMessage(BuildContext context, String errorKey) {
    final l = AppLocalizations.of(context);
    if (l == null) return errorKey;

    final resolver = <String, String Function()>{
      
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

      
      'errorInvalidCoupon': () => l.errorInvalidCoupon,
      'errorCouponDepleted': () => l.errorCouponDepleted,
      'errorCouponUsed': () => l.errorCouponUsed,
      'errorApplyCoupon': () => l.errorApplyCoupon,
      'errorLoadCoupons': () => l.errorLoadCoupons,
      'errorVerifyCoupon': () => l.errorVerifyCoupon,

      
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
