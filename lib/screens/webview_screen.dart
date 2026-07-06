import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_theme.dart';
import '../widgets/volcano_background.dart';

/// Arguments shared by the WebView screen and its No-Internet fallback.
class WebViewArgs {
  const WebViewArgs({required this.title, required this.url});

  final String title;
  final String url;
}

/// Displays a remote page (Privacy Policy / Support) inside an in-app
/// WebView. Only reachable after a connectivity check from the caller.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key, required this.args});

  final WebViewArgs args;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  double _loadProgress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.obsidian)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _loadProgress = progress / 100);
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _hasError = false);
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() => _hasError = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.args.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidian,
      body: VolcanoBackground(
        overlayOpacity: 0.55,
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              if (_loadProgress < 1 && !_hasError)
                LinearProgressIndicator(
                  value: _loadProgress == 0 ? null : _loadProgress,
                  minHeight: 3,
                  backgroundColor: Colors.black26,
                  color: AppColors.lavaOrange,
                ),
              Expanded(
                child: _hasError
                    ? _buildError(context)
                    : Container(
                        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: WebViewWidget(controller: _controller),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.parchment),
          ),
          Expanded(
            child: Text(
              widget.args.title,
              style: AppTextStyles.heading.copyWith(fontSize: 20),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.lavaOrange, size: 56),
            const SizedBox(height: 12),
            Text(
              'This page could not be loaded.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() => _hasError = false);
                _controller.reload();
              },
              child: const Text('Retry', style: AppTextStyles.button),
            ),
          ],
        ),
      ),
    );
  }
}
