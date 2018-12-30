import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/user.dart';
import '../network/twitarr.dart';
import '../progress.dart';
import '../widgets.dart';

class CreateAccountDialog extends StatefulWidget {
  const CreateAccountDialog({
    Key key,
  }) : super(key: key);

  @override
  _CreateAccountDialogState createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<CreateAccountDialog> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password1 = TextEditingController();
  final TextEditingController _password2 = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _securityQuestion = TextEditingController();
  final TextEditingController _securityAnswer = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool get _valid {
    return AuthenticatedUser.isValidUsername(_username.text) &&
           AuthenticatedUser.isValidDisplayName(_username.text) &&
           AuthenticatedUser.isValidPassword(_password1.text) &&
           (_password1.text == _password2.text) &&
           AuthenticatedUser.isValidEmail(_email.text) &&
           AuthenticatedUser.isValidSecurityQuestion(_securityQuestion.text) &&
           AuthenticatedUser.isValidSecurityAnswer(_securityAnswer.text);
  }

  void _createAccount() async {
    assert(_valid);
    final Progress<Credentials> progress = Cruise.of(context).createAccount(
      username: _username.text,
      password: _password1.text,
      email: _email.text,
      securityQuestion: _securityQuestion.text,
      securityAnswer: _securityAnswer.text,
    );
    final bool close = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _AccountCreationStatus(
        username: _username.text,
        progress: progress,
      ),
    );
    if (close == true)
      Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Twitarr account'),
      contentPadding: const EdgeInsets.fromLTRB(0.0, 20.0, 0.0, 0.0),
      content: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: Divider.createBorderSide(context),
            bottom: Divider.createBorderSide(context),
          ),
        ),
        child: Form(
          key: _formKey,
          autovalidate: true,
          onChanged: () {
            setState(() {
              /* need to recheck whether the submit button should be enabled */
            });
          },
          onWillPop: () async {
            return await showDialog<bool>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('Cancel account creation?'),
                actions: <Widget>[
                  FlatButton(
                    onPressed: () { Navigator.of(context).pop(true); },
                    child: const Text('YES'),
                  ),
                  FlatButton(
                    onPressed: () { Navigator.of(context).pop(false); },
                    child: const Text('NO'),
                  ),
                ],
              ),
            ) == true;
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 8.0),
            child: ListBody(
              children: <Widget>[
                const Text(
                  'To create an account on the Twitarr server, please fill in the '
                  'following fields, then press the "Create account" button below.'
                ),
                const SizedBox(height: 12.0),
                SizedBox(
                  height: 96.0,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(
                        labelText: 'User name',
                      ),
                      validator: (String name) {
                        if (!AuthenticatedUser.isValidUsername(name))
                          return 'User names must be alphabetic and at least three characters long.';
                        if (!AuthenticatedUser.isValidDisplayName(name))
                          return 'User names are also used as display names, which must be no more than 40 characters long.';
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: 96.0,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: TextFormField(
                      controller: _password1,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                      ),
                      validator: (String password) {
                        if (!AuthenticatedUser.isValidPassword(password))
                          return 'Passwords must be at least six characters long.';
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: 96.0,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: TextFormField(
                      controller: _password2,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        helperText: 'To make sure you know it.',
                      ),
                      validator: (String password) {
                        if (password != _password1.text)
                          return 'Passwords don\'t match.';
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: 96.0,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        helperText: 'Only visible to administrators.',
                      ),
                      validator: (String email) {
                        if (!AuthenticatedUser.isValidEmail(email))
                          return 'E-mail is not valid.';
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: 96.0,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: TextFormField(
                      controller: _securityQuestion,
                      decoration: const InputDecoration(
                        labelText: 'Security question',
                      ),
                      validator: (String securityQuestion) {
                        if (!AuthenticatedUser.isValidSecurityQuestion(securityQuestion))
                          return 'You need a security question.';
                      },
                    ),
                  ),
                ),
                SizedBox(
                  height: 96.0,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: TextFormField(
                      controller: _securityAnswer,
                      decoration: const InputDecoration(
                        labelText: 'Security answer',
                      ),
                      validator: (String securityAnswer) {
                        if (!AuthenticatedUser.isValidSecurityAnswer(securityAnswer))
                          return 'You need a security answer.';
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        FlatButton(
          onPressed: _valid ? _createAccount : null,
          child: const Text('CREATE ACCOUNT'),
        ),
        FlatButton(
          onPressed: () async {
            if (await Navigator.maybePop(context) && mounted)
              Navigator.pop(context);
          },
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}

class _AccountCreationStatus extends StatelessWidget {
  const _AccountCreationStatus({
    Key key,
    @required this.progress,
    @required this.username,
  }) : assert(progress != null),
       assert(username != null),
       super(key: key);

  final Progress<Credentials> progress;
  final String username;

  @override
  Widget build(BuildContext context) {
    final Widget idleStatus = AlertDialog(
      title: const Text('Creating account...'),
      content: const Center(
        heightFactor: 1.5,
        child: CircularProgressIndicator(),
      ),
      actions: <Widget>[
        FlatButton(
          onPressed: () { Navigator.of(context).pop(true); },
          child: const Text('CANCEL'),
        ),
      ],
    );
    return ProgressBuilder<Credentials>(
      progress: progress,
      idleChild: idleStatus,
      startingChild: idleStatus,
      activeBuilder: (BuildContext context, double progress, double target) {
        return AlertDialog(
          title: const Text('Creating account...'),
          content: Center(
            heightFactor: 1.5,
            child: CircularProgressIndicator(
              value: progress / target,
            ),
          ),
          actions: <Widget>[
            FlatButton(
              onPressed: () { Navigator.of(context).pop(true); },
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
      failedBuilder: (BuildContext context, Exception error, StackTrace stackTrace) {
        final List<String> messages = <String>[];
        if (error is ServerError) {
          for (String message in error.messages) {
            message = message.trim();
            // The server doesn't send back fully punctuated messages, so
            // we fix them up here.
            if (message.endsWith('.') || message.endsWith('?') || message.endsWith('!')) {
              messages.add(message);
            } else {
              messages.add('$message.');
            }
          }
          if (messages.isEmpty)
            messages.add('The server unfortunately did not send back a reason why the account creation failed.');
        } else {
          messages.add('An unexpected error occurred:\n$error');
        }
        return AlertDialog(
          title: const Text('Account creation failed'),
          content: SingleChildScrollView(
            child: ListBody(
              children: messages.map<Widget>((String message) => Text(message)).toList(),
            ),
          ),
          actions: <Widget>[
            FlatButton(
              onPressed: () { Navigator.of(context).pop(true); },
              child: const Text('CANCEL'),
            ),
            FlatButton(
              onPressed: () { Navigator.of(context).pop(false); },
              child: const Text('BACK'),
            ),
          ],
        );
      },
      builder: (BuildContext context, Credentials value) {
        return AlertDialog(
          title: const Text('Account created!'),
          content: Text('Your account username is "${value.username}".'),
          actions: <Widget>[
            FlatButton(
              onPressed: () { Navigator.of(context).pop(true); },
              child: const Text('YAY!'),
            ),
          ],
        );
      }
    );
  }
}