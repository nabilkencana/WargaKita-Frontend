import 'package:flutter/material.dart';
import 'package:warga_app/screens/register_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final String? prefilledEmail;

  const LoginScreen({super.key, this.prefilledEmail});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isEmailValid = false;
  bool _showEmailHint = true;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _headerScaleAnimation;

  static const _primaryColor = Color(0xFF0D6EFD);
  static const _animationDuration = Duration(milliseconds: 1200);
  static const _transitionDuration = Duration(milliseconds: 600);
  static const _inputBorderRadius = BorderRadius.all(Radius.circular(16));
  static const _containerBorderRadius = BorderRadius.all(Radius.circular(28));
  static const _buttonBorderRadius = BorderRadius.all(Radius.circular(16));

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupEmailListener();
    _prefillEmail();
  }

  void _prefillEmail() {
    if (widget.prefilledEmail != null && widget.prefilledEmail!.isNotEmpty) {
      _emailController.text = widget.prefilledEmail!;
      final email = _emailController.text.trim();
      final isValid = _validateEmailFormat(email);

      setState(() {
        _isEmailValid = isValid;
        _showEmailHint = email.isEmpty;
      });

      print('📧 Email prefilled from register: ${widget.prefilledEmail}');
    }
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: _animationDuration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    _headerScaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();
  }

  void _setupEmailListener() {
    _emailController.addListener(() {
      final email = _emailController.text.trim();
      final isValid = _validateEmailFormat(email);

      setState(() {
        _isEmailValid = isValid;
        _showEmailHint = email.isEmpty;
      });
    });
  }

  bool _validateEmailFormat(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(r'^[\w\.-]+@gmail\.com$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('Email tidak boleh kosong');
      return;
    }

    if (!_isEmailValid) {
      _showError('Format email harus @gmail.com');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await _authService.sendOtp(email);
      _showSuccess('Kode OTP telah dikirim ke $email');

      await Future.delayed(const Duration(milliseconds: 800));

      Navigator.pushNamed(
        context,
        '/verify-otp',
        arguments: {'email': email, 'onResendOtp': () => _resendOtp(email)},
      );
    } catch (e) {
      if (e.toString().contains('Email tidak ditemukan')) {
        _showEmailNotRegisteredDialog(email);
      } else {
        _showError(
          'Gagal mengirim OTP: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOtp(String email) async {
    try {
      await _authService.resendOtp(email);
      _showSuccess('OTP berhasil dikirim ulang');
    } catch (e) {
      _showError(
        'Gagal mengirim ulang OTP: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  void _showEmailNotRegisteredDialog(String email) {
    showDialog(
      context: context,
      builder: (BuildContext context) => _buildRegisterDialog(email),
    );
  }

  Widget _buildRegisterDialog(String email) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt_1,
                color: Colors.blue,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Email Belum Terdaftar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'Email '),
                  TextSpan(
                    text: email,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const TextSpan(
                    text: ' belum terdaftar. Yuk daftar sekarang!',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _buildOutlinedButton(
                    text: 'Ganti Email',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildElevatedButton(
                    text: 'Daftar',
                    onPressed: () {
                      Navigator.of(context).pop();
                      _navigateToRegisterWithEmail(email);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildElevatedButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Di LoginScreen (_buildRegisterDialog bagian)
  void _navigateToRegisterWithEmail(String email) {
    Navigator.push(
      // Ubah dari pushReplacement menjadi push
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RegisterScreen(prefilledEmail: email),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            _createSlideTransition(animation, child),
        transitionDuration: _transitionDuration,
      ),
    );
  }

  Widget _createSlideTransition(Animation<double> animation, Widget child) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeInOutCubic;

    final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

    return SlideTransition(position: animation.drive(tween), child: child);
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 6,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Tutup',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 6,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildEmailInput() {
    final isPrefilled =
        widget.prefilledEmail != null && widget.prefilledEmail!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Alamat Email',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                letterSpacing: 0.3,
              ),
            ),
            if (isPrefilled) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D6EFD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Dari pendaftaran',
                  style: TextStyle(
                    color: const Color(0xFF0D6EFD),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: _inputBorderRadius,
            border: Border.all(
              color: _emailFocusNode.hasFocus
                  ? _primaryColor.withOpacity(0)
                  : (isPrefilled
                        ? const Color(0xFF0D6EFD).withOpacity(0.5)
                        : (_isEmailValid && _emailController.text.isNotEmpty
                              ? Colors.green.shade400
                              : Colors.white)),
              width: _emailFocusNode.hasFocus || isPrefilled ? 2.5 : 1.5,
            ),
            boxShadow: _emailFocusNode.hasFocus
                ? [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.15),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : (isPrefilled
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0D6EFD).withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : []),
          ),
          child: TextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            decoration: InputDecoration(
              hintText: 'nama@gmail.com',
              hintStyle: TextStyle(
                color: isPrefilled
                    ? const Color(0xFF0D6EFD).withOpacity(0.6)
                    : Colors.grey.shade500,
                fontSize: 15,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.normal,
              ),
              border: InputBorder.none,
              constraints: const BoxConstraints(minHeight: 51),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 23,
                vertical: 18,
              ),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: _emailFocusNode.hasFocus || isPrefilled
                    ? _primaryColor
                    : Colors.grey.shade500,
                size: 22,
              ),
              suffixIcon: _emailController.text.isNotEmpty
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isEmailValid
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: isPrefilled
                                  ? const Color(0xFF0D6EFD)
                                  : Colors.green,
                              size: 24,
                            )
                          : Icon(
                              Icons.error_outline_rounded,
                              color: Colors.orange,
                              size: 24,
                            ),
                    )
                  : null,
              fillColor: isPrefilled
                  ? const Color(0xFF0D6EFD).withOpacity(0.05)
                  : Colors.white,
              filled: true,
            ),
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isPrefilled
                  ? const Color(0xFF0D6EFD)
                  : Colors.grey.shade800,
              fontFamily: 'Roboto',
            ),
            onSubmitted: (_) => _sendOtp(),
          ),
        ),
        if (_showEmailHint)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              isPrefilled
                  ? 'Email sudah diisi dari proses pendaftaran. Lanjutkan login.'
                  : 'Gunakan email dengan format @gmail.com',
              style: TextStyle(
                color: isPrefilled
                    ? const Color(0xFF0D6EFD).withOpacity(0.8)
                    : Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: _buttonBorderRadius,
        boxShadow: _isLoading || !_isEmailValid
            ? []
            : [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: (_isLoading || !_isEmailValid) ? null : _sendOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isEmailValid ? _primaryColor : Colors.grey.shade400,
          shape: RoundedRectangleBorder(borderRadius: _buttonBorderRadius),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Masuk',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRememberMeCheckbox() {
    return Row(
      children: [
        Transform.scale(
          scale: 1.2,
          child: Checkbox(
            activeColor: _primaryColor,
            value: _rememberMe,
            onChanged: (value) {
              setState(() {
                _rememberMe = value ?? false;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Ingat perangkat ini',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterSection() {
    return Center(
      child: Column(
        children: [
          Text(
            'Belum punya akun?',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      RegisterScreen(prefilledEmail: _emailController.text),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          _createSlideTransition(animation, child),
                  transitionDuration: _transitionDuration,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100, width: 1.5),
              ),
              child: Text(
                'Daftar Sekarang',
                style: TextStyle(
                  fontSize: 15,
                  color: _primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 320,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, const Color(0xFF1E88E5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
        ),
        Positioned.fill(
          child: ScaleTransition(
            scale: _headerScaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        Colors.white.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 25,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/Vector.png',
                    width: 70,
                    height: 70,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Selamat Datang Di WargaKita',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Masuk dengan email @gmail.com untuk melanjutkan',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _containerBorderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.blueGrey.withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 5,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEmailInput(),
                const SizedBox(height: 20),
                _buildRememberMeCheckbox(),
                const SizedBox(height: 28),
                _buildLoginButton(),
                const SizedBox(height: 24),
                _buildRegisterSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildFormSection()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }
}