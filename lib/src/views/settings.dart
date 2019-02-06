import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../logic/cruise.dart';
import '../logic/store.dart';
import '../network/rest.dart';
import '../network/twitarr.dart';
import '../widgets.dart';

class Settings extends StatefulWidget {
  const Settings({
    Key key,
  }) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final FocusNode _serverFocus = FocusNode();
  final TextEditingController _server = TextEditingController();

  bool initialized = false;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: cruise.restoringSettings,
        builder: (BuildContext context, bool busy, Widget child) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return ListView(
                children: <Widget>[
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
                        if (_isValid(_server.text))
                          _apply(RestTwitarrConfiguration(baseUrl: _server.text));
                      },
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.url,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Custom server URL',
                        hintText: 'http://twitarr.example.com:3000/',
                        errorText: _isValid(_server.text) ? null : 'URL is not valid',
                      ),
                    ),
                    groupValue: currentConfiguration,
                    value: RestTwitarrConfiguration(baseUrl: _server.text),
                    onChanged: _isValid(_server.text) ? _apply : null,
                  ),
                  const Divider(),
                  ListTile(
                    title: Text('Network quality test controls', style: theme.textTheme.body2.copyWith(color: theme.primaryColor)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.hourglass_empty),
                    title: Text('Extra latency per request: ${latency.round()}ms'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                ],
              );
            },
          );
        },
      ),
    );
  }
}
