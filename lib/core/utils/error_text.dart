import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns backend/network errors into a short message safe to show a user.
String friendlyError(Object error) {
  if (error is PostgrestException) {
    switch (error.code) {
      case '23505':
        return 'That already exists.';
      case '42501':
        return 'You do not have permission to do that. Sign in again.';
      case 'P0001': // raise exception inside our RPCs
        return error.message;
    }
    return error.message;
  }
  if (error is StorageException) return error.message;
  if (error is AuthException) return error.message;
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup')) {
    return 'No internet connection. Please try again.';
  }
  return text.replaceFirst('Exception: ', '');
}
