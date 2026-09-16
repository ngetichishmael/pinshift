import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

Future<void> configureAndroidWebView(WebViewController controller) async {
  final platform = controller.platform;
  if (platform is! AndroidWebViewController) {
    return;
  }
  await AndroidWebViewController.enableDebugging(true);
  await platform.setGeolocationPermissionsPromptCallbacks(
    onShowPrompt: (request) async {
      return const GeolocationPermissionsResponse(allow: true, retain: true);
    },
  );
}
