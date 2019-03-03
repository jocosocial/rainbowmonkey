import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/server_status.dart';
import '../widgets.dart';

class DeckPlanView extends StatefulWidget implements View {
  const DeckPlanView({
    Key key,
  }) : super(key: key);

  @override
  bool isEnabled(ServerStatus status) => status.deckPlansEnabled;

  @override
  Widget buildTabIcon(BuildContext context) => const Icon(Icons.directions_boat);

  @override
  Widget buildTabLabel(BuildContext context) => const Text('Deck Plans');

  @override
  Widget buildFab(BuildContext context) {
    return null;
  }

  @override
  _DeckPlanViewState createState() => _DeckPlanViewState();
}

class _DeckPlanViewState extends State<DeckPlanView> with SingleTickerProviderStateMixin {
  static const int kMinDeck = 1;
  static const int kMaxDeck = 10;

  AnimationController _currentLevel;
  List<Widget> _decks, _buttons;

  @override
  void initState() {
    super.initState();
    _currentLevel = AnimationController(
      value: kMinDeck.toDouble(),
      lowerBound: kMinDeck.toDouble(),
      upperBound: kMaxDeck.toDouble(),
      vsync: this,
    );
    _decks = List<Widget>.generate(kMaxDeck - kMinDeck + 1,
      (int index) => Deck(
        level: index + kMinDeck,
        opacity: _DeckAnimation(_currentLevel, (index + kMinDeck).toDouble()),
      ),
      growable: false,
    );
    _buttons = List<Widget>.generate(kMaxDeck - kMinDeck + 1,
      (int index) => Expanded(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: InkResponse(
            onTap: () {
              _goToDeck(index + kMinDeck);
            },
            child: FractionallySizedBox(
              widthFactor: 0.75,
              heightFactor: 0.75,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text('${index + kMinDeck}'),
              ),
            ),
          ),
        ),
      ),
      growable: false,
    );
  }

  @override
  void dispose() {
    _currentLevel.dispose();
    super.dispose();
  }

  void _goToDeck(int target) {
    _currentLevel.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeIn,
    );
  }

  double _scale = 2.0;
  double _dynamicScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: GestureDetector(
            onScaleUpdate: (ScaleUpdateDetails details) {
              setState(() { _dynamicScale = details.scale; });
            },
            onScaleEnd: (ScaleEndDetails details) {
              setState(() { _scale = math.max(1.0, _scale * _dynamicScale); _dynamicScale = 1.0; });
            },
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  child: SafeArea(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: 0.0,
                        maxWidth: constraints.maxWidth,
                        minHeight: constraints.maxHeight,
                        maxHeight: constraints.maxHeight * math.max(1.0, _scale * _dynamicScale),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: _decks,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SafeArea(
          child: CustomPaint(
            painter: Elevator(
              min: kMinDeck.toDouble(),
              max: kMaxDeck.toDouble(),
              level: _currentLevel,
              color: Theme.of(context).accentColor,
            ),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.button,
              child: GestureDetector(
                onVerticalDragStart: (DragStartDetails details) {
                  _currentLevel.stop();
                },
                onVerticalDragUpdate: (DragUpdateDetails details) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  _currentLevel.value -= (details.primaryDelta / box.size.height) * (kMaxDeck - kMinDeck + 1);
                },
                onVerticalDragEnd: (DragEndDetails details) {
                  if (details.primaryVelocity > 0.0) {
                    _goToDeck(_currentLevel.value.floor());
                  } else if (details.primaryVelocity < 0.0) {
                    _goToDeck(_currentLevel.value.ceil());
                  } else {
                    _goToDeck(_currentLevel.value.round());
                  }
                },
                child: Column(
                  verticalDirection: VerticalDirection.up,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _buttons,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class Elevator extends CustomPainter {
  Elevator({
    @required this.min,
    @required this.max,
    @required this.level,
    @required this.color,
  }) : assert(min != null),
       assert(max != null),
       assert(level != null),
       assert(color != null),
       super(repaint: level);

  final double min;
  final double max;
  final ValueListenable<double> level;
  final Color color;

  static const double inset = 0.1;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black
      ..strokeWidth = size.width * inset
      ..style = PaintingStyle.stroke;
    final Rect rect = Rect.fromLTWH(
      size.width * inset,
      size.width * inset + (size.height - size.width) * (1.0 - (level.value - min) / (max - min)),
      size.width * (1 - inset * 2.0),
      size.width * (1 - inset * 2.0),
    );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(Elevator oldDelegate) {
    return level != oldDelegate.level
        || color != color;
  }
}

class Deck extends StatelessWidget {
  const Deck({
    Key key,
    @required this.level,
    @required this.opacity,
  }) : assert(level != null),
       assert(opacity != null),
       super(key: key);

  final int level;

  final Animation<double> opacity;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset('images/deck_$level.png'),
      ),
    );
  }
}

class _DeckAnimation extends Animation<double> with AnimationWithParentMixin<double> {
  _DeckAnimation(this.parent, this.deck);

  @override
  final Animation<double> parent;

  final double deck;

  @override
  double get value {
    if (parent.value == deck)
      return 1.0;
    if (parent.value < deck - 1.0 ||
        parent.value > deck + 1.0)
      return 0.0;
    return 1.0 - (parent.value - deck).abs();
  }
}
