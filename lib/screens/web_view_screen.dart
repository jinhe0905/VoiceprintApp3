import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert' show json;

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({Key? key}) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late WebViewController controller;
  bool isLoading = true;
  bool isOffline = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Directory webDirectory;
  bool permissionsGranted = false;
  final String initialPage = 'index.html';

  @override
  void initState() {
    super.initState();
    _setupWebView();
    _checkConnectivity();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      // 检查权限状态
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.storage,
      ].request();
  
      bool allGranted = true;
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          allGranted = false;
        }
      });
  
      setState(() {
        permissionsGranted = allGranted;
      });
  
      if (!permissionsGranted) {
        // 延迟显示权限对话框，避免应用启动时就弹出对话框
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _showPermissionDialog();
          }
        });
      }
    } catch (e) {
      print('权限检查错误: $e');
      // 即使权限检查失败，也允许应用继续运行
      setState(() {
        permissionsGranted = false;
      });
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('需要权限'),
          content: const Text('声纹识别系统需要麦克风和存储权限才能正常工作。请在设置中启用这些权限。'),
          actions: <Widget>[
            TextButton(
              child: const Text('打开设置'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('稍后再说'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isOffline = connectivityResult == ConnectivityResult.none;
    });

    // 监听连接状态变化
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        isOffline = result == ConnectivityResult.none;
      });
      if (!isOffline) {
        controller.reload();
      }
    });
  }

  Future<void> _setupWebView() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      webDirectory = Directory('${directory.path}/web_assets');
      
      if (!await webDirectory.exists()) {
        await webDirectory.create(recursive: true);
        await _copyAssets();
      }
      
      _initWebViewController();
    } catch (e) {
      print('Error setting up WebView: $e');
    }
  }

  Future<void> _copyAssets() async {
    try {
      // 复制HTML文件
      await _copyFileFromAssets('assets/web/index.html', '${webDirectory.path}/index.html');
      await _copyFileFromAssets('assets/web/login.html', '${webDirectory.path}/login.html');
      await _copyFileFromAssets('assets/web/dashboard.html', '${webDirectory.path}/dashboard.html');
      await _copyFileFromAssets('assets/web/dashboard_chat.html', '${webDirectory.path}/dashboard_chat.html');
      await _copyFileFromAssets('assets/web/profile.html', '${webDirectory.path}/profile.html');
      await _copyFileFromAssets('assets/web/verify.html', '${webDirectory.path}/verify.html');
      
      // 创建子目录
      final cssDir = Directory('${webDirectory.path}/css');
      final jsDir = Directory('${webDirectory.path}/js');
      final imgDir = Directory('${webDirectory.path}/img');
      final pagesDir = Directory('${webDirectory.path}/pages');
      
      await cssDir.create();
      await jsDir.create();
      await imgDir.create();
      await pagesDir.create();
      
      // 复制CSS文件
      final cssAssets = await _getAssetsList('assets/web/css');
      for (var file in cssAssets) {
        final fileName = file.split('/').last;
        await _copyFileFromAssets(file, '${cssDir.path}/$fileName');
      }
      
      // 复制JS文件
      final jsAssets = await _getAssetsList('assets/web/js');
      for (var file in jsAssets) {
        final fileName = file.split('/').last;
        await _copyFileFromAssets(file, '${jsDir.path}/$fileName');
      }
      
      // 复制图像文件
      final imgAssets = await _getAssetsList('assets/web/img');
      for (var file in imgAssets) {
        final fileName = file.split('/').last;
        await _copyFileFromAssets(file, '${imgDir.path}/$fileName');
      }
      
      // 复制pages文件
      final pagesAssets = await _getAssetsList('assets/web/pages');
      for (var file in pagesAssets) {
        final fileName = file.split('/').last;
        await _copyFileFromAssets(file, '${pagesDir.path}/$fileName');
      }
    } catch (e) {
      print('Error copying assets: $e');
    }
  }

  Future<List<String>> _getAssetsList(String path) async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = Map.from(
        Map.castFrom<String, dynamic, String, dynamic>(
          await json.decode(manifestContent),
        ),
      );
      
      return manifestMap.keys
          .where((String key) => key.startsWith(path))
          .toList();
    } catch (e) {
      print('Error getting assets list: $e');
      return [];
    }
  }

  Future<void> _copyFileFromAssets(String assetPath, String localPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final buffer = byteData.buffer;
      await File(localPath).writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
    } catch (e) {
      print('Error copying $assetPath: $e');
    }
  }

  void _initWebViewController() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100) {
              setState(() {
                isLoading = false;
              });
            }
          },
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            // 注入JavaScript以允许录音
            controller.runJavaScript('''
              // 配置麦克风访问
              navigator.mediaDevices.getUserMedia = navigator.mediaDevices.getUserMedia || 
                                                   navigator.webkitGetUserMedia || 
                                                   navigator.mozGetUserMedia || 
                                                   navigator.msGetUserMedia;
              
              // 通知Flutter应用录音权限已就绪
              if (window.VoiceprintApp && navigator.mediaDevices) {
                window.VoiceprintApp.postMessage('audioPermissionReady');
              }
              
              // 处理可能的错误
              window.onerror = function(message, source, lineno, colno, error) {
                console.log('捕获到错误:', message);
                if (window.VoiceprintApp) {
                  window.VoiceprintApp.postMessage('error:' + message);
                }
                return true;
              };
            ''');
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: ${error.description}');
            setState(() {
              isLoading = false;
              isOffline = true;
            });
          },
          onNavigationRequest: (NavigationRequest request) async {
            if (request.url.startsWith('http://') || request.url.startsWith('https://')) {
              // 处理外部链接
              final uri = Uri.parse(request.url);
              if (await canLaunchUrl(uri)) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
        ),
      );
      
    // 尝试直接加载HTML字符串
    _loadIndexHtmlContent();
      
    // 添加JavaScript通道以处理网页与Flutter之间的通信
    controller.addJavaScriptChannel(
      'VoiceprintApp',
      onMessageReceived: (JavaScriptMessage message) {
        _handleJsMessage(message.message);
      },
    );
  }
  
  // 直接加载HTML内容
  Future<void> _loadIndexHtmlContent() async {
    try {
      // 尝试从assets读取index.html
      String indexHtml = await rootBundle.loadString('assets/web/index.html');
      
      // 加载HTML字符串
      controller.loadHtmlString(indexHtml, baseUrl: 'file://${webDirectory.path}/');
    } catch (e) {
      print('加载HTML内容错误: $e');
      // 如果失败，尝试加载文件
      controller.loadFile('${webDirectory.path}/$initialPage');
    }
  }

  void _handleJsMessage(String message) {
    // 处理来自网页的消息
    print('Message from JavaScript: $message');
    
    // 可以在这里添加特定的消息处理逻辑
    if (message.startsWith('share:')) {
      // 实现分享功能
    } else if (message == 'requestMicrophonePermission') {
      _checkPermissions();
    } else if (message == 'audioPermissionReady') {
      // 应用已准备好进行音频录制
      print('音频录制权限已就绪');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('声纹通'),
        backgroundColor: Colors.blue[900],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              controller.reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // 实现分享功能
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'home') {
                controller.loadFile('${webDirectory.path}/$initialPage');
              } else if (value == 'about') {
                _showAboutDialog();
              } else if (value == 'settings') {
                _showSettingsDialog();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'home',
                child: Text('首页'),
              ),
              const PopupMenuItem<String>(
                value: 'about',
                child: Text('关于'),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Text('设置'),
              ),
            ],
          ),
        ],
      ),
      body: isOffline
          ? _buildOfflineScreen()
          : Stack(
              children: [
                WebViewWidget(controller: controller),
                if (isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
    );
  }

  Widget _buildOfflineScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.signal_wifi_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            '无法连接到网络',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('请检查您的网络连接后重试'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              await _checkConnectivity();
              if (!isOffline) {
                controller.reload();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[900],
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('关于声纹通'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('声纹通 v1.0.0'),
              SizedBox(height: 8),
              Text('一个专业的声纹识别解决方案，提供企业级身份验证服务。'),
              SizedBox(height: 16),
              Text('© 2025 声纹科技有限公司 版权所有'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('设置'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.mic),
                title: Text('麦克风权限'),
                subtitle: Text('用于声音录制'),
              ),
              ListTile(
                leading: Icon(Icons.storage),
                title: Text('存储权限'),
                subtitle: Text('用于存储声纹数据'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('打开设置'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
} 