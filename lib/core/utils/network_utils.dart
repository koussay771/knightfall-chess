import 'dart:io';

/// Connection info decoded from a QR code.
class QrConnectionInfo {
  final String ip;
  final int port;

  const QrConnectionInfo({required this.ip, required this.port});

  @override
  String toString() => '$ip:$port';
}

/// Network helper utilities for local IP detection and QR code encoding/decoding.
class NetworkUtils {
  NetworkUtils._();

  /// Retrieves the device's local IPv4 address (e.g. Wi-Fi or Hotspot subnet).
  /// Excludes loopback addresses (127.0.0.1).
  static Future<String?> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // Prefer Wi-Fi / wlan / hotspot interfaces
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('wlan') ||
            name.contains('wi-fi') ||
            name.contains('wifi') ||
            name.contains('ap') ||
            name.contains('hotspot') ||
            name.contains('en') ||
            name.contains('eth')) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              return addr.address;
            }
          }
        }
      }

      // Fallback: Return first available non-loopback IPv4
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (_) {
      // Network interface query failed
    }
    return null;
  }

  /// Encodes host IP and port into a standard QR code payload string: "ip:port".
  static String encodeQrPayload(String ip, int port) {
    return '$ip:$port';
  }

  /// Decodes a QR code payload formatted as "ip:port" into a [QrConnectionInfo].
  /// Returns null if the payload is malformed or invalid.
  static QrConnectionInfo? decodeQrPayload(String payload) {
    try {
      final trimmed = payload.trim();
      final parts = trimmed.split(':');
      if (parts.length != 2) return null;

      final ip = parts[0].trim();
      final port = int.tryParse(parts[1].trim());

      if (ip.isEmpty || port == null || port <= 0 || port > 65535) {
        return null;
      }

      // Validate IP format
      final parsed = InternetAddress.tryParse(ip);
      if (parsed == null || parsed.type != InternetAddressType.IPv4) {
        // Also allow valid hostnames/IPs
        if (ip != 'localhost' && !ip.contains('.')) return null;
      }

      return QrConnectionInfo(ip: ip, port: port);
    } catch (_) {
      return null;
    }
  }
}
