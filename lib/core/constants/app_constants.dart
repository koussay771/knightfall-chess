class AppConstants {
  static const int defaultPort = 8080;
  static const int tcpPort = 8080;
  static const int udpPort = 4546;
  static const String broadcastAddress = '255.255.255.255';
  static const Duration pingInterval = Duration(seconds: 2);
  static const Duration reconnectInterval = Duration(seconds: 1);
  static const Duration udpBroadcastInterval = Duration(milliseconds: 1500);
  static const List<int> timeControls = [180, 300, 600, 0];
  static const List<String> timeControlLabels = ['3 min', '5 min', '10 min', '∞'];
  static const String modeStandard = 'standard';
  static const String modeKoth = 'koth';
  static const String modeDare = 'dare';
}
