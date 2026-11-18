# Project Blueprint: Cross-Platform Local Hotspot Chess (Flutter)

## 1. Tech Stack & Core Architecture
- **Framework:** Flutter (Latest Stable) targeting Android & iOS.
- **State Management:** Riverpod (`flutter_riverpod`) or Bloc for strict separation between UI, Chess Engine, and Network Layer.
- **Chess Logic Engine:** Pure Dart custom engine (or wrapping `chess` package strictly for move validation, FEN generation, and game-over states — NO legal move hints shown on UI).
- **Local Networking (Zero-Internet):** 
  - `dart:io` `ServerSocket` & `Socket` (TCP) on port `4545` for reliable, ordered game state & move synchronization.
  - `RawDatagramSocket` (UDP) on port `4546` for automatic LAN/Hotspot room discovery (broadcasting room name & host IP every 1.5s).
- **Local Storage:** `hive` or `shared_preferences` + `sqflite` for Match History, Head-to-Head stats, and Profiles.
- **Utilities:** `qr_flutter` & `mobile_scanner` (fallback IP connection via QR code), `audioplayers` (SFX), `flutter/services.dart` (`HapticFeedback`).

---

## 2. Folder Structure
```text
lib/
├── main.dart
├── core/
│   ├── constants/        # Ports, colors, default themes, audio paths
│   ├── models/           # Player, GameMessage (JSON protocol), MatchRecord
│   └── utils/            # Network IP helper, FEN parser, sound manager
├── engine/
│   ├── chess_board_state.dart  # Board matrix, turn, clocks, captured pieces, move history
│   ├── move_validator.dart     # Full rules: Castling, En Passant, Promotion, Check/Mate/Draw
│   └── premove_handler.dart    # Queuing & validating premoves on opponent's turn
├── network/
│   ├── udp_discovery.dart      # Broadcast & listen for active Hotspot games
│   ├── tcp_server.dart         # Host socket manager (handles players + spectators + reconnects)
│   ├── tcp_client.dart         # Client socket manager with auto-reconnect heartbeat
│   └── sync_protocol.dart      # JSON serialization for moves, clocks, takebacks, game states
├── features/
│   ├── lobby/                  # Home screen, Host/Join UI, QR Scanner, Time Control selector
│   ├── game/                   # Interactive 8x8 Board, Clocks, Captured bar, Move list, Takeback modal
│   ├── spectator/              # Read-only live board view for 3rd+ devices on Hotspot
│   ├── history/                # Match history list & Head-to-Head scoreboard
│   ├── modes/                  # King of the Hill (Mini-Tournament) & Bet/Dare mode wrappers
│   └── profile_themes/         # Player name/avatar editor & Board theme selector