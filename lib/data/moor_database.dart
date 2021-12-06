import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart'show rootBundle;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;
part 'moor_database.g.dart';
// The name of the database table is "tasks"
// By default, the name of the generated data class will be "Task" (without "s")

// The default data class name "Tasks" would now be "SomeOtherNameIfYouWant"
//@DataClassName('SomeOtherNameIfYouWant')
class Tasks extends Table {
  // autoIncrement automatically sets this to be the primary key
  IntColumn get id => integer().autoIncrement()();
  // If the length constraint is not fulfilled, the Task will not
  // be inserted into the database and an exception will be thrown.
  TextColumn get name => text().withLength(min: 1, max: 50)();
  // DateTime is not natively supported by SQLite
  // Moor converts it to & from UNIX seconds
  DateTimeColumn get dueDate => dateTime().nullable()();
  // Booleans are not supported as well, Moor converts them to integers
  // Simple default values are specified as Constants
  BoolColumn get completed => boolean().withDefault(Constant(false))();


  // Custom primary keys defined as a set of columns
  // @override
  // Set<Column> get primaryKey => {id, name};
}

// This annotation tells the code generator which tables this DB works with
@DriftDatabase(tables: [Tasks], daos: [TaskDao])
// _$AppDatabase is the name of the generated class
class AppDatabase extends _$AppDatabase {
  AppDatabase()
  // Specify the location of the database file
      : super(_openConnection());

  // Bump this when changing tables and columns.
  // Migrations will be covered in the next part.
  @override
  int get schemaVersion => 2;

}
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // put the database file, called db.sqlite here, into the documents folder
    // for your app.
    final dbFolder = await getDatabasesPath();
    final file = File(p.join(dbFolder, 'db.sqlite'));

   /* if (!await file.exists()) {
      // Extract the pre-populated database file from assets
      final blob = await rootBundle.load('assets/my_database.db');
      await file.writeAsBytes(blob as List<int>);
    }*/
    return NativeDatabase(file);
  });
}

// Denote which tables this DAO can access
@DriftAccessor(tables: [Tasks], queries: {
  // An implementation of this query will be generated inside the _$TaskDaoMixin
  // Both completeTasksGenerated() and watchCompletedTasksGenerated() will be created.
  'completedTasksGenerated':
  'SELECT * FROM tasks WHERE completed = 1 ORDER BY due_date DESC, name;'
},)
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  final AppDatabase db;

  // Called by the AppDatabase class
  TaskDao(this.db) : super(db);

  // All tables have getters in the generated class - we can select the tasks table
  Future<List<Task>> getAllTasks() => select(tasks).get();

  // Moor supports Streams which emit elements when the watched data changes
// Updated to use the orderBy statement
  Stream<List<Task>> watchAllTasks() {
    // Wrap the whole select statement in parenthesis
    return (select(tasks)
    // Statements like orderBy and where return void => the need to use a cascading ".." operator
      ..orderBy(
        ([
          // Primary sorting by due date
              (t) =>
              OrderingTerm(expression: t.dueDate, mode: OrderingMode.desc),
          // Secondary alphabetical sorting
              (t) => OrderingTerm(expression: t.name),
        ]),
      ))
    // watch the whole select statement
        .watch();
  }

  Stream<List<Task>> watchCompletedTasks() {
    // where returns void, need to use the cascading operator
    return (select(tasks)
      ..orderBy(
        ([
          // Primary sorting by due date
              (t) =>
              OrderingTerm(expression: t.dueDate, mode: OrderingMode.desc),
          // Secondary alphabetical sorting
              (t) => OrderingTerm(expression: t.name),
        ]),
      )
      ..where((t) => t.completed.equals(true)))
        .watch();
  }

  // Watching complete tasks with a custom query
  Stream<List<Task>> watchCompletedTasksCustom() {
    // select all categories and load how many associated entries there are for
    // each category
    return customSelect(
      'SELECT * FROM tasks WHERE completed = 1 ORDER BY due_date DESC, name;',
      // The Stream will emit new values when the data inside the Tasks table changes
      readsFrom: {tasks},
      // customSelect or customSelectStream gives us QueryRow list
      // This runs each time the Stream emits a new value.
    ).watch().map((rows) {
      // Turning the data of a row into a Task object
     // return rows.map((row) => Task.fromData(row.data, db)).toList();
      return rows
          .map((row) => Task.fromData(row.data))
          .toList();
    });
  }

  Future insertTask(Insertable<Task> task) => into(tasks).insert(task);

  // Updates a Task with a matching primary key
  Future updateTask(Insertable<Task> task) => update(tasks).replace(task);

  Future deleteTask(Insertable<Task> task) => delete(tasks).delete(task);

}
