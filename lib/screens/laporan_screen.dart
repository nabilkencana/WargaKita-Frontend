// laporan_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:warga_app/screens/riwayat_laporan_screen.dart';
import 'package:warga_app/services/auth_service.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import '../models/user_model.dart';
import 'package:http/http.dart' as http;

class LaporanScreen extends StatefulWidget {
  final User user;

  const LaporanScreen({super.key, required this.user});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedKategori = 'Infrastruktur';
  bool _isLoading = false;
  File? _imageFile;
  Uint8List? _imageBytes;
  double _uploadProgress = 0.0;

  final List<String> _kategoriList = [
    'Infrastruktur',
    'Kebersihan',
    'Keamanan',
    'Lingkungan',
    'Lainnya',
  ];

  List<Color> get _kategoriColors => [
    Colors.blue.shade50,
    Colors.green.shade50,
    Colors.orange.shade50,
    Colors.teal.shade50,
    Colors.purple.shade50,
  ];

  List<Color> get _kategoriBorderColors => [
    Colors.blue.shade200,
    Colors.green.shade200,
    Colors.orange.shade200,
    Colors.teal.shade200,
    Colors.purple.shade200,
  ];

  @override
  Widget build(BuildContext context) {
    final hasImage = kIsWeb ? _imageBytes != null : _imageFile != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Header hijau full lebar
            _buildAppBar(),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Card Container untuk form
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title Section
                            _buildSectionTitle(
                              icon: Icons.description_outlined,
                              title: 'Informasi Laporan',
                              subtitle: 'Isi detail laporan Anda',
                            ),

                            const SizedBox(height: 24),

                            // Kategori dengan chips yang lebih menarik
                            _buildKategoriSection(),
                            const SizedBox(height: 24),

                            // Judul
                            _buildTextField(
                              controller: _judulController,
                              label: 'Judul Laporan',
                              hintText: 'Contoh: Jalan Rusak di RT 05',
                              icon: Icons.title,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 20),

                            // Deskripsi
                            _buildTextField(
                              controller: _deskripsiController,
                              label: 'Deskripsi Lengkap',
                              hintText:
                                  'Jelaskan masalah atau saran secara detail...\n\nContoh: Terdapat lubang besar di jalan utama RT 05 yang membahayakan pengendara, terutama pada malam hari.',
                              icon: Icons.description,
                              maxLines: 5,
                            ),
                            const SizedBox(height: 24),

                            // Upload Foto dengan kompatibilitas web
                            _buildPhotoUploadSection(hasImage: hasImage),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Progress indicator untuk upload
                      if (_uploadProgress > 0.0 && _uploadProgress < 1.0)
                        _buildUploadProgress(),

                      const SizedBox(height: 16),

                      // Submit Button dengan animasi
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade800.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buat Laporan',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sampaikan keluhan atau saran Anda untuk perbaikan',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              // Tombol Riwayat
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RiwayatLaporanScreen(user: widget.user),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.history_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                tooltip: 'Lihat Riwayat Laporan',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.green.shade700, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKategoriSection() {
    final kategoriColors = _kategoriColors;
    final kategoriBorderColors = _kategoriBorderColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori Laporan',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_kategoriList.length, (index) {
            final kategori = _kategoriList[index];
            final isSelected = _selectedKategori == kategori;

            final color = index < kategoriColors.length
                ? kategoriColors[index]
                : Colors.grey.shade50;

            final borderColor = index < kategoriBorderColors.length
                ? kategoriBorderColors[index]
                : Colors.grey.shade300;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedKategori = kategori;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.grey.shade50,
                  border: Border.all(
                    color: isSelected ? borderColor : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: borderColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getKategoriIcon(kategori),
                      size: 16,
                      color: isSelected ? borderColor : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      kategori,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.black87
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required int maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
            prefixIcon: Icon(icon, color: Colors.green.shade600, size: 20),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Field ini harus diisi';
            }
            if (value.length < 10) {
              return 'Minimal 10 karakter';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhotoUploadSection({required bool hasImage}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto Pendukung (Opsional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImageFromGallery,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: hasImage ? 200 : 120,
            decoration: BoxDecoration(
              color: hasImage ? Colors.green.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasImage ? Colors.green.shade300 : Colors.grey.shade300,
                width: hasImage ? 2 : 1,
              ),
            ),
            child: hasImage
                ? Stack(
                    children: [
                      // Preview gambar dengan kompatibilitas web
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.memory(
                                _imageBytes!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                _imageFile!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      // Overlay dengan informasi
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black.withOpacity(0.3),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Foto Terpilih',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap untuk mengganti foto',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Tombol hapus
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: _clearImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade500,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap untuk memilih foto',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dari galeri - Maks. 10MB',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        // Tombol untuk kamera (hanya untuk mobile)
        if (!kIsWeb) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImageFromCamera,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade600,
                    side: BorderSide(color: Colors.green.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(Icons.camera_alt, size: 18),
                  label: Text(
                    'Ambil Foto dengan Kamera',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_upload, color: Colors.green.shade600),
              const SizedBox(width: 8),
              Text(
                'Mengupload gambar ke Cloudinary...',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: Colors.green.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 4),
          Text(
            '${(_uploadProgress * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 12, color: Colors.green.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isLoading
            ? []
            : [
                BoxShadow(
                  color: Colors.green.shade400.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitLaporan,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          disabledBackgroundColor: Colors.green.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mengirim...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Kirim Laporan',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  IconData _getKategoriIcon(String kategori) {
    switch (kategori) {
      case 'Infrastruktur':
        return Icons.construction;
      case 'Kebersihan':
        return Icons.clean_hands;
      case 'Keamanan':
        return Icons.security;
      case 'Lingkungan':
        return Icons.nature;
      case 'Lainnya':
        return Icons.more_horiz;
      default:
        return Icons.category;
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      if (kIsWeb) {
        // Untuk Flutter Web
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;

          // Validasi ukuran file (max 10MB)
          if (file.size > 10 * 1024 * 1024) {
            _showErrorDialog("Ukuran file maksimal 10MB");
            return;
          }

          setState(() {
            _imageBytes = file.bytes;
            _imageFile = null;
          });
        }
      } else {
        // Untuk Windows, Android, iOS
        final XFile? pickedFile = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          final file = File(pickedFile.path);

          // Validasi ukuran file
          final fileSize = await file.length();
          if (fileSize > 10 * 1024 * 1024) {
            _showErrorDialog("Ukuran file maksimal 10MB");
            return;
          }

          setState(() {
            _imageFile = file;
            _imageBytes = null;
          });
        }
      }
    } catch (e) {
      _showErrorDialog("Gagal memilih gambar: $e");
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      // Hanya untuk mobile, web tidak support camera
      if (!kIsWeb) {
        final XFile? pickedFile = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          final file = File(pickedFile.path);

          // Validasi ukuran file
          final fileSize = await file.length();
          if (fileSize > 10 * 1024 * 1024) {
            _showErrorDialog("Ukuran file maksimal 10MB");
            return;
          }

          setState(() {
            _imageFile = file;
          });
        }
      }
    } catch (e) {
      _showErrorDialog('Gagal mengambil foto dengan kamera: $e');
    }
  }

  void _clearImage() {
    setState(() {
      _imageFile = null;
      _imageBytes = null;
    });
  }

  // laporan_screen.dart (UPDATE FUNGSI _submitLaporan)
  void _submitLaporan() async {
    final int userId = widget.user.id is int
        ? widget.user.id
        : int.tryParse(widget.user.id.toString()) ?? 0;

    if (userId == 0) {
      _showErrorDialog('User ID tidak valid, silakan login ulang.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final String? token = await AuthService.getToken();
      if (token == null) {
        _showSessionExpiredDialog();
        return;
      }

      print('🔑 Token: ${token.substring(0, 20)}...');

      // Buat multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://wargakita.canadev.my.id/reports'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Tambahkan fields
      request.fields.addAll({
        'title': _judulController.text.trim(),
        'description': _deskripsiController.text.trim(),
        'category': _selectedKategori,
        'userId': userId.toString(), // 🔥 STRING OK karena ASALNYA INT
      });


      // Handle image upload dengan MIME type yang benar
      if (_imageFile != null || _imageBytes != null) {
        await _addImageToRequest(request);
      }

      print('📤 Sending to: ${request.url}');

      // Kirim request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Status: ${response.statusCode}');
      print('Response: ${response.body}');

      // Handle response
      if (response.statusCode.toString().startsWith('2')) {
        final responseData = jsonDecode(response.body);

        print('✅ Success! ID: ${responseData['id']}');
        print('📸 Image URL: ${responseData['imageUrl']}');

        if (!mounted) return;

        _clearForm();
        
        _showSuccessDialog(
          imageUrl: responseData['imageUrl'],
          reportId: responseData['id']?.toString() ?? '-',
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['message'] ?? 'Error ${response.statusCode}';
        _showErrorDialog(
          "Backend error: $errorMessage\n\nPastikan file gambar valid (JPG, PNG, GIF).",
        );
      }
    } catch (e) {
      print('❌ Error: $e');
      _showErrorDialog("Gagal mengirim: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addImageToRequest(http.MultipartRequest request) async {
    try {
      String filePath = '';
      List<int>? fileBytes;
      String? mimeType;
      String extension = 'jpg';

      // Deteksi file source
      if (_imageFile != null) {
        filePath = _imageFile!.path;
        fileBytes = await _imageFile!.readAsBytes();
      } else if (_imageBytes != null) {
        fileBytes = _imageBytes!;
        filePath = 'web_upload_${DateTime.now().millisecondsSinceEpoch}';
      }

      if (fileBytes == null || fileBytes.isEmpty) {
        print('⚠️ No image bytes available');
        return;
      }

      // Deteksi MIME type menggunakan package mime
      mimeType = lookupMimeType(filePath, headerBytes: fileBytes);
      print('🔍 Detected MIME type: $mimeType');
      print('📁 File path/name: $filePath');

      // Jika mimeType tidak terdeteksi, coba deteksi manual
      if (mimeType == null || mimeType.isEmpty) {
        mimeType = _detectMimeTypeManually(fileBytes);
        print('🔍 Manual MIME detection: $mimeType');
      }

      // Set extension berdasarkan MIME type
      if (mimeType == 'image/png') {
        extension = 'png';
      } else if (mimeType == 'image/jpeg') {
        extension = 'jpg';
      } else if (mimeType == 'image/gif') {
        extension = 'gif';
      }

      // Validasi MIME type sesuai backend requirements
      final allowedMimeTypes = [
        'image/jpeg',
        'image/png',
        'image/jpg',
        'image/gif',
      ];
      if (!allowedMimeTypes.contains(mimeType)) {
        print('❌ Unsupported MIME type: $mimeType');
        _showWarningDialog(
          'Format file tidak didukung',
          'File memiliki tipe: $mimeType\nBackend hanya menerima: JPG, PNG, GIF',
        );
        return;
      }

      // Split mimeType untuk MediaType
      final mimeParts = mimeType?.split('/');
      if (mimeParts?.length != 2) {
        print('❌ Invalid MIME type format: $mimeType');
        return;
      }

      final contentType = MediaType(mimeParts![0], mimeParts[1]);
      final filename =
          'report_${DateTime.now().millisecondsSinceEpoch}.$extension';

      print('📁 Final filename: $filename');
      print('📁 Content-Type: $contentType');

      // Tambahkan file ke request
      if (_imageFile != null) {
        // Dari file path
        request.files.add(
          await http.MultipartFile.fromPath(
            'imageFile',
            _imageFile!.path,
            filename: filename,
            contentType: contentType,
          ),
        );
      } else {
        // Dari bytes (web)
        request.files.add(
          http.MultipartFile.fromBytes(
            'imageFile',
            fileBytes,
            filename: filename,
            contentType: contentType,
          ),
        );
      }

      print('✅ Image added to request');
    } catch (e) {
      print('❌ Error adding image: $e');
      _showWarningDialog(
        'Error proses gambar',
        'Gagal memproses gambar: $e\nLaporan akan dikirim tanpa gambar.',
      );
    }
  }

  String? _detectMimeTypeManually(List<int> bytes) {
    if (bytes.length < 4) return null;

    // PNG signature: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }

    // JPEG signature: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    // GIF signature: GIF87a or GIF89a
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return 'image/gif';
    }

    return null;
  }

  // HAPUS fungsi _uploadToCloudinary() karena tidak digunakan lagi
  // atau bisa dijadikan backup plan

  // Fungsi untuk handle session expired
  void _showSessionExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600),
            SizedBox(width: 10),
            Text('Sesi Berakhir'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sesi login Anda telah berakhir.'),
            SizedBox(height: 8),
            Text(
              'Silakan login kembali untuk mengirim laporan.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Kembali ke halaman sebelumnya
            },
            child: Text('Nanti'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate ke login screen
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            child: Text('Login Ulang'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog({String? imageUrl, String reportId = '-'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Laporan Berhasil Dikirim!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),

              // Show image preview jika ada
              if (imageUrl != null) ...[
                Container(
                  height: 120,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              Text(
                'ID Laporan: #$reportId\n\nLaporan Anda telah berhasil dikirim dan akan segera diproses oleh tim kami.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearForm();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade600,
                        side: BorderSide(color: Colors.green.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Buat Laporan Baru'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWarningDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Lanjutkan',
              style: TextStyle(color: Colors.green.shade600),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Text(
              'Terjadi Kesalahan',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Tutup',
              style: TextStyle(color: Colors.green.shade600),
            ),
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    _judulController.clear();
    _deskripsiController.clear();
    setState(() {
      _selectedKategori = 'Infrastruktur';
      _imageFile = null;
      _imageBytes = null;
    });
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }
}
