import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets.dart';

class CodeOfConduct extends StatelessWidget {
  const CodeOfConduct({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Code of Conduct'),
      ),
      body: const SingleChildScrollView(
        child: ServerTextView('codeofconduct'),
      ),
    );
  }
}
