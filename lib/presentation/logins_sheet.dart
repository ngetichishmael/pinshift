import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinshift/core/saved_login.dart';
import 'package:pinshift/data/login_vault.dart';
import 'package:pinshift/presentation/logins_controller.dart';

typedef PageCredentials = ({String username, String password});

Future<void> showLoginsSheet(
  BuildContext context, {
  required String? pageHost,
  required Future<void> Function(SavedLogin login) onFill,
  required Future<PageCredentials?> Function() readFromPage,
  required void Function(String host) onOpenSite,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _LoginsSheet(
      pageHost: pageHost,
      onFill: onFill,
      readFromPage: readFromPage,
      onOpenSite: onOpenSite,
    ),
  );
}

enum _Gate { checking, unlocked, denied, unavailable }

class _LoginsSheet extends ConsumerStatefulWidget {
  const _LoginsSheet({
    required this.pageHost,
    required this.onFill,
    required this.readFromPage,
    required this.onOpenSite,
  });

  final String? pageHost;
  final Future<void> Function(SavedLogin login) onFill;
  final Future<PageCredentials?> Function() readFromPage;
  final void Function(String host) onOpenSite;

  @override
  ConsumerState<_LoginsSheet> createState() => _LoginsSheetState();
}

class _LoginsSheetState extends ConsumerState<_LoginsSheet> {
  late final LoginsController _controller = ref.read(
    loginsControllerProvider.notifier,
  );
  var _gate = _Gate.checking;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_unlock);
  }

  @override
  void dispose() {
    _controller.lock();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() => _gate = _Gate.checking);
    final result = await _controller.unlock();
    if (!mounted) {
      return;
    }
    setState(() {
      _gate = switch (result) {
        UnlockResult.unlocked => _Gate.unlocked,
        UnlockResult.denied => _Gate.denied,
        UnlockResult.unavailable => _Gate.unavailable,
      };
    });
  }

  Future<void> _edit([SavedLogin? existing]) async {
    final draft = await showDialog<_LoginDraft>(
      context: context,
      builder: (_) => _LoginDialog(
        existing: existing,
        initialHost: widget.pageHost ?? '',
        readFromPage: widget.readFromPage,
      ),
    );
    if (draft == null) {
      return;
    }
    if (existing == null) {
      await _controller.add(
        host: draft.host,
        username: draft.username,
        password: draft.password,
      );
    } else {
      await _controller.edit(
        existing.id,
        host: draft.host,
        username: draft.username,
        password: draft.password,
      );
    }
  }

  Future<void> _delete(SavedLogin login) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete login?'),
        content: Text(
          'The saved login for ${login.host} will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller.delete(login.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: switch (_gate) {
        _Gate.checking => const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
        _Gate.unlocked => _buildList(theme),
        _Gate.denied => _Notice(
          icon: Icons.lock_outline,
          title: 'Saved logins are locked',
          message: 'Unlock with Face ID, fingerprint or your device passcode.',
          action: FilledButton(onPressed: _unlock, child: const Text('Unlock')),
        ),
        _Gate.unavailable => const _Notice(
          icon: Icons.phonelink_lock_outlined,
          title: 'Screen lock required',
          message:
              'Set up a passcode, PIN or biometrics on this device to use saved logins.',
        ),
      },
    );
  }

  Widget _buildList(ThemeData theme) {
    final logins = ref.watch(loginsControllerProvider);
    final scheme = theme.colorScheme;
    final here = [
      for (final l in logins)
        if (loginMatchesHost(l, widget.pageHost)) l,
    ];
    final others = [
      for (final l in logins)
        if (!loginMatchesHost(l, widget.pageHost)) l,
    ];

    Widget row(SavedLogin login, {required bool matches}) {
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.surfaceContainerHighest,
          child: Text(
            login.host.isEmpty ? '?' : login.host[0].toUpperCase(),
            style: theme.textTheme.titleSmall,
          ),
        ),
        title: Text(login.host, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          login.username.isEmpty ? 'No username' : login.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (matches)
              FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onFill(login);
                },
                child: const Text('Fill'),
              )
            else
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOpenSite(login.host);
                },
                child: const Text('Open site'),
              ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) =>
                  value == 'edit' ? _edit(login) : _delete(login),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      );
    }

    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Saved logins',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Add login',
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (logins.isEmpty)
            _Notice(
              icon: Icons.key_off_outlined,
              title: 'No saved logins yet',
              message:
                  'Type your email and password into a sign-in page, then add the login here and use "Read from page".',
              action: FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Add login'),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (here.isNotEmpty) ...[
                    label('This site'),
                    for (final l in here) row(l, matches: true),
                  ],
                  if (others.isNotEmpty) ...[
                    label(here.isEmpty ? 'All logins' : 'Other sites'),
                    for (final l in others) row(l, matches: false),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

typedef _LoginDraft = ({String host, String username, String password});

class _LoginDialog extends StatefulWidget {
  const _LoginDialog({
    required this.existing,
    required this.initialHost,
    required this.readFromPage,
  });

  final SavedLogin? existing;
  final String initialHost;
  final Future<PageCredentials?> Function() readFromPage;

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  late final _host = TextEditingController(
    text: widget.existing?.host ?? normalizeHost(widget.initialHost),
  );
  late final _username = TextEditingController(
    text: widget.existing?.username ?? '',
  );
  late final _password = TextEditingController(
    text: widget.existing?.password ?? '',
  );
  var _obscure = true;
  var _reading = false;
  String? _hint;

  @override
  void dispose() {
    _host.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    setState(() {
      _reading = true;
      _hint = null;
    });
    final found = await widget.readFromPage();
    if (!mounted) {
      return;
    }
    setState(() {
      _reading = false;
      if (found == null || found.password.isEmpty) {
        _hint = 'No filled-in password field found on this page.';
        return;
      }
      _username.text = found.username;
      _password.text = found.password;
    });
  }

  bool get _valid =>
      normalizeHost(_host.text).isNotEmpty && _password.text.isNotEmpty;

  void _submit() {
    if (!_valid) {
      return;
    }
    Navigator.of(context).pop((
      host: _host.text,
      username: _username.text.trim(),
      password: _password.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add login' : 'Edit login'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _host,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Website'),
              onChanged: (_) => setState(() {}),
            ),
            TextField(
              controller: _username,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email or username'),
            ),
            TextField(
              controller: _password,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _reading ? null : _read,
              icon: _reading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: const Text('Read from page'),
            ),
            if (_hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _hint!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid ? _submit : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
