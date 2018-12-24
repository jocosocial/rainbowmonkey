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
  _CreateAccountDialogState createState() => new _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<CreateAccountDialog> {
  final TextEditingController _username = new TextEditingController();
  final TextEditingController _password1 = new TextEditingController();
  final TextEditingController _password2 = new TextEditingController();
  final TextEditingController _email = new TextEditingController();
  final TextEditingController _securityQuestion = new TextEditingController();
  final TextEditingController _securityAnswer = new TextEditingController();
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();

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
      builder: (BuildContext context) => new _AccountCreationStatus(
        username: _username.text,
        progress: progress,
      ),
    );
    if (close == true)
      Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return new AlertDialog(
      title: const Text('Create Twitarr account'),
      contentPadding: const EdgeInsets.fromLTRB(0.0, 20.0, 0.0, 0.0),
      content: new DecoratedBox(
        decoration: new BoxDecoration(
          border: new Border(
            top: Divider.createBorderSide(context),
            bottom: Divider.createBorderSide(context),
          ),
        ),
        child: new Form(
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
              builder: (BuildContext context) => new AlertDialog(
                title: const Text('Cancel account creation?'),
                actions: <Widget>[
                  new FlatButton(
                    onPressed: () { Navigator.of(context).pop(true); },
                    child: const Text('YES'),
                  ),
                  new FlatButton(
                    onPressed: () { Navigator.of(context).pop(false); },
                    child: const Text('NO'),
                  ),
                ],
              ),
            ) == true;
          },
          child: new SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 8.0),
            child: new ListBody(
              children: <Widget>[
                const Text(
                  'To create an account on the Twitarr server, please fill in the '
                  'following fields, then press the "Create account" button below.'
                ),
                const SizedBox(height: 12.0),
                new SizedBox(
                  height: 96.0,
                  child: new Align(
                    alignment: AlignmentDirectional.topStart,
                    child: new TextFormField(
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
                new SizedBox(
                  height: 96.0,
                  child: new Align(
                    alignment: AlignmentDirectional.topStart,
                    child: new TextFormField(
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
                new SizedBox(
                  height: 96.0,
                  child: new Align(
                    alignment: AlignmentDirectional.topStart,
                    child: new TextFormField(
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
                new SizedBox(
                  height: 96.0,
                  child: new Align(
                    alignment: AlignmentDirectional.topStart,
                    child: new TextFormField(
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
                new SizedBox(
                  height: 96.0,
                  child: new Align(
                    alignment: AlignmentDirectional.topStart,
                    child: new TextFormField(
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
                new SizedBox(
                  height: 96.0,
                  child: new Align(
                    alignment: AlignmentDirectional.topStart,
                    child: new TextFormField(
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
        new FlatButton(
          onPressed: _valid ? _createAccount : null,
          child: const Text('CREATE ACCOUNT'),
        ),
        new FlatButton(
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
    final Widget idleStatus = new AlertDialog(
      title: const Text('Creating account...'),
      content: const Center(
        heightFactor: 1.5,
        child: const CircularProgressIndicator(),
      ),
      actions: <Widget>[
        new FlatButton(
          onPressed: () { Navigator.of(context).pop(true); },
          child: const Text('CANCEL'),
        ),
      ],
    );
    return new ProgressBuilder<Credentials>(
      progress: progress,
      idleChild: idleStatus,
      startingChild: idleStatus,
      activeBuilder: (BuildContext context, double progress, double target) {
        return new AlertDialog(
          title: const Text('Creating account...'),
          content: new Center(
            heightFactor: 1.5,
            child: new CircularProgressIndicator(
              value: progress / target,
            ),
          ),
          actions: <Widget>[
            new FlatButton(
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
        return new AlertDialog(
          title: const Text('Account creation failed'),
          content: new SingleChildScrollView(
            child: new ListBody(
              children: messages.map<Widget>((String message) => new Text(message)).toList(),
            ),
          ),
          actions: <Widget>[
            new FlatButton(
              onPressed: () { Navigator.of(context).pop(true); },
              child: const Text('CANCEL'),
            ),
            new FlatButton(
              onPressed: () { Navigator.of(context).pop(false); },
              child: const Text('BACK'),
            ),
          ],
        );
      },
      builder: (BuildContext context, Credentials value) {
        return new AlertDialog(
          title: const Text('Account created!'),
          content: new Text('Your account username is "$username".'),
          actions: <Widget>[
            new FlatButton(
              onPressed: () { Navigator.of(context).pop(true); },
              child: const Text('YAY!'),
            ),
          ],
        );
      }
    );
  }
}