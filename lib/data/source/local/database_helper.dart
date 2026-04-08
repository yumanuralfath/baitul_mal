import 'package:baitul_mal_plus/domain/models/project_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'baitul_mal.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        // Query SQL for create Table
        return db.execute(
          'CREATE TABLE projects(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)',
        );
      },
    );
  }

  // set project to db function
  Future<int> insertProject(ProjectModel project) async {
    Database db = await database;
    return await db.insert('projects', project.toMap());
  }

  // get project from db
  Future<List<ProjectModel>> getProjects() async {
    Database db = await database;

    final List<Map<String, dynamic>> maps = await db.query('projects');
    return List.generate(maps.length, (i) => ProjectModel.fromMap(maps[i]));
  }
}
