import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlMayaSemApp());
}

class AlMayaSemApp extends StatelessWidget {
  const AlMayaSemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'المياه السيم',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
      ),
      home: const WebViewPage(),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  static const String websiteUrl =
      'https://almayasem.sooqnaa.com/ar';

  late final WebViewController _controller;

  StreamSubscription<List<ConnectivityResult>>?
      _connectivitySubscription;

  bool _isLoading = true;
  bool _hasInternet = true;
  int _progress = 0;

  @override
  void initState() {
    super.initState();

    _createWebView();
    _checkInternet();
    _listenToConnectivity();
  }

  // ---------------------------------------------------------
  // WEBVIEW
  // ---------------------------------------------------------

  void _createWebView() {
    late final PlatformWebViewControllerCreationParams params;

    // iOS WKWebView settings
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction:
            const <PlaybackMediaTypes>{},
      );
    } else {
      params =
          const PlatformWebViewControllerCreationParams();
    }

    _controller =
        WebViewController.fromPlatformCreationParams(params)
          ..setJavaScriptMode(
            JavaScriptMode.unrestricted,
          )
          ..setBackgroundColor(Colors.white)
          ..enableZoom(false)
          ..setNavigationDelegate(
            NavigationDelegate(

              // -------------------------------
              // Loading progress
              // -------------------------------

              onProgress: (int progress) {
                if (!mounted) return;

                setState(() {
                  _progress = progress;
                  _isLoading = progress < 100;
                });
              },

              onPageStarted: (String url) {
                if (!mounted) return;

                setState(() {
                  _isLoading = true;
                  _progress = 0;
                });
              },

              onPageFinished: (String url) {
                if (!mounted) return;

                setState(() {
                  _isLoading = false;
                  _progress = 100;
                  _hasInternet = true;
                });
              },

              // -------------------------------
              // Handle WhatsApp / phone / email
              // -------------------------------

              onNavigationRequest:
                  (NavigationRequest request) async {
                final Uri? uri =
                    Uri.tryParse(request.url);

                if (uri == null) {
                  return NavigationDecision.prevent;
                }

                final String scheme =
                    uri.scheme.toLowerCase();

                // WhatsApp links
                if (scheme == 'whatsapp' ||
                    scheme == 'whatsapp-web') {
                  await _openExternalUrl(uri);
                  return NavigationDecision.prevent;
                }

                // WhatsApp web links
                if (uri.host.contains('wa.me') ||
                    uri.host.contains('whatsapp.com')) {
                  await _openExternalUrl(uri);
                  return NavigationDecision.prevent;
                }

                // Phone numbers
                if (scheme == 'tel') {
                  await _openExternalUrl(uri);
                  return NavigationDecision.prevent;
                }

                // Email
                if (scheme == 'mailto') {
                  await _openExternalUrl(uri);
                  return NavigationDecision.prevent;
                }

                // SMS
                if (scheme == 'sms') {
                  await _openExternalUrl(uri);
                  return NavigationDecision.prevent;
                }

                // Normal website links
                return NavigationDecision.navigate;
              },

              // -------------------------------
              // Web resource errors
              // -------------------------------

              onWebResourceError:
                  (WebResourceError error) {
                // Only handle errors for the main page.
               if (error.isForMainFrame == false) {
                  return;
                }

                if (!mounted) return;

                setState(() {
                  _isLoading = false;
                  _hasInternet = false;
                });
              },

              onHttpError: (HttpResponseError error) {
                debugPrint(
                  'HTTP Error: '
                  '${error.response?.statusCode}',
                );
              },
            ),
          )
          ..loadRequest(
            Uri.parse(websiteUrl),
          );

    // Enable native iOS back/forward swipe gestures.
    if (_controller.platform
        is WebKitWebViewController) {
      final WebKitWebViewController iosController =
          _controller.platform
              as WebKitWebViewController;

      iosController.setAllowsBackForwardNavigationGestures(
        true,
      );
    }
  }

  // ---------------------------------------------------------
  // OPEN EXTERNAL LINKS
  // ---------------------------------------------------------

  Future<void> _openExternalUrl(Uri uri) async {
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showMessage(
          'لا يمكن فتح هذا الرابط',
        );
      }
    } catch (e) {
      debugPrint(
        'External URL error: $e',
      );

      if (mounted) {
        _showMessage(
          'حدث خطأ أثناء فتح الرابط',
        );
      }
    }
  }

  // ---------------------------------------------------------
  // INTERNET CONNECTION
  // ---------------------------------------------------------

  Future<void> _checkInternet() async {
    try {
      final List<ConnectivityResult> results =
          await Connectivity().checkConnectivity();

      final bool connected = results.any(
        (result) =>
            result != ConnectivityResult.none,
      );

      if (!connected && mounted) {
        setState(() {
          _hasInternet = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(
        'Internet check error: $e',
      );
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription =
        Connectivity()
            .onConnectivityChanged
            .listen(
      (List<ConnectivityResult> results) {
        final bool connected = results.any(
          (result) =>
              result != ConnectivityResult.none,
        );

        if (!mounted) return;

        setState(() {
          _hasInternet = connected;
        });

        if (connected) {
          _reloadWebsite();
        }
      },
    );
  }

  // ---------------------------------------------------------
  // RELOAD
  // ---------------------------------------------------------

  Future<void> _reloadWebsite() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _progress = 0;
    });

    try {
      await _controller.reload();
    } catch (e) {
      debugPrint(
        'Reload error: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasInternet = false;
      });
    }
  }

  // ---------------------------------------------------------
  // PULL TO REFRESH
  // ---------------------------------------------------------

  Future<void> _refreshPage() async {
    try {
      final List<ConnectivityResult> results =
          await Connectivity().checkConnectivity();

      final bool connected = results.any(
        (result) =>
            result != ConnectivityResult.none,
      );

      if (!connected) {
        if (mounted) {
          setState(() {
            _hasInternet = false;
          });
        }
        return;
      }

      await _controller.reload();

      await Future.delayed(
        const Duration(
          milliseconds: 500,
        ),
      );
    } catch (e) {
      debugPrint(
        'Refresh error: $e',
      );
    }
  }

  // ---------------------------------------------------------
  // SHARE
  // ---------------------------------------------------------

  Future<void> _shareWebsite(
    BuildContext context,
  ) async {
    final RenderBox? box =
        context.findRenderObject() as RenderBox?;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'تفضل بزيارة موقع المياه السيم:\n'
              '$websiteUrl',
          subject: 'المياه السيم',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(
                    Offset.zero,
                  ) &
                  box.size,
        ),
      );
    } catch (e) {
      debugPrint(
        'Share error: $e',
      );
    }
  }

  // ---------------------------------------------------------
  // BACK NAVIGATION
  // ---------------------------------------------------------

  Future<bool> _handleBack() async {
    final bool canGoBack =
        await _controller.canGoBack();

    if (canGoBack) {
      await _controller.goBack();
      return false;
    }

    return true;
  }

  // ---------------------------------------------------------
  // MESSAGE
  // ---------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ---------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------
  // UI
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,

      onPopInvokedWithResult:
          (bool didPop, dynamic result) async {
        if (didPop) return;

        final bool shouldClose =
            await _handleBack();

        if (shouldClose && context.mounted) {
          Navigator.of(context).pop();
        }
      },

      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'سوبر ماركت أبو وديع',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          actions: [
            Builder(
              builder: (shareContext) {
                return IconButton(
                  tooltip: 'مشاركة',
                  icon: const Icon(
                    Icons.share,
                  ),
                  onPressed: () {
                    _shareWebsite(
                      shareContext,
                    );
                  },
                );
              },
            ),
          ],
        ),

        body: !_hasInternet
            ? _buildOfflineScreen()
            : Column(
                children: [

                  // Top progress bar
                  if (_isLoading &&
                      _progress < 100)
                    LinearProgressIndicator(
                      value: _progress > 0
                          ? _progress / 100
                          : null,
                      minHeight: 3,
                    ),

                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshPage,

                      child: WebViewWidget(
                        controller:
                            _controller,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ---------------------------------------------------------
  // OFFLINE SCREEN
  // ---------------------------------------------------------

  Widget _buildOfflineScreen() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [

            const Icon(
              Icons.wifi_off_rounded,
              size: 80,
              color: Colors.grey,
            ),

            const SizedBox(height: 24),

            const Text(
              'لا يوجد اتصال بالإنترنت',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'يرجى التحقق من اتصالك '
              'بالإنترنت ثم المحاولة مرة أخرى.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 28),

            ElevatedButton.icon(
              onPressed: () async {
                await _checkInternet();

                if (_hasInternet) {
                  await _reloadWebsite();
                }
              },
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'إعادة المحاولة',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
