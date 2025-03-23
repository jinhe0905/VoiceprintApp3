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
      }
      
      // 确保在初始化控制器前复制所有资源
      await _copyAssets();
      _initWebViewController();
    } catch (e) {
      print('Error setting up WebView: $e');
      setState(() {
        isLoading = false;
        isOffline = false; // 不要将设置错误视为离线问题
      });
    }
  }

  Future<void> _copyAssets() async {
    try {
      // 确保目录存在
      if (!await webDirectory.exists()) {
        await webDirectory.create(recursive: true);
      }
      
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
      
      if (!await cssDir.exists()) await cssDir.create();
      if (!await jsDir.exists()) await jsDir.create();
      if (!await imgDir.exists()) await imgDir.create();
      if (!await pagesDir.exists()) await pagesDir.create();
      
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
      
      print('资源文件复制完成，目标目录: ${webDirectory.path}');
    } catch (e) {
      print('Error copying assets: $e');
      // 即使资源复制失败，也尝试继续运行
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
              // 页面开始加载时，不认为是离线状态
              isOffline = false;
            });
            print('WebView开始加载页面: $url');
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            print('WebView页面加载完成: $url');
            
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
            ''').catchError((error) {
              print('注入JavaScript时出错: $error');
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: ${error.description}, 错误代码: ${error.errorCode}, URL: ${error.url}');
            
            // 只有当错误类型与网络相关时才显示离线状态
            bool isNetworkError = error.errorCode == -2 || // 网络错误
                                 error.errorCode == -8 || // 连接超时 
                                 error.errorCode == -7;   // 连接被拒绝
                                 
            if (isNetworkError) {
              setState(() {
                isLoading = false;
                isOffline = true;
              });
            } else {
              // 对于其他类型的错误，不显示离线状态
              setState(() {
                isLoading = false;
              });
              
              // 尝试加载备用资源
              _tryLoadBackupResource();
            }
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
      
    // 添加JavaScript通道以处理网页与Flutter之间的通信
    controller.addJavaScriptChannel(
      'VoiceprintApp',
      onMessageReceived: (JavaScriptMessage message) {
        _handleJsMessage(message.message);
      },
    );
    
    // 加载HTML内容 - 使用多种方式尝试加载
    _loadContent();
  }
  
  // 尝试加载备用资源
  void _tryLoadBackupResource() {
    try {
      // 尝试直接加载文件
      final filePath = '${webDirectory.path}/$initialPage';
      print('尝试加载备用资源: $filePath');
      controller.loadFile(filePath);
    } catch (e) {
      print('加载备用资源失败: $e');
    }
  }
  
  // 使用多种方式尝试加载内容
  Future<void> _loadContent() async {
    try {
      // 方法1: 尝试从assets读取HTML并直接加载字符串
      try {
        final htmlContent = await rootBundle.loadString('assets/web/index.html');
        print('HTML字符串加载成功，长度: ${htmlContent.length}');
        await controller.loadHtmlString(htmlContent, baseUrl: 'file://${webDirectory.path}/');
        return;
      } catch (e) {
        print('HTML字符串加载失败: $e，尝试其他方法');
      }
      
      // 方法2: 尝试加载本地文件
      try {
        final filePath = '${webDirectory.path}/$initialPage';
        final file = File(filePath);
        if (await file.exists()) {
          print('加载本地文件: $filePath');
          await controller.loadFile(filePath);
          return;
        } else {
          print('本地文件不存在: $filePath');
        }
      } catch (e) {
        print('加载本地文件失败: $e，尝试其他方法');
      }
      
      // 方法3: 加载简单的静态HTML显示错误信息
      print('尝试加载静态HTML内容');
      final staticHtml = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>声纹通</title>
        <style>
          body { font-family: 'Arial', sans-serif; text-align: center; padding: 20px; }
          .container { max-width: 500px; margin: 0 auto; }
          h1 { color: #0D47A1; }
          .btn { background-color: #0D47A1; color: white; border: none; padding: 10px 20px; 
                border-radius: 5px; font-size: 16px; cursor: pointer; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>声纹通</h1>
          <p>欢迎使用声纹识别系统</p>
          <button class="btn" onclick="location.reload()">刷新页面</button>
        </div>
      </body>
      </html>
      ''';
      await controller.loadHtmlString(staticHtml);
      
    } catch (e) {
      print('所有加载方法都失败: $e');
      setState(() {
        isLoading = false;
      });
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