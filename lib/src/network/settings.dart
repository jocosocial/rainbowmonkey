import 'rest.dart';
import 'twitarr.dart';

// for 2020 cruise
const String _kShipTwitarrUrl = 'http://10.114.238.135/';
const TwitarrConfiguration kShipTwitarr = RestTwitarrConfiguration(baseUrl: _kShipTwitarrUrl, builtin: true);
const String _kShipTwitarrHostUrl = 'http://10.114.238.136/';
const TwitarrConfiguration kShipTwitarrHost = RestTwitarrConfiguration(baseUrl: _kShipTwitarrHostUrl, builtin: true);
const String _kDevTwitarrUrl = 'https://twitarr.wookieefive.net/';
const TwitarrConfiguration kDevTwitarr = RestTwitarrConfiguration(baseUrl: _kDevTwitarrUrl, builtin: true);
