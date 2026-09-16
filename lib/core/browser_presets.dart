Uri? parseBrowseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final withScheme = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  return uri;
}

class BrowserPreset {
  const BrowserPreset({required this.label, required this.url});

  final String label;
  final String url;
}

const browserPresets = <BrowserPreset>[
  BrowserPreset(
    label: 'Shinrai HRMS',
    url: 'https://hrms.shinraitechnologies.io/',
  ),
  BrowserPreset(label: 'BrowserLeaks geo', url: 'https://browserleaks.com/geo'),
  BrowserPreset(label: 'What is my IP', url: 'https://ifconfig.me/'),
];

/// Typical Android Chrome UA. WebView TLS, Client Hints, and
/// `X-Requested-With` can still identify this as an embedded WebView.
const chromeMobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.6778.135 Mobile Safari/537.36';
