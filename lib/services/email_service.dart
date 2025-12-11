import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class EmailService {
  // Template baru untuk menerima rating
  static Future<bool> sendRatingToDeveloper({
    required String userName,
    required String userEmail,
    required int rating,
    required String? comment,
    required BuildContext context,
  }) async {
    try {
      print('📤 Mengirim rating ke developer...');

      // Buat string bintang untuk template
      String stars = '';
      for (int i = 0; i < rating; i++) {
        stars += '★';
      }
      for (int i = rating; i < 5; i++) {
        stars += '☆';
      }

      // Data untuk template baru
      final templateParams = {
        'user_name': userName,
        'user_email': userEmail,
        'rating': rating.toString(),
        'stars': stars, // String bintang: ★★★☆☆
        'comment': comment ?? 'Tidak ada komentar',
        'date_time': DateTime.now().toLocal().toString(),
        'app_name': 'Warga App',
        'app_version': '1.0.0',
        'platform': 'Mobile App',
      };

      print('📋 Mengirim data:');
      templateParams.forEach((key, value) {
        print('   $key: $value');
      });

      // Kirim ke EmailJS dengan template BARU
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'service_id': 'service_7td0ipe',
          'template_id':
              'template_rating_received', // GANTI dengan template baru
          'user_id': 'FQZbFqUisI5yBqDjp',
          'template_params': templateParams,
        }),
      );

      print('📨 Status: ${response.statusCode}');
      print('📨 Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Rating berhasil dikirim ke developer!');
        return true;
      } else {
        print('❌ EmailJS error. Fallback ke email manual.');
        return false;
      }
    } catch (e) {
      print('❌ Error: $e');
      return false;
    }
  }

  // Atau gunakan template yang sudah ada dengan parameter sederhana
  static Future<bool> sendRatingSimple({
    required String userName,
    required String userEmail,
    required int rating,
    required String? comment,
  }) async {
    try {
      // Template minimal dengan parameter yang pasti ada
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'service_id': 'service_7td0ipe',
          'template_id': 'template_xeaduwh', // Template existing
          'user_id': 'FQZbFqUisI5yBqDjp',
          'template_params': {
            // Gunakan parameter yang ada di template existing
            'user_name': userName,
            'user_email': userEmail,
            'rating': 'Rating: $rating/5',
            'comment': comment ?? 'Tidak ada komentar',
            'date': DateTime.now().toLocal().toString(),
          },
        }),
      );

      print('Simple email response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Simple email error: $e');
      return false;
    }
  }
}
