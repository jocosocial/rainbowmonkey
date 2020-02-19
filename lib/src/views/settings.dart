import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:battery_optimization/battery_optimization.dart';

import '../logic/background_polling.dart';
import '../logic/cruise.dart';
import '../logic/store.dart';
import '../network/rest.dart';
import '../network/settings.dart';
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

class _SettingsState extends State<Settings> with WidgetsBindingObserver {
  final FocusNode _serverFocus = FocusNode();
  final TextEditingController _server = TextEditingController();

  bool initialized = false;

  int _setBackgroundPollingPeriod;

  bool _isIgnoringBatteryOptimizations;

  @override
  void initState() {
    super.initState();
    _setBackgroundPollingPeriod = backgroundPollingPeriodMinutes;
    BatteryOptimization.isIgnoringBatteryOptimizations().then((bool value) {
      if (mounted) {
        setState(() {
          _isIgnoringBatteryOptimizations = value;
        });
      }
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    BatteryOptimization.isIgnoringBatteryOptimizations().then((bool value) {
      if (mounted) {
        setState(() {
          _isIgnoringBatteryOptimizations = value;
        });
      }
    });
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
    final TextStyle headingStyle = theme.textTheme.bodyText1.copyWith(color: theme.colorScheme.onSurface);
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
          final List<Widget> children = <Widget>[];
          if (Platform.isAndroid) {
            final String s = _setBackgroundPollingPeriod == 1 ? '' : 's';
            String batteryMessage;
            switch (_isIgnoringBatteryOptimizations) {
              case true:
                batteryMessage = 'Notifications should be relatively prompt as '
                                 'you have exempted Rainbow Monkey from normal battery life optimizations. '
                                 'Please remember to re-enable battery life optimizations after the cruise!';
                break;
              case false:
                batteryMessage = 'Notifications will be delayed; '
                                 'Android is saving battery life by reducing how often Rainbow Monkey can run in the background. '
                                 'You can change this in the battery settings. '
                                 '(On a cruise ship we can only do notifications by regularly checking with the on-board server; '
                                 'without Internet access we cannot rely on the usual Android messaging servers.)';
                break;
              default:
                batteryMessage = 'Notifications may be delayed if '
                                 'Android is saving battery life by reducing how often Rainbow Monkey can run in the background. '
                                 '(On a cruise ship we can only do notifications by regularly checking with the on-board server; '
                                 'without Internet access we cannot rely on the usual Android messaging servers.)';
                break;
            }
            children.addAll(<Widget>[
              ListTile(
                title: Text('Notifications', style: headingStyle),
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: pollingDisabled ?
                  const Text('Background polling is disabled.') :
                  Text('Time between checks for new messages when logged in: $_setBackgroundPollingPeriod minute$s'),
              ),
              Padding(
                padding: sliderPadding,
                child: Slider(
                  value: _setBackgroundPollingPeriod.toDouble(),
                  min: 1.0,
                  max: 60.0,
                  divisions: 59,
                  onChanged: pollingDisabled ? null : (double value) {
                    setState(() {
                      _setBackgroundPollingPeriod = value.round();
                    });
                    _updateBackgroundPollingPeriod();
                  },
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                child: Padding(
                  key: ValueKey<bool>(_isIgnoringBatteryOptimizations),
                  padding: const EdgeInsets.fromLTRB(32.0, 16.0, 32.0, 20.0),
                  child: Text(
                    batteryMessage,
                  ),
                ),
              ),
              Center(
                child: FlatButton(
                  child: const Text('OPEN BATTERY SETTINGS'),
                  onPressed: () async => await BatteryOptimization.openBatteryOptimizationSettings(),
                ),
              ),
            ]);
          }
          children.addAll(<Widget>[
            ListTile(
              title: Text('Server', style: headingStyle),
            ),
            RadioListTile<TwitarrConfiguration>(
              title: const Text('Twit-arr server on Nieuw Amsterdam'),
              groupValue: cruise.twitarrConfiguration,
              value: kShipTwitarr,
              onChanged: busy ? null : _apply,
            ),
            RadioListTile<TwitarrConfiguration>(
              title: const Text('Host on Nieuw Amsterdam'),
              groupValue: cruise.twitarrConfiguration,
              value: kShipTwitarrHost,
              onChanged: busy ? null : _apply,
            ),
            RadioListTile<TwitarrConfiguration>(
              title: const Text('Development test server'),
              groupValue: cruise.twitarrConfiguration,
              value: kDevTwitarr,
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
                  errorText: _server.text.isEmpty || _isValid(_server.text) ? null : 'URL is not valid',
                ),
              ),
              groupValue: currentConfiguration,
              value: RestTwitarrConfiguration(baseUrl: _server.text),
              onChanged: _isValid(_server.text) ? _apply : null,
            ),
            const SizedBox(height: 24.0),
          ]);
          assert(() {
            children.addAll(<Widget>[
              const Divider(),
              ListTile(
                title: Text('Network quality test controls', style: headingStyle),
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
                title: Text('Time dilation for animations', style: headingStyle),
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
