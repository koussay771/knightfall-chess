import 'package:chess/chess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'move_validator.dart';

/// State representation of a queued premove.
class PremoveState {
  final String? from;
  final String? to;
  final String? promotion;

  const PremoveState({
    this.from,
    this.to,
    this.promotion,
  });

  bool get hasPremove => from != null && to != null;

  PremoveState copyWith({
    Object? from = _sentinel,
    Object? to = _sentinel,
    Object? promotion = _sentinel,
  }) {
    return PremoveState(
      from: identical(from, _sentinel) ? this.from : from as String?,
      to: identical(to, _sentinel) ? this.to : to as String?,
      promotion: identical(promotion, _sentinel)
          ? this.promotion
          : promotion as String?,
    );
  }
}

const Object _sentinel = Object();

/// Notifier handling the queuing, clearing, and execution of premoves.
class PremoveNotifier extends StateNotifier<PremoveState> {
  PremoveNotifier() : super(const PremoveState());

  /// Sets or updates the queued premove.
  void setPremove(String from, String to, {String? promotion}) {
    state = PremoveState(
      from: from,
      to: to,
      promotion: promotion,
    );
  }

  /// Cancels / clears the currently queued premove.
  void clearPremove() {
    state = const PremoveState();
  }

  /// Attempts to execute the stored premove against the updated [chess] board state.
  /// If the move is legal, clears the premove and returns a map with:
  /// `{'from': from, 'to': to, if (promotion != null) 'promotion': promotion}`.
  /// If illegal or no premove is queued, clears it silently and returns `null`.
  Map<String, String>? tryExecute(Chess chess) {
    if (!state.hasPremove) {
      return null;
    }

    final from = state.from!;
    final to = state.to!;
    final promotion = state.promotion;

    // Check legality in current board state
    if (MoveValidator.isLegal(chess, from, to, promotion: promotion)) {
      clearPremove();
      final result = <String, String>{
        'from': from,
        'to': to,
      };
      if (promotion != null) {
        result['promotion'] = promotion;
      }
      return result;
    } else {
      // Illegal now - silently discard
      clearPremove();
      return null;
    }
  }
}

final premoveProvider =
    StateNotifierProvider<PremoveNotifier, PremoveState>((ref) {
  return PremoveNotifier();
});
