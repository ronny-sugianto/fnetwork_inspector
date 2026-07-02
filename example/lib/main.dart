import 'package:dio/dio.dart';
import 'package:fnetwork_inspector/fnetwork_inspector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FNetworkInspector.initialize(
    enableInspection: kDebugMode,
    enableNotifications: false,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fnetwork_inspector example',
      builder: (BuildContext context, Widget? child) => FNetworkInspectorOverlay(
        enabled: kDebugMode,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'));
    _dio.interceptors.add(FNetworkInspector.dioInterceptor);
  }

  Future<void> _makeRequest() async {
    try {
      await _dio.get('/posts', queryParameters: <String, dynamic>{'userId': 1});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('fnetwork_inspector example')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ElevatedButton(
              onPressed: _makeRequest,
              child: const Text('Make request'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      const NetworkLogListScreen(),
                ),
              ),
              child: const Text('Open Inspector'),
            ),
          ],
        ),
      ),
    );
  }
}
