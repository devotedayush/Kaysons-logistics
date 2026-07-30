import 'package:flutter_test/flutter_test.dart';

import 'package:kaysons_logistics/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildAppTheme keeps the app palette stable', () {
    final theme = buildAppTheme();

    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.error, AppColors.danger);
    expect(theme.scaffoldBackgroundColor, AppColors.onPrimary);
  });
}
