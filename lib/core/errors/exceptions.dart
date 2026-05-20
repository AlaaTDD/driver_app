/// A base class for all application-specific exceptions.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  AppException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

/// Thrown when a network request fails or the user is offline.
class NetworkException extends AppException {
  NetworkException([String message = 'errorNoInternet', String? code])
      : super(message, code: code ?? 'network_error');
}

/// Thrown when user input validation fails.
class ValidationException extends AppException {
  ValidationException(String message, {String? code, dynamic details})
      : super(message, code: code ?? 'validation_error', details: details);
}

/// Thrown when a user tries to access a resource without proper authentication or authorization.
class AuthException extends AppException {
  AuthException(String message, {String? code})
      : super(message, code: code ?? 'auth_error');
}

/// Thrown for general server or database errors.
class ServerException extends AppException {
  ServerException(String message, {String? code, dynamic details})
      : super(message, code: code ?? 'server_error', details: details);
}

/// Thrown when a requested resource (like a file or trip) is not found.
class NotFoundException extends AppException {
  NotFoundException(String message, {String? code})
      : super(message, code: code ?? 'not_found');
}
