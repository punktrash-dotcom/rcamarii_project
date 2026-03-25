import 'package:flutter/material.dart';

class UserSetupResult {
  const UserSetupResult({
    required this.userName,
    required this.appLockEnabled,
    required this.password,
  });

  final String userName;
  final bool appLockEnabled;
  final String password;
}

Future<UserSetupResult?> showFirstRunSetupDialog(BuildContext context) {
  return showDialog<UserSetupResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _UserAccessDialog(
      title: 'Set up RCAMARii',
      description:
          'Enter your name and choose whether the app should ask for a password on startup.',
      confirmLabel: 'Continue',
      allowDismiss: false,
      initialName: '',
      initialAppLockEnabled: false,
      initialPassword: '',
    ),
  );
}

Future<bool> showPasswordVerificationDialog(
  BuildContext context, {
  required String expectedPassword,
  required String title,
  required String message,
  bool allowCancel = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: allowCancel,
    builder: (_) => _PasswordVerificationDialog(
      expectedPassword: expectedPassword,
      title: title,
      message: message,
      allowCancel: allowCancel,
    ),
  );

  return result ?? false;
}

Future<String?> showUserNameEditDialog(
  BuildContext context, {
  required String initialName,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _EditUserNameDialog(initialName: initialName),
  );
}

Future<UserSetupResult?> showUserAccessEditDialog(
  BuildContext context, {
  required String initialName,
  required bool initialAppLockEnabled,
  required String initialPassword,
}) {
  return showDialog<UserSetupResult>(
    context: context,
    builder: (_) => _UserAccessDialog(
      title: 'Edit account access',
      description:
          'Update the saved username and startup password settings for this device.',
      confirmLabel: 'Save',
      allowDismiss: true,
      initialName: initialName,
      initialAppLockEnabled: initialAppLockEnabled,
      initialPassword: initialPassword,
    ),
  );
}

class _UserAccessDialog extends StatefulWidget {
  const _UserAccessDialog({
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.allowDismiss,
    required this.initialName,
    required this.initialAppLockEnabled,
    required this.initialPassword,
  });

  final String title;
  final String description;
  final String confirmLabel;
  final bool allowDismiss;
  final String initialName;
  final bool initialAppLockEnabled;
  final String initialPassword;

  @override
  State<_UserAccessDialog> createState() => _UserAccessDialogState();
}

class _UserAccessDialogState extends State<_UserAccessDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  final TextEditingController _passwordController = TextEditingController();

  late bool _appLockEnabled = widget.initialAppLockEnabled;
  bool _obscurePassword = true;
  String? _nameError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmedName = _nameController.text.trim();
    final trimmedPassword = _passwordController.text.trim();
    final resolvedPassword = !_appLockEnabled
        ? ''
        : trimmedPassword.isNotEmpty
            ? trimmedPassword
            : widget.initialPassword;

    setState(() {
      _nameError = trimmedName.isEmpty ? 'Enter your name.' : null;
      _passwordError = _appLockEnabled && resolvedPassword.isEmpty
          ? 'Enter a password to lock the app.'
          : null;
    });

    if (_nameError != null || _passwordError != null) {
      return;
    }

    Navigator.of(context).pop(
      UserSetupResult(
        userName: trimmedName,
        appLockEnabled: _appLockEnabled,
        password: resolvedPassword,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: widget.allowDismiss,
      child: AlertDialog(
        title: Text(widget.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.description,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Your name',
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  value: _appLockEnabled,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lock the app on startup'),
                  subtitle: const Text(
                      'Require a password before opening the dashboard.'),
                  onChanged: (value) {
                    setState(() {
                      _appLockEnabled = value;
                      if (!value) {
                        _passwordError = null;
                        _passwordController.clear();
                      }
                    });
                  },
                ),
                if (_appLockEnabled) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: widget.initialPassword.isNotEmpty
                          ? 'New password'
                          : 'Password',
                      helperText: widget.initialPassword.isNotEmpty
                          ? 'Leave blank to keep the current password.'
                          : null,
                      errorText: _passwordError,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (widget.allowDismiss)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _PasswordVerificationDialog extends StatefulWidget {
  const _PasswordVerificationDialog({
    required this.expectedPassword,
    required this.title,
    required this.message,
    required this.allowCancel,
  });

  final String expectedPassword;
  final String title;
  final String message;
  final bool allowCancel;

  @override
  State<_PasswordVerificationDialog> createState() =>
      _PasswordVerificationDialogState();
}

class _PasswordVerificationDialogState
    extends State<_PasswordVerificationDialog> {
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_passwordController.text == widget.expectedPassword) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _errorText = 'Incorrect password.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.allowCancel,
      child: AlertDialog(
        title: Text(widget.title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                autofocus: true,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: _errorText,
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (widget.allowCancel)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          FilledButton(
            onPressed: _submit,
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }
}

class _EditUserNameDialog extends StatefulWidget {
  const _EditUserNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditUserNameDialog> createState() => _EditUserNameDialogState();
}

class _EditUserNameDialogState extends State<_EditUserNameDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);

  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() {
        _errorText = 'Enter your name.';
      });
      return;
    }

    Navigator.of(context).pop(trimmedName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit name'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: TextField(
          controller: _nameController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Your name',
            errorText: _errorText,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
