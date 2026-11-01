
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class AccountService {
  AccountService._();

  static final AccountService instance = AccountService._();

  static const String _databaseName = 'pitfit_accounts.db';
  static const String _sessionUsernameKey = 'pitfit_session_username';
  static const String _sessionRoleKey = 'pitfit_session_role';

  // PBKDF2 z HMAC-SHA256 do wyprowadzania skrótu hasła.
  // Wartość soli jest losowa i osobna dla każdego konta.
  final Pbkdf2 _passwordAlgorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 600000,
    bits: 256,
  );

  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;

    final path = await getDatabasesPath();
    _database = await openDatabase(
      '$path/$_databaseName',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL COLLATE NOCASE UNIQUE,
            password_hash TEXT NOT NULL,
            password_salt TEXT NOT NULL,
            role TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  Future<String> _hashPassword(String password, List<int> salt) async {
    final key = await _passwordAlgorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    return base64Encode(await key.extractBytes());
  }

  List<int> _generateSalt() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256));
  }

  /// Tworzy konto. Zwraca komunikat błędu albo null, jeśli się udało.
  Future<String?> register({
    required String username,
    required String password,
    required String role,
  }) async {
    final normalizedUsername = username.trim();

    if (normalizedUsername.length < 3) {
      return 'Nazwa użytkownika musi mieć co najmniej 3 znaki.';
    }

    if (password.length < 8) {
      return 'Hasło musi mieć co najmniej 8 znaków.';
    }

    if (role != 'Użytkownik' && role != 'Trener') {
      return 'Nieprawidłowy typ konta.';
    }

    final db = await _db;

    final existing = await db.query(
      'accounts',
      columns: ['id'],
      where: 'username = ?',
      whereArgs: [normalizedUsername],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return 'Ta nazwa użytkownika jest już zajęta.';
    }

    final salt = _generateSalt();
    final passwordHash = await _hashPassword(password, salt);

    try {
      await db.insert('accounts', {
        'username': normalizedUsername,
        'password_hash': passwordHash,
        'password_salt': base64Encode(salt),
        'role': role,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on DatabaseException {
      return 'Nie udało się utworzyć konta. Spróbuj innej nazwy.';
    }

    return null;
  }

  /// Loguje użytkownika. Zwraca komunikat błędu albo null, jeśli się udało.
  Future<String?> login({
    required String username,
    required String password,
  }) async {
    final db = await _db;

    final results = await db.query(
      'accounts',
      where: 'username = ?',
      whereArgs: [username.trim()],
      limit: 1,
    );

    if (results.isEmpty) {
      return 'Nieprawidłowa nazwa użytkownika lub hasło.';
    }

    final account = results.first;
    final salt = base64Decode(account['password_salt'] as String);
    final expectedHash = account['password_hash'] as String;
    final actualHash = await _hashPassword(password, salt);

    if (actualHash != expectedHash) {
      return 'Nieprawidłowa nazwa użytkownika lub hasło.';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionUsernameKey,
      account['username'] as String,
    );
    await prefs.setString(
      _sessionRoleKey,
      account['role'] as String,
    );

    return null;
  }

  /// Zwraca zapisany użytkownik, jeśli istnieje sesja.
  Future<Map<String, String>?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_sessionUsernameKey);
    final role = prefs.getString(_sessionRoleKey);

    if (username == null || role == null) return null;

    return {
      'username': username,
      'role': role,
    };
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionUsernameKey);
    await prefs.remove(_sessionRoleKey);
  }
}
