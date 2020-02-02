import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/calendar.dart';
import '../models/errors.dart';
import '../network/twitarr.dart';
import '../progress.dart';
import '../widgets.dart';

class CheckClockDialog extends StatefulWidget {
  const CheckClockDialog({
    Key key,
  }) : super(key: key);

  @override
  _CheckClockDialogState createState() => _CheckClockDialogState();
}

class _CheckClockDialogState extends State<CheckClockDialog> {
  Progress<ServerTime> _progress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_progress == null)
      _refresh();
  }

  void _refresh() {
    _progress = Cruise.of(context).getServerTime();
  }

  static final Key _progressKey = UniqueKey();
  static final Key _errorKey = UniqueKey();
  static final Key _doneKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final Widget idleStatus = AlertDialog(
      key: _progressKey,
      title: const Text('Contacting server...'),
      content: const Center(
        heightFactor: 1.5,
        child: CircularProgressIndicator(),
      ),
      actions: <Widget>[
        FlatButton(
          onPressed: () { Navigator.of(context).pop(); },
          child: const Text('CANCEL'),
        ),
      ],
    );
    return ProgressBuilder<ServerTime>(
      progress: _progress,
      idleChild: idleStatus,
      startingChild: idleStatus,
      activeBuilder: (BuildContext context, double progress, double target) {
        return AlertDialog(
          key: _progressKey,
          title: const Text('Contacting server...'),
          content: Center(
            heightFactor: 1.5,
            child: CircularProgressIndicator(
              value: progress / target,
            ),
          ),
          actions: <Widget>[
            FlatButton(
              onPressed: () { Navigator.of(context).pop(); },
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
      failedBuilder: (BuildContext context, Exception error, StackTrace stackTrace) {
        String message;
        if (error is UserFriendlyError) {
          message = '$error';
        } else if (error != null && error.toString().isNotEmpty) {
          message = 'An unexpected error occurred:\n$error';
        } else {
          message = 'Could not contact server.';
        }
        return AlertDialog(
          key: _errorKey,
          title: const Text('Error'),
          content: SingleChildScrollView(
            child: Text(message),
          ),
          actions: <Widget>[
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
      builder: (BuildContext context, ServerTime serverTime) {
        debugPaintSizeEnabled = false;
        if (serverTime.serverTimeZoneOffset != serverTime.clientTimeZoneOffset) {
          return AlertDialog(
            key: _doneKey,
            title: const Text('Time zone and clock status'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  const Text('Your time zone does not match the time zone set on the server.'),
                  const SizedBox(height: 12.0),
                  Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    columnWidths: const <int, TableColumnWidth>{
                      1: FixedColumnWidth(12.0),
                    },
                    children: <TableRow>[
                      TableRow(children: <Widget>[
                        const Text('Twitarr server:', textAlign: TextAlign.right),
                        const SizedBox(),
                        TimeZone(serverTime.serverTimeZoneOffset),
                      ]),
                      TableRow(children: <Widget>[
                        const Text('This device:', textAlign: TextAlign.right),
                        const SizedBox(),
                        TimeZone(serverTime.clientTimeZoneOffset),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  const Text('Adjust your time zone in your system settings and retest.'),
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                onPressed: () { setState(_refresh); },
                child: const Text('RETEST'),
              ),
              FlatButton(
                onPressed: () { Navigator.of(context).pop(); },
                child: const Text('CLOSE'),
              ),
            ],
          );
        }
        if (serverTime.skew.abs() > const Duration(hours: 12)) {
          return AlertDialog(
            key: _doneKey,
            title: const Text('Time zone and clock status'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  const Text('Your clock does not match the clock on the server.'),
                  const SizedBox(height: 12.0),
                  Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    columnWidths: const <int, TableColumnWidth>{
                      0: IntrinsicColumnWidth(flex: 1.0),
                      1: FixedColumnWidth(12.0),
                      2: FlexColumnWidth(1.5),
                    },
                    children: <TableRow>[
                      TableRow(children: <Widget>[
                        const Text('Twitarr server:', textAlign: TextAlign.right),
                        const SizedBox(),
                        DateStamp(serverTime.now.toLocal()),
                      ]),
                      TableRow(children: <Widget>[
                        const Text('This device:', textAlign: TextAlign.right),
                        const SizedBox(),
                        DateStamp(serverTime.clientNow.toLocal()),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  const Text('Adjust your clock in your system settings (don\'t forget to check the date as well) and retest.'),
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                onPressed: () { setState(_refresh); },
                child: const Text('RETEST'),
              ),
              FlatButton(
                onPressed: () { Navigator.of(context).pop(); },
                child: const Text('CLOSE'),
              ),
            ],
          );
        }
        if (serverTime.skew.abs() > const Duration(minutes: 5)) {
          return AlertDialog(
            key: _doneKey,
            title: const Text('Time zone and clock status'),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  const Text('Your clock does not match the clock on the server.'),
                  const SizedBox(height: 12.0),
                  Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    columnWidths: const <int, TableColumnWidth>{
                      0: FlexColumnWidth(2.0),
                      1: FixedColumnWidth(12.0),
                      2: IntrinsicColumnWidth(),
                    },
                    children: <TableRow>[
                      TableRow(children: <Widget>[
                        const Text('Twitarr server:', textAlign: TextAlign.right),
                        const SizedBox(),
                        Clock(serverTime.now.toLocal()),
                        const SizedBox(),
                      ]),
                      TableRow(children: <Widget>[
                        const Text('This device:', textAlign: TextAlign.right),
                        const SizedBox(),
                        Clock(serverTime.clientNow.toLocal()),
                        const SizedBox(),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  const Text('Adjust your clock in your system settings and retest.'),
                ],
              ),
            ),
            actions: <Widget>[
              FlatButton(
                onPressed: () { setState(_refresh); },
                child: const Text('RETEST'),
              ),
              FlatButton(
                onPressed: () { Navigator.of(context).pop(); },
                child: const Text('CLOSE'),
              ),
            ],
          );
        }
        return AlertDialog(
          title: const Text('Time zone and clock status'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Your clock and time zone settings match what we have on the Twitarr server.'),
                const SizedBox(height: 12.0),
                Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  columnWidths: const <int, TableColumnWidth>{
                    0: FlexColumnWidth(2.0),
                    1: FixedColumnWidth(12.0),
                    2: IntrinsicColumnWidth(),
                  },
                  children: <TableRow>[
                    TableRow(children: <Widget>[
                      const Text('Time zone:', textAlign: TextAlign.right),
                      const SizedBox(),
                      TimeZone(serverTime.serverTimeZoneOffset),
                      const SizedBox(),
                    ]),
                    TableRow(children: <Widget>[
                      const Text('Twitarr server:', textAlign: TextAlign.right),
                      const SizedBox(),
                      Clock(serverTime.now.toLocal()),
                      const SizedBox(),
                    ]),
                    TableRow(children: <Widget>[
                      const Text('This device:', textAlign: TextAlign.right),
                      const SizedBox(),
                      Clock(serverTime.clientNow.toLocal()),
                      const SizedBox(),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              onPressed: () { Navigator.of(context).pop(); },
              child: const Text('CLOSE'),
            ),
          ],
        );
      }
    );
  }
}

class TimeZone extends StatelessWidget {
  const TimeZone(this.timeZone);

  final Duration timeZone;

  @override
  Widget build(BuildContext context) {
    final Duration absTimeZone = timeZone.abs();
    final int h = absTimeZone.inHours;
    final int m = (absTimeZone.inMinutes - (h * 60)).abs();
    final String s = timeZone.isNegative ? '\u2212' : '+';
    return Text(
      '$s${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
      style: Theme.of(context).textTheme.headline5,
    );
  }
}

class Clock extends StatelessWidget {
  const Clock(this.time);

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    return Text(
      Calendar.getHours(time, use24Hour: MediaQuery.of(context).alwaysUse24HourFormat),
      style: Theme.of(context).textTheme.headline5,
      textAlign: TextAlign.end,
    );
  }
}

class DateStamp extends StatelessWidget {
  const DateStamp(this.time);

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${Calendar.getHours(time, use24Hour: MediaQuery.of(context).alwaysUse24HourFormat)}',
    );
  }
}
