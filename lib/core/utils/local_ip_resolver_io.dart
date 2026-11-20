import 'dart:io';

/// Platform-specific IP resolver for native (Android, iOS, Windows, Linux, macOS).
/// Resolution priority (highest first):
///   0. Android mobile hotspot subnet (192.168.43.x) or Windows ICS subnet (192.168.137.x)
///   1. Interface name matches hotspot/tethering keywords
///   2. Wi-Fi / wireless interface names
///   3. Ethernet interface names
///   4. Any non-loopback, non-link-local IPv4
Future<String?> getPlatformLocalIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );

    if (interfaces.isEmpty) return null;

    // Collect all valid non-loopback, non-link-local IPv4 addresses per interface
    bool isValidAddr(InternetAddress addr) =>
        !addr.isLoopback &&
        addr.type == InternetAddressType.IPv4 &&
        !addr.address.startsWith('169.254.');

    // 0. Known hotspot subnets — most specific, highest priority
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (isValidAddr(addr) &&
            (addr.address.startsWith('192.168.43.') ||  // Android hotspot
             addr.address.startsWith('192.168.137.') || // Windows ICS / hotspot
             addr.address.startsWith('172.20.10.'))) {  // iPhone hotspot
          return addr.address;
        }
      }
    }

    // 1. Hotspot / tethering interface names
    const hotspotKeywords = [
      'ap', 'softap', 'tether', 'rndis', 'swlan', 'hotspot', 'direct',
    ];
    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      if (hotspotKeywords.any((kw) => name.contains(kw))) {
        for (final addr in iface.addresses) {
          if (isValidAddr(addr)) return addr.address;
        }
      }
    }

    // 2. Wi-Fi / Wireless interface names (Windows: "Wi-Fi", Android: "wlan0")
    const wifiKeywords = [
      'wlan', 'wi-fi', 'wifi', 'wireless', 'wl',
    ];
    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      if (wifiKeywords.any((kw) => name.contains(kw))) {
        for (final addr in iface.addresses) {
          if (isValidAddr(addr)) return addr.address;
        }
      }
    }

    // 3. Ethernet interface names (Windows: "Ethernet", Linux: "eth0", "en0")
    const ethKeywords = ['eth', 'en', 'ethernet', 'local area'];
    for (final iface in interfaces) {
      final name = iface.name.toLowerCase();
      if (ethKeywords.any((kw) => name.contains(kw))) {
        for (final addr in iface.addresses) {
          if (isValidAddr(addr)) return addr.address;
        }
      }
    }

    // 4. Any remaining valid non-loopback IPv4
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (isValidAddr(addr) && !addr.address.startsWith('127.')) {
          return addr.address;
        }
      }
    }

    // 5. Ultimate fallback — any non-loopback IPv4 (even link-local 169.254.x.x)
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
          return addr.address;
        }
      }
    }
  } catch (e) {
    // NetworkInterface.list() may throw on devices with restricted permissions.
    // Caller (NetworkUtils.getLocalIpAddress) will return null and the UI will
    // show a clear "No hotspot IP detected" message.
  }
  return null;
}
