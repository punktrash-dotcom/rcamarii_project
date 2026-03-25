import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../themes/app_visuals.dart';

class WebViewScreen extends StatefulWidget {
  final String url;

  const WebViewScreen({super.key, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isUnsupportedPlatform = false;
  bool _didTearDownWebView = false;

  @override
  void initState() {
    super.initState();

    // webview_flutter 4.x supports Android and iOS.
    // Other platforms (Windows/Linux/macOS) require manual handling or
    // will throw the 'WebViewPlatform.instance != null' assertion.
    if (Platform.isAndroid || Platform.isIOS) {
      _initController();
    } else {
      setState(() {
        _isUnsupportedPlatform = true;
        _isLoading = false;
      });
    }
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppVisuals.dawnMist)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${error.description}')),
              );
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _tearDownWebView() async {
    if (_didTearDownWebView) {
      return;
    }
    _didTearDownWebView = true;

    final controller = _controller;
    if (controller == null) {
      return;
    }

    try {
      await controller.loadHtmlString(
        '<html><body style="background:#000;"></body></html>',
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _controller = null;
        _isLoading = false;
      });
    } else {
      _controller = null;
    }
  }

  Future<void> _closeScreen() async {
    await _tearDownWebView();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, __) {
        _tearDownWebView();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _closeScreen,
          ),
          title: const Text('Knowledge Center'),
          backgroundColor: AppVisuals.primaryGold,
          bottom: _isLoading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
          actions: [
            if (_controller != null) ...[
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _controller?.reload(),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  if (await _controller?.canGoBack() ?? false) {
                    await _controller?.goBack();
                  }
                },
              ),
            ],
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isUnsupportedPlatform) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.computer_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'DESKTOP PREVIEW LIMITATION',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),
              Text(
                'The WebView component is optimized for Android and iOS mobile devices. Please test on a mobile emulator or physical device to view: \n\n${widget.url}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppVisuals.textForestMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('RETURN TO HUB'),
              )
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ColoredBox(
          color: AppVisuals.dawnMist,
          child: _controller == null
              ? const SizedBox.expand()
              : WebViewWidget(controller: _controller!),
        ),
      ],
    );
  }
}
