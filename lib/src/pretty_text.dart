import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import 'models/server_status.dart';
import 'models/string.dart';
import 'models/user.dart';
import 'widgets.dart';

class PrettyText extends StatefulWidget {
  const PrettyText(this.text, {
    Key key,
    this.prefix,
    this.style,
    this.maxLines,
    this.overflow,
  }) : super(key: key);

  final TwitarrString text;

  final String prefix;

  final TextStyle style;

  final int maxLines;

  final TextOverflow overflow;

  @override
  State<PrettyText> createState() => _PrettyTextState();
}

// Special emoji (the last two aren't supported by the server).
const String _emojiNames = 'buffet|die-ship|die|fez|hottub|joco|pirate|ship-front|ship|towel-monkey|tropical-drink|zombie|monkey|rainbow-monkey';

const String _schemePatternFragment = r'(?:(?:[a-zA-Z]+)://)';
const String _portPatternFragment = r'(?::[0-9]+)';
const String _hostPatternFragment = r'(?:(?:\p{Letter}[\p{Letter}\p{Number}]*\.)+\p{Letter}[\p{Letter}\p{Number}]*)';
const String _pathPatternFragment = r'(?:/[^ \t\n]+)';
final RegExp _tokenizerPattern = RegExp(
  '(?::(?<EMOJI>$_emojiNames):)'
  '|'
  '(?:\#(?<HASHTAG>\\p{Letter}{3,100}))'
  '|'
  '(?:@(?<USERNAME>[-a-z&]{3,40}))'
  '|'
  '(?<URL>$_schemePatternFragment?$_hostPatternFragment$_portPatternFragment?$_pathPatternFragment?)',
  unicode: true);
final RegExp _schemePattern = RegExp(_schemePatternFragment);

class _PrettyTextState extends State<PrettyText> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_parts != null)
      _disposeParts();
    _updateSpans();
  }

  @override
  void didUpdateWidget(PrettyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _disposeParts();
      _updateSpans();
    }
  }

  List<_Part> _tokenize(TwitarrString input) {
    final String text = input.encodedValue;
    final List<_Part> result = <_Part>[];
    if (widget.prefix != null)
      result.add(_TextPart(widget.prefix));
    text.splitMapJoin(
      _tokenizerPattern,
      onMatch: (Match rawMatch) {
        final RegExpMatch match = rawMatch as RegExpMatch;
        final String type = match.groupNames.where((String name) => match.namedGroup(name) != null).single;
        final String value = match.namedGroup(type);
        switch (type) {
          case 'EMOJI':
            result.add(_EmojiPart(value));
            break;
          case 'HASHTAG':
            result.add(_HashTagPart(value, setState, context));
            break;
          case 'USERNAME':
            result.add(_UsernamePart(value, setState, context));
            break;
          case 'URL':
            result.add(_LinkPart(value, setState, context));
            break;
        }
        return '';
      },
      onNonMatch: (String nonMatch) {
        if (nonMatch.isNotEmpty)
          result.add(_TextPart('$nonMatch'));
        return '';
      }
    );
    return result;
  }

  List<_Part> _parts;
  Widget _widget;

  void _updateSpans() {
    _parts = _tokenize(widget.text);
    if (!_parts.any((_Part part) => part is! _EmojiPart)) {
      _widget = Wrap(children: <Widget>[
        for (_EmojiPart part in _parts.cast<_EmojiPart>())
          part.buildSpecial(context),
      ]);
    }
  }

  void _disposeParts() {
    for (_Part part in _parts)
      part.dispose();
    _parts = null;
    _widget = null;
  }

  @override
  void dispose() {
    _disposeParts();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_widget != null)
      return _widget;
    return Text.rich(TextSpan(
      children: _parts.map<InlineSpan>((_Part part) => part.build(context)).toList()),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}

abstract class _Part {
  const _Part();

  InlineSpan build(BuildContext context);

  @mustCallSuper
  void dispose() { }
}

class _TextPart extends _Part {
  const _TextPart(this.text);

  final String text;

  @override
  InlineSpan build(BuildContext context) => TextSpan(text: text);
}

class _EmojiPart extends _Part {
  const _EmojiPart(this.emoji);

  final String emoji;

  String get _path => 'images/emoji/$emoji.png';

  @override
  InlineSpan build(BuildContext context) {
    final double height = DefaultTextStyle.of(context).style.fontSize;
    return WidgetSpan(child: Image.asset(_path, height: height));
  }

  Widget buildSpecial(BuildContext context) {
    final double height = DefaultTextStyle.of(context).style.fontSize;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Image.asset(_path, height: height * 2.0),
    );
  }
}

abstract class _TappablePart extends _Part {
  _TappablePart(this.setState, this.context) {
    _recognizer = TapGestureRecognizer()
      ..onTapDown = _handleTapDown
      ..onTapUp = _handleTapUp
      ..onTapCancel = _handleTapUp
      ..onTap = handleTap;
  }

  final StateSetter setState;
  final BuildContext context;

  @protected
  String get text;

  @protected
  TextStyle get style;

  @protected
  void handleTap();

  GestureRecognizer _recognizer;
  Timer _timer;
  bool _down = false;

  void _handleTapDown(TapDownDetails details) {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _down = true;
    });
  }

  void _handleTapUp([TapUpDetails details]) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 100), () {
      setState(() {
        _down = false;
      });
      _timer = null;
    });
  }

  @override
  InlineSpan build(BuildContext context) {
    TextStyle currentStyle = style;
    if (_down) {
      final Color highlightColor = Theme.of(context).colorScheme.secondary;
      currentStyle = currentStyle.copyWith(color: highlightColor);
    }
    return TextSpan(text: text, style: currentStyle, recognizer: _recognizer);
  }

  @override
  void dispose() {
    _recognizer.dispose();
    _timer?.cancel();
    super.dispose();
  }
}

class _LinkPart extends _TappablePart {
  _LinkPart(this.link, StateSetter setState, BuildContext context) : super(setState, context);

  final String link;

  @override
  String get text => link;

  @override
  TextStyle get style => const TextStyle(decoration: TextDecoration.underline);

  @override
  void handleTap() {
    String url;
    if (link.startsWith(_schemePattern)) {
      final int colon = link.indexOf(':');
      url = link.substring(0, colon).toLowerCase() + link.substring(colon);
    } else {
      url = 'http://$link';
    }
    launch(url);
  }
}

class _HashTagPart extends _TappablePart {
  _HashTagPart(this.tag, StateSetter setState, BuildContext context) : super(setState, context);

  final String tag;

  @override
  String get text => '#$tag';

  @override
  TextStyle get style => const TextStyle(fontStyle: FontStyle.italic);

  @override
  void handleTap() {
    search(context, text);
  }
}

class _UsernamePart extends _TappablePart {
  _UsernamePart(this.username, StateSetter setState, BuildContext context) : super(setState, context);

  final String username;

  @override
  String get text => '@$username';

  @override
  TextStyle get style => const TextStyle(fontWeight: FontWeight.bold);

  @override
  void handleTap() {
    if ((Cruise.of(context).serverStatus.currentValue ?? const ServerStatus()).userProfileEnabled) {
      Navigator.pushNamed(context, '/profile', arguments: User(username: username, displayName: '', role: Role.none));
    } else {
      search(context, text);
    }
  }
}
