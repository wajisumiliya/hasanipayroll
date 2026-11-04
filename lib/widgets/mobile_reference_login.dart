import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The approved artwork is a static, unauthenticated decorative layer. All
/// editable fields and actions above it are real Flutter controls. Artwork
/// coordinates are kept in their original 863px space, with no stretching.
class MobileReferenceLogin extends StatefulWidget {
  const MobileReferenceLogin({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.onTogglePassword,
    required this.onSignIn,
    required this.onForgotPassword,
    this.errorMessage,
  });
  final TextEditingController usernameController, passwordController;
  final bool obscurePassword, loading;
  final VoidCallback onTogglePassword, onSignIn, onForgotPassword;
  final String? errorMessage;

  @override
  State<MobileReferenceLogin> createState() => _MobileReferenceLoginState();
}

class _MobileReferenceLoginState extends State<MobileReferenceLogin> {
  static const _rememberKey = 'mobile_login_remember_identifier';
  static const _identifierKey = 'mobile_login_identifier';
  bool _remember = true;
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _restoreIdentifier();
  }

  Future<void> _restoreIdentifier() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _remember = preferences.getBool(_rememberKey) ?? true);
    if (_remember && widget.usernameController.text.isEmpty) {
      widget.usernameController.text =
          preferences.getString(_identifierKey) ?? '';
    }
  }

  Future<void> _setRemember(bool value) async {
    setState(() => _remember = value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberKey, value);
    if (!value) await preferences.remove(_identifierKey);
  }

  Future<void> _signIn() async {
    if (widget.loading) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (_remember) {
        await preferences.setString(
            _identifierKey, widget.usernameController.text.trim());
      } else {
        await preferences.remove(_identifierKey);
      }
    } catch (_) {
      // An optional remembered identifier must never block authentication.
    }
    if (mounted) widget.onSignIn();
  }

  // The pictured OS status/navigation bars are excluded. SafeArea supplies the
  // device's real bars instead of displaying a fake time or battery level.
  Widget _at(double x, double y, double width, double height, Widget child) =>
      Positioned(
          left: x, top: y - 64, width: width, height: height, child: child);

  Widget _field(
          {required TextEditingController controller,
          required String label,
          bool password = false}) =>
      Semantics(
        label: label,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => DecoratedBox(
            // Only hide the printed placeholder once the user has typed.
            decoration: BoxDecoration(
                gradient: value.text.isEmpty
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF192543), Color(0xFF17223F)])),
            child: TextField(
              key: ValueKey(password
                  ? 'mobile-login-password'
                  : 'mobile-login-identifier'),
              controller: controller,
              focusNode: password ? _passwordFocus : _usernameFocus,
              enabled: !widget.loading,
              obscureText: password && widget.obscurePassword,
              autocorrect: false,
              enableSuggestions: !password,
              keyboardType:
                  password ? TextInputType.visiblePassword : TextInputType.text,
              textInputAction:
                  password ? TextInputAction.done : TextInputAction.next,
              autofillHints: [
                password ? AutofillHints.password : AutofillHints.username
              ],
              onSubmitted: password
                  ? (_) => _signIn()
                  : (_) => FocusScope.of(context).nextFocus(),
              cursorColor: const Color(0xFFB7C7E5),
              style: const TextStyle(
                  fontSize: 28, height: 1.2, color: Colors.white),
              scrollPadding: const EdgeInsets.all(60),
              decoration: const InputDecoration(
                // Keep the dark artwork/typed-value gradient visible instead
                // of inheriting the application's white input fill.
                filled: false,
                fillColor: Colors.transparent,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ),
      );

  Widget _hit(String label, VoidCallback? onTap, {Widget? child}) => Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: Material(
          color: Colors.transparent,
          child: InkWell(
              onTap: onTap,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: child)));

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: const Color(0xFF02091F),
            systemNavigationBarColor: const Color(0xFF02091F)),
        child: Scaffold(
          backgroundColor: const Color(0xFF02091F),
          body: SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(children: [
                  SizedBox(
                    width: width,
                    height: width * 1698 / 863,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 863,
                        height: 1698,
                        child: AutofillGroup(
                            child:
                                Stack(clipBehavior: Clip.hardEdge, children: [
                          Positioned(
                              left: 0,
                              top: -64,
                              width: 863,
                              height: 1822,
                              child: ExcludeSemantics(
                                  child: Image.asset(
                                      'assets/mobile_login_reference.png',
                                      fit: BoxFit.fill,
                                      filterQuality: FilterQuality.high))),
                          _at(
                              200,
                              90,
                              470,
                              100,
                              Semantics(
                                  label: 'Hasani Payroll',
                                  child: SizedBox.expand())),
                          _at(
                              75,
                              780,
                              710,
                              230,
                              Semantics(
                                  label:
                                      'Welcome to Hasani Payroll. A smarter, faster, and more secure payroll experience for your organization.',
                                  child: SizedBox.expand())),
                          _at(
                              75,
                              1042,
                              713,
                              88,
                              GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  excludeFromSemantics: true,
                                  onTap: widget.loading
                                      ? null
                                      : () => _usernameFocus.requestFocus())),
                          _at(
                              75,
                              1160,
                              713,
                              88,
                              GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  excludeFromSemantics: true,
                                  onTap: widget.loading
                                      ? null
                                      : () => _passwordFocus.requestFocus())),
                          _at(
                              172,
                              1058,
                              535,
                              61,
                              _field(
                                  controller: widget.usernameController,
                                  label: 'Email or Employee ID')),
                          _at(
                              172,
                              1178,
                              535,
                              61,
                              _field(
                                  controller: widget.passwordController,
                                  label: 'Password',
                                  password: true)),
                          _at(
                              700,
                              1162,
                              86,
                              84,
                              _hit(
                                  widget.obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  widget.loading
                                      ? null
                                      : widget.onTogglePassword,
                                  child: widget.obscurePassword
                                      ? null
                                      : Center(
                                          child: Container(
                                              color: const Color(0xFF18223F),
                                              width: 64,
                                              height: 56,
                                              child: const Icon(
                                                  Icons.visibility_outlined,
                                                  size: 40,
                                                  color: Color(0xFFB5C0DC)))))),
                          _at(
                              75,
                              1260,
                              310,
                              98,
                              Semantics(
                                  label: 'Remember me',
                                  checked: _remember,
                                  child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: widget.loading
                                          ? null
                                          : () => _setRemember(!_remember),
                                      child: Align(
                                          alignment: const Alignment(-1, -.05),
                                          child: Container(
                                              width: 45,
                                              height: 45,
                                              decoration: BoxDecoration(
                                                  color: _remember
                                                      ? const Color(0xFF007AFF)
                                                      : const Color(0xFF06122E),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: _remember
                                                      ? null
                                                      : Border.all(
                                                          color: const Color(
                                                              0xFFB5C0DC),
                                                          width: 2)),
                                              child: _remember
                                                  ? const Icon(Icons.check,
                                                      color: Colors.white,
                                                      size: 38)
                                                  : null))))),
                          _at(
                              551,
                              1260,
                              240,
                              98,
                              _hit(
                                  'Forgot password?',
                                  widget.loading
                                      ? null
                                      : widget.onForgotPassword)),
                          _at(
                              75,
                              1373,
                              713,
                              110,
                              _hit('Sign In', widget.loading ? null : _signIn,
                                  child: widget.loading
                                      ? Container(
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(55),
                                              gradient: const LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Color(0xFFFF1945),
                                                    Color(0xFFB90020)
                                                  ])),
                                          child: const Center(
                                              child: SizedBox(
                                                  width: 46,
                                                  height: 46,
                                                  child:
                                                      CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 4))))
                                      : null)),
                          _at(
                              130,
                              1538,
                              650,
                              100,
                              Semantics(
                                  label:
                                      'Secure Login. Your data is protected with enterprise-grade encryption and security controls.',
                                  child: SizedBox.expand())),
                        ])),
                      ),
                    ),
                  ),
                  if (widget.errorMessage != null)
                    Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(widget.errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Color(0xFFFFAEBF), fontSize: 14)))),
                ]),
              );
            }),
          ),
        ),
      );
}
