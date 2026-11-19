export 'udp_discovery_io.dart'
    if (dart.library.html) 'udp_discovery_web.dart'
    if (dart.library.js_interop) 'udp_discovery_web.dart';
