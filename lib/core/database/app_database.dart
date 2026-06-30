import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'app_database.g.dart';

class Players extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  IntColumn get skillLevel => integer().withDefault(const Constant(1))();

  IntColumn get rating => integer().withDefault(const Constant(1000))();

  IntColumn get wins => integer().withDefault(const Constant(0))();

  IntColumn get losses => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Leagues extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get maxPlayers => integer().withDefault(const Constant(16))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Matches extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();
  TextColumn get sessionId => text()(); // NEW

  TextColumn get teamAPlayer1 => text()();
  TextColumn get teamAPlayer2 => text()();

  TextColumn get teamBPlayer1 => text()();
  TextColumn get teamBPlayer2 => text()();

  IntColumn get teamAScore => integer().nullable()();
  IntColumn get teamBScore => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Attendance extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();
  TextColumn get playerId => text()();
  TextColumn get sessionId => text()(); // NEW
  DateTimeColumn get checkInTime => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'shuttle_league.sqlite'));
    return NativeDatabase(file);
  });
}

class LeaguePlayers extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();
  TextColumn get playerId => text()();
  DateTimeColumn get joinedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Players, Leagues, Matches, Attendance, LeaguePlayers],
)
