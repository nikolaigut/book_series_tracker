import 'package:url_launcher/url_launcher.dart';

class OnleiheService {
  static const String _onleiheBase = 'https://dibizentral.onleihe.com/search';

  /// Opens the Onleihe 3 search page for the given title.
  /// Because Onleihe requires a valid library login, this launches
  /// the search in the system browser / webview where the user can
  /// log in and see availability.
  Future<bool> searchAvailability(String title) async {
    final uri = Uri.parse(_onleiheBase).replace(
      queryParameters: {'query': title},
    );

    const mode = LaunchMode.externalApplication;
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: mode);
    }
    return false;
  }

  Uri searchUri(String title) {
    return Uri.parse(_onleiheBase).replace(
      queryParameters: {'query': title},
    );
  }
}
