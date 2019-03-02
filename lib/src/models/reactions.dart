import 'package:flutter/foundation.dart';

@immutable
class Reactions {
  const Reactions(
    this._details,
  );

  final Map<String, ReactionSummary> _details;

  int get likes => _details['like']?.count ?? 0;

  bool get currentUserLiked => _details['like']?.includesCurrentUser ?? false;

  @override
  String toString() {
    return _details.toString();
  }
}

class ReactionSummary {
  const ReactionSummary({
    this.count,
    this.includesCurrentUser,
  });

  final int count;

  final bool includesCurrentUser;

  @override
  String toString() {
    return '$count${includesCurrentUser ? "*" : ""}';
  }
}
