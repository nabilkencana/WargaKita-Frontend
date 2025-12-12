import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String email;
  final Future<void> Function() onResendOtp;

  const VerifyOtpScreen({
    super.key,
    required this.email,
    required this.onResendOtp,
  });

  @override
  _VerifyOtpScreenState createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isResending = false;
  int _countdown = 60;
  late Timer _timer;
  String? _lastOtpError;

  @override
  void initState() {
    super.initState();
    print('🔄 VerifyOtpScreen initialized for email: ${widget.email}');
    _startTimer();
    _setupOtpFields();
    _showInitialSuccess();
    // Auto focus ke field pertama
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _showInitialSuccess() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Kode OTP telah dikirim ke ${widget.email}',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
        ),
      );
    });
  }

  void _setupOtpFields() {
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (!_focusNodes[i].hasFocus && _otpControllers[i].text.isEmpty) {
          if (i > 0) _focusNodes[i - 1].requestFocus();
        }
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String _getOtpCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _handleOtpChange(String value, int index) {
    // Hanya terima angka
    if (value.isNotEmpty && !RegExp(r'^[0-9]$').hasMatch(value)) {
      _otpControllers[index].clear();
      return;
    }

    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Clear error ketika user mulai mengetik lagi
    if (_lastOtpError != null) {
      setState(() {
        _lastOtpError = null;
      });
    }

    // Auto verify ketika semua field terisi
    if (_getOtpCode().length == 6) {
      _verifyOtp();
    }
  }

  void _handleKeyEvent(RawKeyEvent event, int index) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_otpControllers[index].text.isEmpty && index > 0) {
          _focusNodes[index - 1].requestFocus();
          _otpControllers[index - 1].clear();
        }
      }
    }
  }

  // Fungsi untuk handle paste OTP
  Future<void> _handlePaste(BuildContext context, int currentIndex) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      String pastedText = clipboardData!.text!.trim();

      // Hanya ambil angka dari text yang di-paste
      pastedText = pastedText.replaceAll(RegExp(r'[^0-9]'), '');

      print('📋 Pasted text: $pastedText');

      if (pastedText.isEmpty) {
        // Jika tidak ada angka yang valid
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak ada kode OTP yang valid untuk ditempel'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Hanya ambil maksimal 6 karakter pertama
      if (pastedText.length > 6) {
        pastedText = pastedText.substring(0, 6);
      }

      // Isi field OTP sesuai dengan text yang di-paste
      for (int i = 0; i < pastedText.length; i++) {
        final char = pastedText[i];
        final targetIndex = currentIndex + i;

        if (targetIndex < 6 && RegExp(r'^[0-9]$').hasMatch(char)) {
          _otpControllers[targetIndex].text = char;
          if (targetIndex < 5) {
            _focusNodes[targetIndex + 1].requestFocus();
          }
        }
      }

      // Auto verify jika sudah 6 digit
      if (_getOtpCode().length == 6) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _verifyOtp();
        });
      }

      // Clear error jika ada
      if (_lastOtpError != null) {
        setState(() {
          _lastOtpError = null;
        });
      }

      // Tampilkan feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP berhasil ditempel'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // screens/verify_otp_screen.dart - UPDATE bagian _verifyOtp
  Future<void> _verifyOtp() async {
    final otpCode = _getOtpCode();

    print('🔢 OTP entered: $otpCode');
    print('📧 Email: ${widget.email}');

    if (otpCode.length != 6) {
      _showError('Harap masukkan 6 digit kode OTP');
      return;
    }

    // Unfocus keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _lastOtpError = null;
    });

    try {
      print('🚀 Memulai verifikasi OTP dengan server...');

      final authResponse = await _authService.verifyOtp(widget.email, otpCode);

      print('✅ Verifikasi OTP berhasil di server');
      print('👤 User: ${authResponse.user?.email}');
      print(
        '🔑 Token: ${authResponse.accessToken != null ? "Received ✓" : "Not received ✗"}',
      );

      // ✅ VERIFIKASI TOKEN DISIMPAN
      final savedToken = await AuthService.getToken();
      print(
        '💾 Token saved in storage: ${savedToken != null ? "Yes ✓" : "No ✗"}',
      );

      if (savedToken != null) {
        print('🔐 Token length: ${savedToken.length}');
        print(
          '🔐 Token preview: ${savedToken.substring(0, min(30, savedToken.length))}...',
        );
      }

      _showSuccess('Verifikasi berhasil! Mengarahkan ke Home Screen...');

      // ✅ TUNGGU SEBENTAR UNTUK MEMASTIKAN DATA DISIMPAN
      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        if (authResponse.user != null) {
          Navigator.pushAndRemoveUntil(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  HomeScreen(user: authResponse.user!),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOutCubic;
                    var tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
              transitionDuration: const Duration(milliseconds: 600),
            ),
            (route) => false,
          );
        } else {
          _showError('Data user tidak ditemukan setelah login');
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('❌ OTP verification error: $e');
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _lastOtpError = errorMessage;
      });
      _showError(errorMessage);

      // ✅ HAPUS TOKEN JIKA VERIFIKASI GAGAL
      if (errorMessage.contains('invalid') ||
          errorMessage.contains('expired')) {
        await AuthService.logout();
      }

      _clearOtpFields();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isResending = true);

    try {
      print('🔄 Mengirim ulang OTP ke: ${widget.email}');

      await widget.onResendOtp();

      _showSuccess('Kode OTP baru telah dikirim ke ${widget.email}');

      setState(() {
        _countdown = 60;
        _lastOtpError = null;
      });
      _startTimer();
      _clearOtpFields();

      // Auto focus kembali ke field pertama
      _focusNodes[0].requestFocus();
    } catch (e) {
      final errorMessage = e.toString().replaceFirst('Exception: ', '');
      _showError('Gagal mengirim ulang OTP: $errorMessage');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _clearOtpFields() {
    for (final controller in _otpControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() {
      _lastOtpError = null;
    });
    print('🧹 OTP fields cleared');
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 6,
        action: SnackBarAction(
          label: 'Tutup',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
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
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 6,
      ),
    );
  }

  void _goBack() {
    print('🔙 Going back to login screen');
    Navigator.pop(context);
  }

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _timer.cancel();
    print('🧹 VerifyOtpScreen disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.black87,
              size: 18,
            ),
          ),
          onPressed: _goBack,
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Verifikasi OTP',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Header Section
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.blue.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade200.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: Colors.blue.shade700,
                        size: 45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Verifikasi Kode OTP',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Masukkan 6 digit kode yang dikirim ke',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        widget.email,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // OTP Input Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kode OTP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      // Paste button
                      TextButton.icon(
                        onPressed: () => _handlePaste(context, 0),
                        icon: Icon(
                          Icons.paste_rounded,
                          color: Colors.blue.shade600,
                          size: 16,
                        ),
                        label: Text(
                          'Paste OTP',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Error message jika ada
                  if (_lastOtpError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: Colors.red.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _lastOtpError!,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // OTP Input Fields
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        final hasError = _lastOtpError != null;
                        final isFocused = _focusNodes[index].hasFocus;

                        return Container(
                          width: 52,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              if (isFocused)
                                BoxShadow(
                                  color: Colors.blue.shade200.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: RawKeyboardListener(
                            focusNode: FocusNode(),
                            onKey: (event) => _handleKeyEvent(event, index),
                            child: GestureDetector(
                              onLongPress: () async {
                                // Enable long press untuk paste
                                await _handlePaste(context, index);
                              },
                              child: TextFormField(
                                controller: _otpControllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  counterText: '',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: hasError
                                          ? Colors.red
                                          : Colors.blue,
                                      width: 2.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: hasError
                                          ? Colors.red.shade300
                                          : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: hasError
                                      ? Colors.red.shade50
                                      : (isFocused
                                            ? Colors.blue.shade50
                                            : Colors.white),
                                  contentPadding: EdgeInsets.zero,
                                  hintText: '0',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: hasError
                                      ? Colors.red.shade800
                                      : Colors.black87,
                                  letterSpacing: 1.2,
                                ),
                                onChanged: (value) =>
                                    _handleOtpChange(value, index),
                                textInputAction: index == 5
                                    ? TextInputAction.done
                                    : TextInputAction.next,
                                // Enable paste menu
                                enableInteractiveSelection: true,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Info Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tips:',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Kode OTP akan kadaluarsa dalam $_countdown detik\n• Periksa folder spam jika tidak menemukan email\n• Kode akan terverifikasi otomatis ketika 6 digit terisi\n• Anda bisa paste OTP menggunakan tombol Paste OTP di atas',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Timer & Resend Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _countdown < 10
                      ? Colors.orange.shade50
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _countdown < 10
                        ? Colors.orange.shade200
                        : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: _countdown < 10
                              ? Colors.orange.shade600
                              : Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Kode kadaluarsa dalam',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$_countdown detik',
                      style: TextStyle(
                        color: _countdown < 10
                            ? Colors.orange.shade700
                            : Colors.green.shade600,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Resend OTP Button
              Center(
                child: _isResending
                    ? Column(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Mengirim ulang...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _countdown == 0 ? _resendOtp : null,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: _countdown == 0
                                  ? Colors.blue.shade400
                                  : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                color: _countdown == 0
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade400,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Kirim Ulang Kode OTP',
                                style: TextStyle(
                                  color: _countdown == 0
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade400,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Column(
                children: [
                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D6EFD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                        shadowColor: Colors.blue.shade300,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Verifikasi Sekarang',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Clear Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _clearOtpFields,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: Colors.grey.shade400,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cleaning_services_rounded,
                            color: Colors.grey.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Hapus Semua Kode',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
