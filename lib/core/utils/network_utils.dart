import 'local_ip_resolver.dart';

/// Connection info decoded from a QR code, URL, or manual IP entry.
class QrConnectionInfo {
  final String ip;
  final int port;

  const QrConnectionInfo({required this.ip, required this.port});

  @override
  String toString() => '$ip:$port';
}

/// Network helper utilities for dynamic local IP detection and cross-platform
/// QR / Direct-Connect address encoding & parsing.
class NetworkUtils {
  NetworkUtils._();

  /// Retrieves the device's local non-loopback IPv4 address dynamically.
  /// Prioritizes mobile hotspot/tether interfaces and Wi-Fi networks.
  static Future<String?> getLocalIpAddress() async {
    return await resolvePlatformLocalIp();
  }

  /// Encodes host IP and port into standard QR code payload string: "ip:port".
  static String encodeQrPayload(String ip, int port) {
    return '$ip:$port';
  }

  /// Encodes host IP and port into a clickable browser URL: "http://ip:port".
  static String encodeQrUrl(String ip, int port) {
    return 'http://$ip:$port';
  }

  /// Decodes and normalizes a QR code payload, browser URL, or user input string
  /// into a valid [QrConnectionInfo].
  ///
  /// Supports:
  /// - `192.168.x.x:8080`
  /// - `192.168.x.x` (defaults to [defaultPort], e.g. 8080)
  /// - `http://192.168.x.x:8080/`
  /// - `ws://192.168.x.x:8080/ws`
  /// - `localhost` / `localhost:8080`
  ///
  /// Returns `null` if the input is malformed, not a valid IP/domain, or port is out of range.
  static QrConnectionInfo? decodeQrPayload(String payload, {int defaultPort = 8080}) {
    return parseAddress(payload, defaultPort: defaultPort);
  }

  /// Parses user direct input or QR payload with default port fallback.
  static QrConnectionInfo? parseAddress(String input, {int defaultPort = 8080}) {
    var text = input.trim();
    if (text.isEmpty) return null;

    // Strip wrapping quotes or brackets
    if (text.startsWith('"') && text.endsWith('"')) {
      text = text.substring(1, text.length - 1).trim();
    }
    if (text.startsWith("'") && text.endsWith("'")) {
      text = text.substring(1, text.length - 1).trim();
    }

    // Strip URI schemes if present (http://, https://, ws://, wss://)
    final lower = text.toLowerCase();
    if (lower.startsWith('http://')) {
      text = text.substring(7);
    } else if (lower.startsWith('https://')) {
      text = text.substring(8);
    } else if (lower.startsWith('ws://')) {
      text = text.substring(5);
    } else if (lower.startsWith('wss://')) {
      text = text.substring(6);
    }

    // Strip any URL path query fragments (e.g. 192.168.1.1:8080/ws -> 192.168.1.1:8080)
    final slashIndex = text.indexOf('/');
    if (slashIndex != -1) {
      text = text.substring(0, slashIndex);
    }

    String host;
    int port = defaultPort;

    if (text.contains(':')) {
      final parts = text.split(':');
      if (parts.length != 2) return null;
      host = parts[0].trim();
      final parsedPort = int.tryParse(parts[1].trim());
      if (parsedPort == null || parsedPort <= 0 || parsedPort > 65535) {
        return null;
      }
      port = parsedPort;
    } else {
      host = text.trim();
    }

    if (host.isEmpty) return null;

    // Validate host
    if (host.toLowerCase() == 'localhost') {
      return QrConnectionInfo(ip: 'localhost', port: port);
    }

    // Check standard IPv4 format: 4 octets between 0 and 255
    final ipv4Regex = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
    final match = ipv4Regex.firstMatch(host);
    if (match != null) {
      for (int i = 1; i <= 4; i++) {
        final octet = int.tryParse(match.group(i)!);
        if (octet == null || octet < 0 || octet > 255) return null;
      }
      return QrConnectionInfo(ip: host, port: port);
    }

    // Allow valid local/standard hostnames containing dots and valid chars
    final hostnameRegex = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+$');
    if (hostnameRegex.hasMatch(host)) {
      return QrConnectionInfo(ip: host, port: port);
    }

    return null;
  }
}
