import 'rest.dart';
import 'twitarr.dart';

// for 2020 cruise
const String _kShipTwitarrUrl = 'https://twitarr.com/';
const TwitarrConfiguration kShipTwitarr = RestTwitarrConfiguration(baseUrl: _kShipTwitarrUrl, builtin: true);

const String _kShipTwitarrUnencryptedUrl1 = 'http://joco.hollandamerica.com/';
const TwitarrConfiguration kShipTwitarrUnencrypted1 = RestTwitarrConfiguration(baseUrl: _kShipTwitarrUnencryptedUrl1, builtin: true);

const String _kShipTwitarrUnencryptedUrl2 = 'http://10.114.238.135/';
const TwitarrConfiguration kShipTwitarrUnencrypted2 = RestTwitarrConfiguration(baseUrl: _kShipTwitarrUnencryptedUrl2, builtin: true);

const String _kShipTwitarrHostUrl = 'http://10.114.238.136/';
const TwitarrConfiguration kShipTwitarrHost = RestTwitarrConfiguration(baseUrl: _kShipTwitarrHostUrl, builtin: true);

const String _kDevTwitarrUrl = 'https://twitarr.wookieefive.net/';
const TwitarrConfiguration kDevTwitarr = RestTwitarrConfiguration(baseUrl: _kDevTwitarrUrl, builtin: true);
