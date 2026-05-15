// Proof test for roadmap §0.6.bullet-3 — Android backup exclusion.
//
// Verifies that AndroidManifest.xml carries android:allowBackup="false"
// and references a backup_rules.xml that excludes all app data domains.
// CWD = frontend/ when invoked via `flutter test`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manifestContent;
  late String backupRulesContent;

  setUpAll(() {
    final cwd = Directory.current.path;
    manifestContent =
        File('$cwd/android/app/src/main/AndroidManifest.xml').readAsStringSync();
    backupRulesContent =
        File('$cwd/android/app/src/main/res/xml/backup_rules.xml')
            .readAsStringSync();
  });

  test('1. AndroidManifest.xml has android:allowBackup="false"', () {
    expect(manifestContent, contains('android:allowBackup="false"'),
        reason:
            'The <application> element must declare android:allowBackup="false" '
            'to prevent automatic cloud backup of P2P game data and forensics.');
  });

  test('2. AndroidManifest.xml references a fullBackupContent rule file', () {
    expect(manifestContent, contains('android:fullBackupContent='),
        reason:
            'The <application> element should reference a backup_rules.xml via '
            'android:fullBackupContent so that any future SDK-version upgrade '
            'that relaxes allowBackup still respects the exclusion rules.');
  });

  test('3. backup_rules.xml excludes file domain', () {
    expect(backupRulesContent, contains('domain="file"'),
        reason:
            'backup_rules.xml must have at least one <exclude domain="file" .../> '
            'to cover the app documents directory.');
    expect(backupRulesContent, contains('<exclude'),
        reason: 'Must contain an <exclude> element.');
  });

  test('4. backup_rules.xml excludes database domain', () {
    expect(backupRulesContent, contains('domain="database"'),
        reason:
            'backup_rules.xml must have at least one <exclude domain="database" .../> '
            'to cover SQLite databases (saved_games.db, saved_games_enc.db).');
  });
}
