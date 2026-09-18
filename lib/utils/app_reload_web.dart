import 'dart:js_interop';

@JS('reloadLatestPayrollApp')
external JSPromise<JSAny?> _reloadLatestPayrollApp();

Future<void> reloadLatestApp() async {
  await _reloadLatestPayrollApp().toDart;
}
