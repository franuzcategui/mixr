class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiUnauthorizedException extends ApiException {
  ApiUnauthorizedException(super.message) : super(statusCode: 401);
}

class ApiServerException extends ApiException {
  ApiServerException(super.message, {super.statusCode});
}
