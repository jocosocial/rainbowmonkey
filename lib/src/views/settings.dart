import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../logic/background_polling.dart';
import '../logic/cruise.dart';
import '../logic/store.dart';
import '../network/rest.dart';
import '../network/twitarr.dart';
import '../widgets.dart';

class Settings extends StatefulWidget {
  const Settings({
    Key key,
    @required this.store,
  }) : super(key: key);

  final DataStore store;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final FocusNode _serverFocus = FocusNode();
  final TextEditingController _server = TextEditingController();

  bool initialized = false;

  int _setBackgroundPollingPeriod;

  @override
  void initState() {
    super.initState();
    _setBackgroundPollingPeriod = backgroundPollingPeriodMinutes;
  }

  Timer _timer;
  bool _updating = false;

  void _updateBackgroundPollingPeriod() {
    if (_updating)
      return;
    if (_timer != null)
      _timer.cancel();
    final DataStore store = widget.store;
    _timer = Timer(const Duration(seconds: 2), () async {
      if (_updating)
        return;
      _updating = true;
      try {
        await store.saveSetting(Setting.notificationCheckPeriod, _setBackgroundPollingPeriod).asFuture();
        await rescheduleBackground(store);
      } finally {
        _updating = false;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      final TwitarrConfiguration config = Cruise.of(context).twitarrConfiguration;
      if (config is RestTwitarrConfiguration)
        _server.text = config.baseUrl;
    }
  }

  void _apply(TwitarrConfiguration configuration) async {
    Cruise.of(context).selectTwitarrConfiguration(configuration);
    await Cruise.of(context).saveTwitarrConfiguration().asFuture();
  }

  bool _isValid(String url) {
    final Uri parsed = Uri.tryParse(url);
    return parsed != null
        && parsed.isAbsolute
        && !parsed.hasQuery
        && parsed.hasAuthority
        && parsed.host != ''
        && (parsed.scheme == 'http' || parsed.scheme == 'https');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CruiseModel cruise = Cruise.of(context);
    final TwitarrConfiguration currentConfiguration = cruise.twitarrConfiguration;
    final double latency = cruise.debugLatency;
    final double reliability = cruise.debugReliability;
    const EdgeInsetsGeometry sliderPadding = EdgeInsetsDirectional.fromSTEB(64.0, 8.0, 16.0, 8.0);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: cruise.restoringSettings,
        builder: (BuildContext context, bool busy, Widget child) {
          final List<Widget> children = <Widget>[
            ListTile(
              title: Text('Server', style: theme.textTheme.body2.copyWith(color: theme.primaryColor)),
            ),
            RadioListTile<TwitarrConfiguration>(
              title: const Text('Automatically pick server'),
              groupValue: cruise.twitarrConfiguration,
              value: const AutoTwitarrConfiguration(),
              onChanged: busy ? null : _apply,
            ),
            RadioListTile<TwitarrConfiguration>(
              title: TextField(
                controller: _server,
                focusNode: _serverFocus,
                onChanged: (String value) {
                  setState(() {
                    if (_isValid(_server.text))
                      _apply(RestTwitarrConfiguration(baseUrl: _server.text));
                  });
                },
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.url,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Custom server URL',
                  hintText: 'http://twitarr.example.com:3000/',
                  errorText: currentConfiguration is AutoTwitarrConfiguration || _isValid(_server.text) ? null : 'URL is not valid',
                ),
              ),
              groupValue: currentConfiguration,
              value: RestTwitarrConfiguration(baseUrl: _server.text),
              onChanged: _isValid(_server.text) ? _apply : null,
            ),
          ];
          if (Platform.isAndroid) {
            final String s = _setBackgroundPollingPeriod == 1 ? '' : 's';
            children.addAll(<Widget>[
              const SizedBox(height: 24.0),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: Text('Time between checks for new messages when logged in: $_setBackgroundPollingPeriod minute$s'),
              ),
              Padding(
                padding: sliderPadding,
                child: Slider(
                  value: _setBackgroundPollingPeriod.toDouble(),
                  min: 1.0,
                  max: 60.0,
                  divisions: 59,
                  onChanged: (double value) {
                    setState(() {
                      _setBackgroundPollingPeriod = value.round();
                    });
                    _updateBackgroundPollingPeriod();
                  },
                ),
              ),
            ]);
          }
          assert(() {
            children.addAll(<Widget>[
              const Divider(),
              ListTile(
                title: Text('Network quality test controls', style: theme.textTheme.body2.copyWith(color: theme.primaryColor)),
              ),
              ListTile(
                leading: const Icon(Icons.hourglass_empty),
                title: Text('Extra latency per request: ${latency.round()}ms'),
              ),
              Padding(
                padding: sliderPadding,
                child: Slider(
                  value: latency == 0 ? 0 : math.log(latency).clamp(0.0, 10.0).toDouble(),
                  min: 0.0,
                  max: 10.0,
                  onChanged: busy ? null : (double value) { cruise.debugLatency = value == 0 ? 0 : math.exp(value); },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.network_wifi),
                title: Text('Probability of fake failure: ${((1.0 - reliability) * 100).round()}%'),
              ),
              Padding(
                padding: sliderPadding,
                child: Slider(
                  value: 1.0 - reliability.clamp(0.0, 1.0).toDouble(),
                  min: 0.0,
                  max: 1.0,
                  onChanged: busy ? null : (double value) { cruise.debugReliability = 1.0 - value; },
                ),
              ),
              const Divider(),
              ListTile(
                title: Text('Time dilation for animations', style: theme.textTheme.body2.copyWith(color: theme.primaryColor)),
              ),
              ListTile(
                leading: const Icon(Icons.av_timer),
                title: Text('Factor: ${timeDilation.toStringAsFixed(1)}x'),
              ),
              Padding(
                padding: sliderPadding,
                child: Slider(
                  value: timeDilation.clamp(1.0, 100.0).toDouble(),
                  min: 1.0,
                  max: 100.0,
                  onChanged: busy ? null : (double value) {
                    setState(() {
                      timeDilation = value;
                    });
                    cruise.store.saveSetting(Setting.debugTimeDilation, timeDilation);
                  },
                ),
              ),
              const SizedBox(height: 24.0),
            ]);
            return true;
          }());
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return ListView(
                children: children,
              );
            },
          );
        },
      ),
    );
  }
}
