import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/assistant_provider.dart'; // We'll need ChatMessage from here

class ChatDatabaseHelper {
  static const _databaseName = "ai_chat.db";
  static const _databaseVersion = 1;

  static const table = 'messages';

  static const columnId = '_id';
  static const columnText = 'text';
  static const columnIsUser = 'isUser';
  static const columnIsSystem = 'isSystem';
  static const columnTimestamp = 'timestamp';

  // Singleton instance
  ChatDatabaseHelper._privateConstructor();
  static final ChatDatabaseHelper instance = ChatDatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Opens the database (and creates it if it doesn't exist)
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $table (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnText TEXT NOT NULL,
            $columnIsUser INTEGER NOT NULL,
            $columnIsSystem INTEGER NOT NULL,
            $columnTimestamp INTEGER NOT NULL
          )
          ''');
  }

  // Insert a message
  Future<int> insertMessage(ChatMessage message) async {
    Database db = await instance.database;
    return await db.insert(table, message.toMap());
  }

  // Retrieve all messages, ordered by timestamp
  Future<List<ChatMessage>> getAllMessages() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(table, orderBy: "$columnTimestamp ASC");

    return List.generate(maps.length, (i) {
      return ChatMessage.fromMap(maps[i]);
    });
  }

  // Delete all messages (Clear History)
  Future<void> clearHistory() async {
    Database db = await instance.database;
    await db.delete(table);
  }
}
