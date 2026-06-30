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
  TextColumn get teamA => text()();
  TextColumn get teamB => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Attendance extends Table {
  TextColumn get id => text()();
  TextColumn get leagueId => text()();
  TextColumn get playerId => text()();
  DateTimeColumn get checkInTime => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Players, Leagues, Matches, Attendance],
)
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
