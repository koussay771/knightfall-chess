/// Platform-specific IP resolver for Web browsers (Chrome, Safari, etc.).
Future<String?> getPlatformLocalIp() async {
  // Browsers cannot query network interfaces directly.
  return 'localhost';
}
