import 'package:url_launcher/url_launcher.dart';

class MapLauncherService {
  static Future<bool> openAddress(String address) async {
    final normalized = address.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final encoded = Uri.encodeComponent(normalized);
    final googleNavigationUri = Uri.parse('google.navigation:q=$encoded');
    final googleMapsSearchUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encoded',
    );

    try {
      final openedNavigation = await launchUrl(
        googleNavigationUri,
        mode: LaunchMode.externalApplication,
      );
      if (openedNavigation) {
        return true;
      }
    } catch (_) {
      // segue para o fallback web/app
    }

    return launchUrl(
      googleMapsSearchUri,
      mode: LaunchMode.externalApplication,
    );
  }
}
