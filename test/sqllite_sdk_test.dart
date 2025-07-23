// import 'package:flutter/services.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:tenant_replication/tenant_replication.dart';

// void main() {
//   // Must be first
//   TestWidgetsFlutterBinding.ensureInitialized();

//   const MethodChannel channel = MethodChannel(
//     'plugins.it_nomads.com/flutter_secure_storage',
//   );

//   setUp(() {
//     // Mock the secure storage plugin methods
//     channel.setMockMethodCallHandler((MethodCall methodCall) async {
//       switch (methodCall.method) {
//         case 'read':
//           return '6556011';
//         case 'write':
//         case 'delete':
//         case 'deleteAll':
//           return null;
//         default:
//           return null;
//       }
//     });
//   });

//   tearDown(() {
//     channel.setMockMethodCallHandler(null);
//   });

//   test('testing code..........', () async {
//     await SSEManager.initializeSSE('http://192.168.0.87:3000');
//     expect(true, true);
//   });
// }
