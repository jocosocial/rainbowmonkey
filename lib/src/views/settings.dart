import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../network/rest.dart';
import '../network/twitarr.dart';
import '../widgets.dart';

class Settings extends StatelessWidget {
  const Settings({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: <Widget>[
          RadioListTile<TwitarrConfiguration>(
            title: const Text('prosedev.com test server'),
            groupValue: Cruise.of(context).twitarrConfiguration,
            value: const RestTwitarrConfiguration(baseUrl: 'http://drang.prosedev.com:3000/api/v2/'),
            onChanged: (TwitarrConfiguration configuration) => Cruise.of(context).selectTwitarrConfiguration(configuration),
          ),
          RadioListTile<TwitarrConfiguration>(
            title: const Text('example.com'),
            groupValue: Cruise.of(context).twitarrConfiguration,
            value: const RestTwitarrConfiguration(baseUrl: 'http://example.com/'),
            onChanged: (TwitarrConfiguration configuration) => Cruise.of(context).selectTwitarrConfiguration(configuration),
          ),
        ],
      ),
    );
  }
}
