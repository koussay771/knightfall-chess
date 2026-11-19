import 'local_ip_resolver_io.dart'
    if (dart.library.html) 'local_ip_resolver_web.dart'
    if (dart.library.js_interop) 'local_ip_resolver_web.dart';

Future<String?> resolvePlatformLocalIp() => getPlatformLocalIp();
