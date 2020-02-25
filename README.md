# Rainbow Monkey

The client application for the cruise, for Android and iOS. Useless without a server; see the accompanying repository.

This app is codenamed "cruisemonkey", named after @rangerrick's app,
but to reduce confusion it is branded as Rainbow Monkey is the stores
and in the application itself.


## Updating the Karaoke list

Make sure that the `resources/JoCoKaraokeSongCatalog.txt` file is in
UTF-8. The original file was in Mac OS Roman; to convert from that to
UTF-8, you can use this command:

```bash
uconv --from-code mac --to-code utf8 --output converted.txt JoCoKaraokeSongCatalog.txt
```

You may also need to replace U+000D characters with U+000A characters.


## Deployment

Update the version in `pubspec.yaml`.

Run `flutter build appbundle --build-number X` (set X to a number higher than ever before; that sets the versionCode).

That creates `build/app/outputs/bundle/release/app-release.aab`, which you upload at: https://play.google.com/apps/publish

You can figure out what the build number should be by looking at the Play console, you want "Version code + 1".
