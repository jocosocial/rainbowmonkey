import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../network/rest.dart';
import '../network/twitarr.dart';
import '../widgets.dart';

class Settings extends StatelessWidget {
  const Settings({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double latency = Cruise.of(context).debugLatency;
    final double reliability = Cruise.of(context).debugReliability;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return ListView(
            children: <Widget>[
              ListTile(
                title: Text('Server', style: theme.textTheme.body2.copyWith(color: theme.primaryColor)),
              ),
              RadioListTile<TwitarrConfiguration>(
                title: const Text('gbasden\'s server'),
                groupValue: Cruise.of(context).twitarrConfiguration,
                value: const RestTwitarrConfiguration(baseUrl: 'http://69.62.137.54:42111/'),
                onChanged: (TwitarrConfiguration configuration) => Cruise.of(context).selectTwitarrConfiguration(configuration),
              ),
              RadioListTile<TwitarrConfiguration>(
                title: const Text('hendusoone\'s server'),
                groupValue: Cruise.of(context).twitarrConfiguration,
                value: const RestTwitarrConfiguration(baseUrl: 'http://twitarrdev.wookieefive.net:3000/'),
                onChanged: (TwitarrConfiguration configuration) => Cruise.of(context).selectTwitarrConfiguration(configuration),
              ),
              RadioListTile<TwitarrConfiguration>(
                title: const Text('hendusoone\'s development machine'),
                groupValue: Cruise.of(context).twitarrConfiguration,
                value: const RestTwitarrConfiguration(baseUrl: 'http://108.49.102.77:3000/'),
                onChanged: (TwitarrConfiguration configuration) => Cruise.of(context).selectTwitarrConfiguration(configuration),
              ),
              const Divider(),
              ListTile(
                title: Text('Network quality', style: theme.textTheme.body2.copyWith(color: theme.primaryColor)),
              ),
              ListTile(
                leading: const Icon(Icons.hourglass_empty),
                title: Text('Latency: ${latency.round()}ms'),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Slider(
                  value: latency == 0 ? 0 : math.log(latency).clamp(0.0, 10.0).toDouble(),
                  min: 0.0,
                  max: 10.0,
                  onChanged: (double value) { Cruise.of(context).debugLatency = value == 0 ? 0 : math.exp(value); },
                ),
              ),
              const Divider(),
              ListTile(
                title: Text('Network reliability', style: theme.textTheme.body2.copyWith(color: theme.primaryColor)),
              ),
              ListTile(
                leading: const Icon(Icons.hourglass_empty),
                title: Text('Probability of failure: ${((1.0 - reliability) * 100).round()}%'),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Slider(
                  value: 1.0 - reliability.clamp(0.0, 1.0).toDouble(),
                  min: 0.0,
                  max: 1.0,
                  onChanged: (double value) { Cruise.of(context).debugReliability = 1.0 - value; },
                ),
              ),
              const Divider(),
              ListTile(
                title: Text('Time dilation', style: theme.textTheme.body2.copyWith(color: theme.primaryColor)),
              ),
              ListTile(
                leading: const Icon(Icons.av_timer),
                title: Text('Factor: ${timeDilation.toStringAsFixed(1)}x'),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Slider(
                  value: timeDilation.clamp(1.0, 100.0).toDouble(),
                  min: 1.0,
                  max: 100.0,
                  onChanged: (double value) { setState(() { timeDilation = value; }); },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
