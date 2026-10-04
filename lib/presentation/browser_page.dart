import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pinshift/core/browser_presets.dart';
import 'package:pinshift/data/pin_store.dart';
import 'package:pinshift/presentation/android_webview_config.dart';
import 'package:pinshift/presentation/simulation_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _probeChannel = 'PinshiftProbe';

const _probeScript = '''
(function() {
  const nav = navigator;
  const conn = nav.connection || nav.mozConnection || nav.webkitConnection;
  const payload = {
    userAgent: nav.userAgent,
    vendor: nav.vendor || null,
    platform: nav.platform || null,
    language: nav.language || null,
    languages: nav.languages ? Array.from(nav.languages) : [],
    webdriver: !!nav.webdriver,
    hardwareConcurrency: nav.hardwareConcurrency || null,
    deviceMemory: nav.deviceMemory || null,
    maxTouchPoints: nav.maxTouchPoints || null,
    cookieEnabled: nav.cookieEnabled,
    hasChrome: typeof window.chrome !== 'undefined',
    hasGeolocation: !!nav.geolocation,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    tzOffsetMinutes: new Date().getTimezoneOffset(),
    viewport: { innerWidth: window.innerWidth, innerHeight: window.innerHeight },
    connection: conn ? {
      effectiveType: conn.effectiveType || null,
      rtt: conn.rtt || null,
      downlink: conn.downlink || null
    } : null
  };
  PinshiftProbe.postMessage(JSON.stringify(payload));
})();
''';

const _geoScript = '''
(function() {
  if (!navigator.geolocation) {
    PinshiftProbe.postMessage(JSON.stringify({ geo: { error: 'no geolocation API' } }));
    return;
  }
  navigator.geolocation.getCurrentPosition(
    function(p) {
      PinshiftProbe.postMessage(JSON.stringify({
        geo: {
          latitude: p.coords.latitude,
          longitude: p.coords.longitude,
          accuracy: p.coords.accuracy
        }
      }));
    },
    function(e) {
      PinshiftProbe.postMessage(JSON.stringify({ geo: { error: e.message } }));
    },
    { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
  );
})();
''';

class BrowserPage extends ConsumerStatefulWidget {
  const BrowserPage({super.key});

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> {
  late final WebViewController _web;
  final _urlController = TextEditingController();
  final _store = PinStore();

  var _ready = false;
  var _loading = false;
  var _chromeUa = false;
  var _showProbe = false;
  var _hasPage = false;
  var _shortcutsOpen = true;
  String? _title;
  String? _httpHint;
  Map<String, dynamic> _probe = {};

  @override
  void initState() {
    super.initState();
    _web = WebViewController();
    Future<void>.microtask(_setup);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    await Permission.location.request();
    _chromeUa = await _store.loadChromeUserAgent();
    final last = await _store.loadLastBrowserUrl();
    if (last != null) {
      _urlController.text = last;
    }

    await _web.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _web.setBackgroundColor(const Color(0xFF101412));
    await _web.addJavaScriptChannel(
      _probeChannel,
      onMessageReceived: (message) {
        try {
          final decoded = jsonDecode(message.message);
          if (decoded is Map<String, dynamic>) {
            setState(() => _probe = {..._probe, ...decoded});
          }
        } catch (_) {}
      },
    );
    await _web.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          setState(() {
            _loading = true;
            _httpHint = null;
          });
        },
        onPageFinished: (url) async {
          _urlController.text = url;
          await _store.saveLastBrowserUrl(url);
          final title = await _web.getTitle();
          await _web.runJavaScript(_probeScript);
          if (mounted) {
            setState(() {
              _loading = false;
              _title = title;
            });
          }
        },
        onHttpError: (error) {
          final code = error.response?.statusCode;
          if (code == null) {
            return;
          }
          setState(() {
            _httpHint = code == 202 || code == 403 || code == 429
                ? 'HTTP $code — often a WAF/bot challenge or rate limit, not a GPS failure.'
                : 'HTTP $code';
          });
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame ?? true) {
            setState(() => _httpHint = error.description);
          }
        },
      ),
    );
    await configureAndroidWebView(_web);
    await _applyUserAgent();
    if (mounted) {
      setState(() => _ready = true);
    }
    final initial = parseBrowseUrl(_urlController.text);
    if (initial != null) {
      setState(() {
        _hasPage = true;
        _shortcutsOpen = false;
      });
      await _web.loadRequest(initial);
    }
  }

  Future<void> _applyUserAgent() async {
    await _web.setUserAgent(_chromeUa ? chromeMobileUserAgent : null);
    await _store.saveChromeUserAgent(_chromeUa);
  }

  Future<void> _go(String raw) async {
    final uri = parseBrowseUrl(raw);
    if (uri == null) {
      setState(() => _httpHint = 'Enter a valid https URL.');
      return;
    }
    setState(() {
      _probe = {};
      _httpHint = null;
      _hasPage = true;
      _shortcutsOpen = false;
    });
    await _web.loadRequest(uri);
  }

  Future<void> _readGeo() async {
    await Permission.location.request();
    await _web.runJavaScript(_geoScript);
  }

  @override
  Widget build(BuildContext context) {
    final sim = ref.watch(simulationControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      autocorrect: false,
                      onTap: () => setState(() => _shortcutsOpen = true),
                      decoration: InputDecoration(
                        hintText: 'Enter an address',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        isDense: true,
                        prefixIcon: const Icon(Icons.language, size: 20),
                        suffixIcon: IconButton(
                          tooltip: 'Go',
                          onPressed: () => _go(_urlController.text),
                          icon: const Icon(Icons.arrow_forward, size: 20),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _go,
                    ),
                  ),
                  IconButton(
                    tooltip: _shortcutsOpen ? 'Hide shortcuts' : 'Shortcuts',
                    onPressed: () =>
                        setState(() => _shortcutsOpen = !_shortcutsOpen),
                    icon: Icon(
                      Icons.bolt,
                      color: _shortcutsOpen ? scheme.primary : null,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reload',
                    onPressed: _ready ? _web.reload : null,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _shortcutsOpen
                  ? SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                        itemCount: browserPresets.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return FilterChip(
                              avatar: Icon(
                                Icons.shield_outlined,
                                size: 16,
                                color: _chromeUa
                                    ? scheme.onSecondaryContainer
                                    : scheme.primary,
                              ),
                              label: const Text('Chrome UA'),
                              selected: _chromeUa,
                              showCheckmark: false,
                              side: BorderSide.none,
                              backgroundColor: scheme.surfaceContainerHighest,
                              onSelected: _ready
                                  ? (value) async {
                                      setState(() => _chromeUa = value);
                                      await _applyUserAgent();
                                      if (_urlController.text.isNotEmpty) {
                                        await _web.reload();
                                      }
                                    }
                                  : null,
                            );
                          }
                          final preset = browserPresets[i - 1];
                          return ActionChip(
                            label: Text(preset.label),
                            side: BorderSide.none,
                            backgroundColor: scheme.surfaceContainerHighest,
                            onPressed: _ready
                                ? () {
                                    _urlController.text = preset.url;
                                    _go(preset.url);
                                  }
                                : null,
                          );
                        },
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _SignalPill(
                  onTap: () => Navigator.of(context).maybePop(),
                  simulating: sim.status.simulating,
                  pinLabel:
                      '${sim.pin.latitude.toStringAsFixed(4)}, ${sim.pin.longitude.toStringAsFixed(4)}',
                ),
              ),
            ),
            if (_httpHint != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 18,
                          color: scheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _httpHint!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_ready)
                      WebViewWidget(controller: _web)
                    else
                      const Center(child: CircularProgressIndicator()),
                    if (_ready && !_hasPage)
                      ColoredBox(
                        color: scheme.surface,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.travel_explore,
                                size: 48,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Open a site to test your location',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Type an address or pick a shortcut above.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_loading)
                      const Align(
                        alignment: Alignment.topCenter,
                        child: LinearProgressIndicator(minHeight: 3),
                      ),
                  ],
                ),
              ),
            ),
            _SignalsPanel(
              probe: _probe,
              title: _title,
              expanded: _showProbe,
              onToggle: () => setState(() => _showProbe = !_showProbe),
              onReadGeo: _readGeo,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalPill extends StatelessWidget {
  const _SignalPill({
    required this.simulating,
    required this.pinLabel,
    required this.onTap,
  });

  final bool simulating;
  final String pinLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = simulating
        ? const Color(0xFF3DDC84)
        : const Color(0xFFFFB84D);
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  simulating
                      ? 'Mock GPS on  ·  $pinLabel'
                      : 'Mock GPS off, real location exposed',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: scheme.onSurface),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalsPanel extends StatelessWidget {
  const _SignalsPanel({
    required this.probe,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.onReadGeo,
  });

  final Map<String, dynamic> probe;
  final String? title;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onReadGeo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final geo = probe['geo'];
    final languages = probe['languages'];
    final ua = probe['userAgent'] as String?;
    final tz = probe['timezone'];

    final rows = <Widget>[
      _SignalRow(
        label: 'User agent',
        value: Text(
          ua ?? '—',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        trailing: ua == null
            ? null
            : IconButton(
                tooltip: 'Copy user agent',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: ua));
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('User agent copied')),
                    );
                },
              ),
      ),
      _SignalRow(
        label: 'webdriver',
        value: _FlagBadge(value: probe['webdriver'], warnWhenTrue: true),
      ),
      _SignalRow(
        label: 'window.chrome',
        value: _FlagBadge(value: probe['hasChrome']),
      ),
      _SignalRow(
        label: 'Geolocation API',
        value: _FlagBadge(value: probe['hasGeolocation']),
      ),
      _SignalRow(
        label: 'Timezone',
        value: Text(
          tz == null
              ? '—'
              : '$tz  (UTC offset ${probe['tzOffsetMinutes']} min)',
          style: theme.textTheme.bodySmall,
        ),
      ),
      _SignalRow(
        label: 'Languages',
        value: Text(
          languages is List && languages.isNotEmpty
              ? languages.join(', ')
              : '—',
          style: theme.textTheme.bodySmall,
        ),
      ),
      if (geo is Map)
        _SignalRow(
          label: 'Page location',
          value: Text(
            geo['error'] != null
                ? '${geo['error']}'
                : '${geo['latitude']}, ${geo['longitude']}  ±${geo['accuracy']} m',
            style: theme.textTheme.bodySmall?.copyWith(
              color: geo['error'] != null ? scheme.error : null,
            ),
          ),
        ),
    ];

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                child: Row(
                  children: [
                    Icon(Icons.sensors, size: 20, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Client signals',
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            title ?? 'What sites can read from this WebView',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      expanded ? Icons.expand_more : Icons.expand_less,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        children: [
                          if (probe.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Open a page to read its signals.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          else
                            Material(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  for (var i = 0; i < rows.length; i++) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        indent: 14,
                                        endIndent: 14,
                                        color: scheme.outlineVariant.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    rows[i],
                                  ],
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: onReadGeo,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Read location from this page'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.label, required this.value, this.trailing});

  final String label;
  final Widget value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 10, trailing == null ? 14 : 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: value),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _FlagBadge extends StatelessWidget {
  const _FlagBadge({required this.value, this.warnWhenTrue = false});

  final Object? value;
  final bool warnWhenTrue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color;
    final String text;
    if (value is bool) {
      final on = value == true;
      text = on ? 'true' : 'false';
      color = on == warnWhenTrue
          ? const Color(0xFFFFB84D)
          : const Color(0xFF3DDC84);
    } else {
      text = '—';
      color = scheme.onSurfaceVariant;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}
