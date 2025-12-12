import 'package:flutter/src/widgets/framework.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';
import '../models/user.dart';

class UserService {
  final dbHelper = DatabaseHelper();

  Future<int> insertUser(User user) async {
    final db = await dbHelper.database;
    return await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<User?> getUserById(int id) async {
    final db = await dbHelper.database;
    final res = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (res.isNotEmpty) return User.fromMap(res.first);
    return null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await dbHelper.database;
    final res = await db.query('users');
    return res.map((e) => User.fromMap(e)).toList();
  }

  void openLiveChat(BuildContext context) {}
}


