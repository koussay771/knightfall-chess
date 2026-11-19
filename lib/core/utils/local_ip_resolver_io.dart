import 'dart:io';

/// Platform-specific IP resolver for native (Android, iOS, Windows, Linux, macOS).
Future<String?> getPlatformLocalIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    if (interfaces.isEmpty) return null;

    // 0. Active Hotspot subnet match (Android hotspot 192.168.43.x, Windows hotspot 192.168.137.x)
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
          if (addr.address.startsWith('192.168.43.') ||
              addr.address.startsWith('192.168.137.')) {
            return addr.address;
          }
        }
      }
    }

    // 1. Hotspot / Tethering interfaces (Android/iOS/PC hotspot by name)
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      if (name.contains('ap') ||
          name.contains('softap') ||
          name.contains('tether') ||
          name.contains('rndis') ||
          name.contains('swlan') ||
          name.contains('hotspot') ||
          name.contains('direct')) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback &&
              addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('169.254.')) {
            return addr.address;
          }
        }
      }
    }

    // 2. Wi-Fi / Wireless interfaces
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      if (name.contains('wlan') ||
          name.contains('wi-fi') ||
          name.contains('wifi') ||
          name.contains('wireless') ||
          name.contains('wl')) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback &&
              addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('169.254.')) {
            return addr.address;
          }
        }
      }
    }

    // 3. Ethernet interfaces
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      if (name.contains('eth') ||
          name.contains('en') ||
          name.contains('ethernet')) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback &&
              addr.type == InternetAddressType.IPv4 &&
              !addr.address.startsWith('169.254.')) {
            return addr.address;
          }
        }
      }
    }

    // 4. Any non-loopback, non-link-local IPv4
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback &&
            addr.type == InternetAddressType.IPv4 &&
            !addr.address.startsWith('169.254.') &&
            !addr.address.startsWith('127.')) {
          return addr.address;
        }
      }
    }

    // 5. Ultimate non-loopback fallback
    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
          return addr.address;
        }
      }
    }
  } catch (_) {
    // Network interface lookup error
  }
  return null;
}
