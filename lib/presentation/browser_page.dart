import 'dart:convert';

import 'package:flutter/material.dart';
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
  var _showProbe = true;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_title ?? 'In-app browser'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _ready ? _web.reload : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.language),
                hintText: 'https://…',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  onPressed: () => _go(_urlController.text),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
              onSubmitted: _go,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                for (final preset in browserPresets) ...[
                  ActionChip(
                    label: Text(preset.label),
                    onPressed: _ready
                        ? () {
                            _urlController.text = preset.url;
                            _go(preset.url);
                          }
                        : null,
                  ),
                  const SizedBox(width: 8),
                ],
                FilterChip(
                  label: const Text('Chrome UA'),
                  selected: _chromeUa,
                  onSelected: _ready
                      ? (value) async {
                          setState(() => _chromeUa = value);
                          await _applyUserAgent();
                          if (_urlController.text.isNotEmpty) {
                            await _web.reload();
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _SignalBanner(
              simulating: sim.status.simulating,
              pinLabel:
                  '${sim.pin.latitude.toStringAsFixed(5)}, ${sim.pin.longitude.toStringAsFixed(5)}',
              chromeUa: _chromeUa,
            ),
          ),
          if (_httpHint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _httpHint!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          Expanded(
            child: _ready
                ? WebViewWidget(controller: _web)
                : const Center(child: CircularProgressIndicator()),
          ),
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    dense: true,
                    title: const Text('Client signals'),
                    subtitle: const Text(
                      'What this WebView exposes. WAF still sees TLS and app id.',
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        _showProbe ? Icons.expand_more : Icons.expand_less,
                      ),
                      onPressed: () => setState(() => _showProbe = !_showProbe),
                    ),
                  ),
                  if (_showProbe)
                    _ProbePanel(probe: _probe, onReadGeo: _readGeo),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalBanner extends StatelessWidget {
  const _SignalBanner({
    required this.simulating,
    required this.pinLabel,
    required this.chromeUa,
  });

  final bool simulating;
  final String pinLabel;
  final bool chromeUa;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          simulating
              ? 'Mock GPS is on ($pinLabel). Office clock-in in this WebView should read that pin. IP/session city is unchanged. UA is ${chromeUa ? 'spoofed Chrome' : 'stock WebView'}.'
              : 'Mock GPS is off — this WebView will send the real device location if a site asks. Start simulation on the map first.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _ProbePanel extends StatelessWidget {
  const _ProbePanel({required this.probe, required this.onReadGeo});

  final Map<String, dynamic> probe;
  final VoidCallback onReadGeo;

  @override
  Widget build(BuildContext context) {
    final geo = probe['geo'];
    final ua = probe['userAgent'] as String?;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'UA: ${ua ?? '—'}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          Text('webdriver: ${probe['webdriver'] ?? '—'}'),
          Text('window.chrome: ${probe['hasChrome'] ?? '—'}'),
          Text(
            'timezone: ${probe['timezone'] ?? '—'} (offset ${probe['tzOffsetMinutes'] ?? '—'} min)',
          ),
          Text('languages: ${probe['languages'] ?? '—'}'),
          Text('geo API: ${probe['hasGeolocation'] ?? '—'}'),
          if (geo is Map)
            Text(
              geo['error'] != null
                  ? 'geo error: ${geo['error']}'
                  : 'geo: ${geo['latitude']}, ${geo['longitude']} ±${geo['accuracy']}m',
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onReadGeo,
            icon: const Icon(Icons.my_location),
            label: const Text('Read geolocation from this page'),
          ),
        ],
      ),
    );
  }
}
