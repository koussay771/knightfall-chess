import 'package:flutter_test/flutter_test.dart';
import 'package:chess_hotspot/core/utils/network_utils.dart';
import 'package:chess_hotspot/network/sync_protocol.dart';
import 'package:chess_hotspot/network/tcp_client.dart';
import 'package:chess_hotspot/network/tcp_server.dart';

void main() {
  group('Step 2: SyncProtocol & NetworkUtils Tests', () {
    test('QR Code payload encoding and decoding', () {
      final payload = NetworkUtils.encodeQrPayload('192.168.43.1', 4545);
      expect(payload, '192.168.43.1:4545');

      final decoded = NetworkUtils.decodeQrPayload(payload);
      expect(decoded, isNotNull);
      expect(decoded!.ip, '192.168.43.1');
      expect(decoded.port, 4545);

      // Malformed payloads
      expect(NetworkUtils.decodeQrPayload(''), isNull);
      expect(NetworkUtils.decodeQrPayload('invalid_string'), isNull);
      expect(NetworkUtils.decodeQrPayload('192.168.1.1:not_a_port'), isNull);
      expect(NetworkUtils.decodeQrPayload('192.168.1.1:999999'), isNull);

      // Flexible IP & URL parsing (with & without explicit port)
      final withoutPort = NetworkUtils.decodeQrPayload('192.168.1.50');
      expect(withoutPort, isNotNull);
      expect(withoutPort!.ip, '192.168.1.50');
      expect(withoutPort.port, 8080);

      final httpUrl = NetworkUtils.decodeQrPayload('http://192.168.1.50:8080/');
      expect(httpUrl, isNotNull);
      expect(httpUrl!.ip, '192.168.1.50');
      expect(httpUrl.port, 8080);

      final wsUrl = NetworkUtils.decodeQrPayload('ws://192.168.1.50:8080/ws');
      expect(wsUrl, isNotNull);
      expect(wsUrl!.ip, '192.168.1.50');
      expect(wsUrl.port, 8080);

      final localhostNoPort = NetworkUtils.decodeQrPayload('localhost');
      expect(localhostNoPort, isNotNull);
      expect(localhostNoPort!.ip, 'localhost');
      expect(localhostNoPort.port, 8080);
    });

    test('SyncProtocol generates valid newline-delimited JSON for all packet types', () {
      // HANDSHAKE
      final hs = SyncProtocol.handshake(
        playerId: 'uuid-1',
        name: 'Kusai',
        role: 'player',
      );
      expect(hs.endsWith('\n'), true);
      final hsMap = SyncProtocol.decode(hs);
      expect(hsMap['type'], 'handshake');
      expect(hsMap['playerId'], 'uuid-1');
      expect(hsMap['name'], 'Kusai');

      // GAME_START
      final start = SyncProtocol.gameStart(
        whiteId: 'uuid-1',
        blackId: 'uuid-2',
        timeControl: 600,
        increment: 0,
        mode: 'standard',
        dareText: 'Coffee on loser',
      );
      expect(start.endsWith('\n'), true);
      final startMap = SyncProtocol.decode(start);
      expect(startMap['type'], 'start');
      expect(startMap['whiteId'], 'uuid-1');
      expect(startMap['timeControl'], 600);
      expect(startMap['dareText'], 'Coffee on loser');

      // MOVE
      final move = SyncProtocol.move(
        from: 'e2',
        to: 'e4',
        promotion: null,
        fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
        whiteTimeMs: 598000,
        blackTimeMs: 600000,
      );
      expect(move.endsWith('\n'), true);
      final moveMap = SyncProtocol.decode(move);
      expect(moveMap['type'], 'move');
      expect(moveMap['from'], 'e2');
      expect(moveMap['to'], 'e4');
      expect(moveMap['whiteTimeMs'], 598000);

      // TAKEBACK_REQ
      final tbReq = SyncProtocol.takebackReq(requesterId: 'uuid-2');
      final tbReqMap = SyncProtocol.decode(tbReq);
      expect(tbReqMap['type'], 'takeback_req');
      expect(tbReqMap['requesterId'], 'uuid-2');

      // TAKEBACK_RES
      final tbRes = SyncProtocol.takebackRes(
        accepted: true,
        revertedFen: 'initial_fen',
      );
      final tbResMap = SyncProtocol.decode(tbRes);
      expect(tbResMap['type'], 'takeback_res');
      expect(tbResMap['accepted'], true);
      expect(tbResMap['revertedFen'], 'initial_fen');

      // GAME_OVER
      final go = SyncProtocol.gameOver(reason: 'checkmate', winnerId: 'uuid-1');
      final goMap = SyncProtocol.decode(go);
      expect(goMap['type'], 'game_over');
      expect(goMap['reason'], 'checkmate');
      expect(goMap['winnerId'], 'uuid-1');

      // SYNC_STATE
      final sync = SyncProtocol.syncState(
        fen: 'fen_state',
        moveHistory: ['e4', 'e5'],
        whiteTimeMs: 590000,
        blackTimeMs: 585000,
      );
      final syncMap = SyncProtocol.decode(sync);
      expect(syncMap['type'], 'sync');
      expect(syncMap['moveHistory'], ['e4', 'e5']);

      // PING & PONG
      expect(SyncProtocol.decode(SyncProtocol.ping())['type'], 'ping');
      expect(SyncProtocol.decode(SyncProtocol.pong())['type'], 'pong');
    });

    test('SyncProtocol normalizes type strings robustly', () {
      expect(SyncProtocol.normalizeType('HANDSHAKE'), 'handshake');
      expect(SyncProtocol.normalizeType('GAME_START'), 'start');
      expect(SyncProtocol.normalizeType('start'), 'start');
      expect(SyncProtocol.normalizeType('takeback_req'), 'takeback_req');
      expect(SyncProtocol.normalizeType('takebackReq'), 'takeback_req');
      expect(SyncProtocol.normalizeType('game_over'), 'game_over');
      expect(SyncProtocol.normalizeType('gameOver'), 'game_over');
      expect(SyncProtocol.normalizeType('SYNC_STATE'), 'sync');
      expect(SyncProtocol.normalizeType('sync'), 'sync');
    });
  });

  group('Step 2: TCP Client / Server Integration Tests', () {
    late TcpServer server;
    late TcpClient client1;
    late TcpClient client2;
    late TcpClient spectator;

    setUp(() {
      server = TcpServer();
      client1 = TcpClient();
      client2 = TcpClient();
      spectator = TcpClient();
    });

    tearDown(() async {
      await client1.disconnect();
      await client2.disconnect();
      await spectator.disconnect();
      await server.stop();
    });

    test('Client connects to Server, sends Handshake, exchanges Moves and Ping/Pong', () async {
      // 1. Start Server
      await server.start();
      expect(server.state.isRunning, true);

      // Track received messages on server
      final serverReceived = <Map<String, dynamic>>[];
      server.onMessageReceived = (pid, msg) {
        serverReceived.add(msg);
      };

      // 2. Client 1 connects (Player 1)
      final clientReceived = <Map<String, dynamic>>[];
      client1.onMessageReceived = (msg) {
        clientReceived.add(msg);
      };

      await client1.connect(
        '127.0.0.1',
        server.state.port,
        playerId: 'p1-uuid',
        name: 'Player 1',
        role: 'player',
      );

      // Allow TCP handshake to complete
      await Future.delayed(const Duration(milliseconds: 200));

      expect(client1.state.isConnected, true);
      expect(server.state.clients.length, 1);
      expect(server.state.clients.first.role, ClientRole.player);
      expect(server.state.clients.first.name, 'Player 1');

      // 3. Client sends a MOVE packet
      final movePacket = SyncProtocol.move(
        from: 'e2',
        to: 'e4',
        fen: 'fen_after_e4',
        whiteTimeMs: 598000,
        blackTimeMs: 600000,
      );
      client1.send(movePacket);

      await Future.delayed(const Duration(milliseconds: 200));

      expect(serverReceived.length, 1);
      expect(serverReceived.first['from'], 'e2');
      expect(serverReceived.first['to'], 'e4');

      // 4. Server broadcasts MOVE packet back to clients
      server.broadcast(movePacket);
      await Future.delayed(const Duration(milliseconds: 200));

      expect(clientReceived.length, 1);
      expect(clientReceived.first['type'], 'move');

      // 5. Connect Client 2 (Player 2)
      await client2.connect(
        '127.0.0.1',
        server.state.port,
        playerId: 'p2-uuid',
        name: 'Player 2',
        role: 'player',
      );
      await Future.delayed(const Duration(milliseconds: 200));

      expect(server.state.players.length, 2);

      // 6. Connect Client 3 (Spectator) - 3rd connection assigned spectator role
      server.buildSyncState = () => SyncProtocol.syncState(
            fen: 'current_board_fen',
            moveHistory: ['e4', 'e5'],
            whiteTimeMs: 580000,
            blackTimeMs: 590000,
          );

      final spectatorReceived = <Map<String, dynamic>>[];
      spectator.onMessageReceived = (msg) {
        spectatorReceived.add(msg);
      };

      await spectator.connect(
        '127.0.0.1',
        server.state.port,
        playerId: 'spec-uuid',
        name: 'Spectator 1',
        role: 'spectator',
      );
      await Future.delayed(const Duration(milliseconds: 200));

      expect(server.state.spectators.length, 1);
      // Spectator receives full SYNC_STATE upon connection
      expect(spectatorReceived.any((m) => m['type'] == 'sync'), true);
    });

    test('Client Ping-Pong keepalive response works', () async {
      await server.start();

      await client1.connect(
        '127.0.0.1',
        server.state.port,
        playerId: 'ping-uuid',
        name: 'Ping Tester',
        role: 'player',
      );
      await Future.delayed(const Duration(milliseconds: 200));

      // Server sends ping to client
      server.sendTo('ping-uuid', SyncProtocol.ping());

      // Client should automatically answer with pong
      await Future.delayed(const Duration(milliseconds: 200));
      expect(client1.state.isConnected, true);
    });
  });
}
