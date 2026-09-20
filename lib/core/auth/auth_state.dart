enum AuthStatus {
  /// Session restore hasn't completed yet — show a splash/spinner, don't
  /// route to either the login screen or the app shell.
  unknown,
  authenticated,
  unauthenticated,
}

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.errorMessage});

  final AuthStatus status;
  final String? errorMessage;
}
