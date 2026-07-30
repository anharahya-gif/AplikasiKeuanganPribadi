import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aplikasi_keuangan_pribadi/main.dart';
import 'package:aplikasi_keuangan_pribadi/providers/finance_provider.dart';
import 'package:aplikasi_keuangan_pribadi/providers/security_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:convert';

// Fake provider to bypass SQLite and path_provider calls in tests
class FakeFinanceProvider extends FinanceProvider {
  FakeFinanceProvider() : super();

  @override
  Future<void> refreshData() async {
    // No-op to bypass DB calls in unit test environment
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
    
    // Disable Google Fonts HTTP fetching in tests
    GoogleFonts.config.allowRuntimeFetching = false;

    // Mock flutter/assets channel to return mock bytes for font files or empty manifests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      if (message == null) return null;
      
      // Decode the asset key from the byte message using proper offset and length
      final String key = utf8.decode(
        message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes),
      );
      
      if (key.endsWith('.ttf') || key.contains('google_fonts')) {
        // Return dummy bytes for font files
        return ByteData.sublistView(Uint8List.fromList(List<int>.filled(100, 0)));
      }
      
      if (key.startsWith('AssetManifest')) {
        // Return a mock manifest containing the font files to make google_fonts think they are bundled assets
        final manifestMap = <String, List<String>>{
          'google_fonts/PlusJakartaSans-ExtraBold.ttf': ['google_fonts/PlusJakartaSans-ExtraBold.ttf'],
          'google_fonts/PlusJakartaSans-Bold.ttf': ['google_fonts/PlusJakartaSans-Bold.ttf'],
          'google_fonts/PlusJakartaSans-SemiBold.ttf': ['google_fonts/PlusJakartaSans-SemiBold.ttf'],
          'google_fonts/PlusJakartaSans-Regular.ttf': ['google_fonts/PlusJakartaSans-Regular.ttf'],
        };
        return const StandardMessageCodec().encodeMessage(manifestMap);
      }
      
      return null; // Return file not found for other assets
    });

    // Mock path_provider channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );

    // Mock shared_preferences channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return null;
      },
    );

    // Mock sqflite channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.tekartik.sqflite'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getDatabasesPath') {
          return '.';
        }
        if (methodCall.method == 'openDatabase') {
          return 1;
        }
        return null;
      },
    );

    // Mock font_loader channel to bypass engine-level TTF parsing errors
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter/font_loader'),
      (MethodCall methodCall) async {
        return null; // Force success
      },
    );
  });

  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    final securityProvider = SecurityProvider();
    
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FinanceProvider>(create: (_) => FakeFinanceProvider()),
          ChangeNotifierProvider.value(value: securityProvider),
        ],
        child: const MyApp(),
      ),
    );

    // Verify that the app is initialized successfully
    expect(find.byType(MyApp), findsOneWidget);
  });
}
