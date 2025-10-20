import 'package:flutter_test/flutter_test.dart';

import 'package:crystal_grimoire_fresh/services/monitoring_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MonitoringService', () {
    test('initialise and log gracefully without Firebase', () async {
      final service = MonitoringService.instance;

      // Should complete even when Firebase is not configured in test environment.
      await service.initialize();
      await expectLater(service.logEvent('test_event'), completes);

      // Logging callable invocations should not throw.
      await service.logFunctionInvocation(
        'testCallable',
        success: true,
        duration: const Duration(milliseconds: 12),
      );

      // Error recording should be resilient.
      expect(
        () => service.recordError(Exception('boom'), StackTrace.current),
        returnsNormally,
      );
    });
  });
}
