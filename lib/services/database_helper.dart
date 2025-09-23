// lib/services/database_helper.dart - UPDATED WITH CERTIFICATE REMINDER COLUMNS

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static Completer<Database>? _databaseCompleter;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // Use a Completer to prevent multiple initialization attempts
    if (_databaseCompleter == null) {
      _databaseCompleter = Completer<Database>();
      try {
        _database = await _initDatabase();
        _databaseCompleter!.complete(_database);
      } catch (e) {
        _databaseCompleter!.completeError(e);
        rethrow;
      }
    }

    return _databaseCompleter!.future;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'attendance_app.db');

    print('Initializing database at $path');

    // ✅ UPDATED: Increment version to 9 to add certificate reminder columns
    return await openDatabase(
      path,
      version: 10, // ← Updated version to add certificate reminder columns
      onCreate: _createDb,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    print('Creating database tables for version $version');

    // ✅ Create all core tables
    await _createCoreApplicationTables(db);

    // ✅ Create leave management tables
    await _createLeaveManagementTables(db);

    // ✅ Create sync and queue tables
    await _createSyncTables(db);

    // ✅ Create indexes for better performance
    await _createIndexes(db);

    print('✅ All database tables created successfully');
  }

  // ✅ Core application tables (attendance, employees, locations, etc.)
  Future<void> _createCoreApplicationTables(Database db) async {
    // ✅ UPDATED: Attendance table with separate location columns
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS attendance(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      employee_id TEXT NOT NULL,
      date TEXT NOT NULL,
      check_in TEXT,
      check_out TEXT,
      check_in_location_id TEXT,      -- ✅ NEW: Separate check-in location ID
      check_out_location_id TEXT,     -- ✅ NEW: Separate check-out location ID
      check_in_location_name TEXT,    -- ✅ NEW: Check-in location name
      check_out_location_name TEXT,   -- ✅ NEW: Check-out location name
      location_id TEXT,               -- ✅ LEGACY: Keep for backward compatibility
      is_synced INTEGER DEFAULT 0,
      sync_error TEXT,
      raw_data TEXT
    )
    ''');

    await _createTableIfNotExists(db, '''
CREATE TABLE IF NOT EXISTS location_exemptions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id TEXT NOT NULL,
  employee_name TEXT NOT NULL,
  employee_pin TEXT NOT NULL,
  reason TEXT NOT NULL,
  granted_at TEXT NOT NULL,
  granted_by TEXT NOT NULL,
  is_active INTEGER DEFAULT 1,
  expiry_date TEXT,
  notes TEXT,
  cached_at TEXT NOT NULL,
  UNIQUE(employee_id)
)
''');

    await _createTableIfNotExists(db, '''
CREATE TABLE IF NOT EXISTS geofence_exit_events(
  id TEXT PRIMARY KEY,
  employee_id TEXT NOT NULL,
  employee_name TEXT NOT NULL,
  exit_time TEXT NOT NULL,
  return_time TEXT,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  location_name TEXT,
  exit_reason TEXT,
  duration_minutes INTEGER DEFAULT 0,
  status TEXT DEFAULT 'active',
  hr_notified INTEGER DEFAULT 0,
  reminder_sent INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  is_synced INTEGER DEFAULT 0,
  sync_error TEXT,
  FOREIGN KEY(employee_id) REFERENCES employees(id)
)
''');


    // Employees table
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS employees(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      designation TEXT,
      department TEXT,
      image TEXT,
      face_data TEXT,
      last_updated INTEGER
    )
    ''');

    // Locations table
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS locations(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      address TEXT,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      radius REAL NOT NULL,
      is_active INTEGER DEFAULT 1,
      last_updated INTEGER
    )
    ''');

    // Polygon locations table
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS polygon_locations(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      coordinates TEXT NOT NULL,
      is_active INTEGER DEFAULT 1,
      center_latitude REAL NOT NULL,
      center_longitude REAL NOT NULL,
      last_updated INTEGER
    )
    ''');

    // Overtime requests table
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS overtime_requests(
      id TEXT PRIMARY KEY,
      project_name TEXT NOT NULL,
      project_code TEXT NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      requester_id TEXT NOT NULL,
      approver_id TEXT NOT NULL,
      status TEXT NOT NULL,
      request_time TEXT NOT NULL,
      response_message TEXT,
      response_time TEXT,
      is_synced INTEGER DEFAULT 0,
      employee_ids TEXT NOT NULL,
      sync_error TEXT,
      last_updated INTEGER
    )
    ''');

    print('✅ Core application tables created');
  }

  // ✅ Leave management specific tables
  Future<void> _createLeaveManagementTables(Database db) async {
    // ✅ ENHANCED: Leave applications table with ALL required fields including certificate reminder columns
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS leave_applications(
      id TEXT PRIMARY KEY,
      employee_id TEXT NOT NULL,
      employee_name TEXT NOT NULL,
      employee_pin TEXT NOT NULL,
      leave_type TEXT NOT NULL,
      start_date TEXT NOT NULL,
      end_date TEXT NOT NULL,
      total_days INTEGER NOT NULL,
      reason TEXT NOT NULL,
      is_already_taken INTEGER DEFAULT 0,
      certificate_url TEXT,
      certificate_file_name TEXT,
      status TEXT DEFAULT 'pending',
      application_date TEXT NOT NULL,
      line_manager_id TEXT NOT NULL,
      line_manager_name TEXT NOT NULL,
      review_date TEXT,
      review_comments TEXT,
      reviewed_by TEXT,
      is_active INTEGER DEFAULT 1,
      is_synced INTEGER DEFAULT 0,
      is_emergency_leave INTEGER DEFAULT 0,
      has_special_deduction INTEGER DEFAULT 0,
      priority_level TEXT DEFAULT 'normal',
      created_at TEXT NOT NULL,
      updated_at TEXT,
      requires_certificate_reminder INTEGER DEFAULT 0,
      certificate_reminder_date TEXT,
      certificate_reminder_sent INTEGER DEFAULT 0,
      certificate_reminder_count INTEGER DEFAULT 0,
      certificate_uploaded_date TEXT
    )
    ''');

    // ✅ Leave balances table with proper structure
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS leave_balances(
      id TEXT PRIMARY KEY,
      employee_id TEXT NOT NULL,
      year INTEGER NOT NULL,
      total_days TEXT NOT NULL,
      used_days TEXT NOT NULL,
      pending_days TEXT NOT NULL,
      last_updated TEXT,
      is_synced INTEGER DEFAULT 1,
      UNIQUE(employee_id, year)
    )
    ''');

    print('✅ Leave management tables created');
  }

  // ✅ NEW: Sync and queue tables for offline functionality
  Future<void> _createSyncTables(Database db) async {
    // ✅ Sync queue table for offline operations
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS sync_queue(
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      application_id TEXT NOT NULL,
      data TEXT NOT NULL,
      created_at TEXT NOT NULL,
      synced INTEGER DEFAULT 0,
      retry_count INTEGER DEFAULT 0,
      last_retry_at TEXT,
      error_message TEXT
    )
    ''');

    // ✅ Failed syncs table for retry logic
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS failed_syncs(
      id TEXT PRIMARY KEY,
      application_id TEXT NOT NULL,
      data TEXT NOT NULL,
      created_at TEXT NOT NULL,
      retry_count INTEGER DEFAULT 0,
      max_retries INTEGER DEFAULT 3,
      last_retry_at TEXT,
      error_message TEXT,
      next_retry_at TEXT
    )
    ''');

    // ✅ Notification logs table
    await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS notification_logs(
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      application_id TEXT,
      employee_id TEXT,
      manager_id TEXT,
      title TEXT,
      body TEXT,
      data TEXT,
      sent_at TEXT NOT NULL,
      success INTEGER DEFAULT 0,
      error_message TEXT
    )
    ''');

    print('✅ Sync and queue tables created');
  }

  // ✅ Create indexes for better performance
  Future<void> _createIndexes(Database db) async {
    try {
      // ✅ UPDATED: Attendance indexes with new location columns
      await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_employee_date ON attendance(employee_id, date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_synced ON attendance(is_synced)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_check_in_location ON attendance(check_in_location_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_check_out_location ON attendance(check_out_location_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_legacy_location ON attendance(location_id)');

      // Leave applications indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_employee_id ON leave_applications(employee_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_manager_id ON leave_applications(line_manager_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_status ON leave_applications(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_type ON leave_applications(leave_type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_application_date ON leave_applications(application_date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_emergency ON leave_applications(is_emergency_leave)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_active ON leave_applications(is_active)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_synced ON leave_applications(is_synced)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_cert_reminder ON leave_applications(requires_certificate_reminder)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_cert_reminder_sent ON leave_applications(certificate_reminder_sent)');

      // Leave balances indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_balance_employee_year ON leave_balances(employee_id, year)');


      await db.execute('CREATE INDEX IF NOT EXISTS idx_geofence_employee ON geofence_exit_events(employee_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_geofence_status ON geofence_exit_events(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_geofence_synced ON geofence_exit_events(is_synced)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_geofence_exit_time ON geofence_exit_events(exit_time)');
      // Location exemptions indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_exemptions_employee ON location_exemptions(employee_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_exemptions_active ON location_exemptions(is_active)');

      // Sync queue indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_synced ON sync_queue(synced)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_type ON sync_queue(type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_app_id ON sync_queue(application_id)');

      // Failed syncs indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_failed_syncs_retry ON failed_syncs(retry_count)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_failed_syncs_app_id ON failed_syncs(application_id)');

      // Employee indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_employees_name ON employees(name)');

      // Location indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_locations_active ON locations(is_active)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_polygon_locations_active ON polygon_locations(is_active)');

      print('✅ Database indexes created successfully');
    } catch (e) {
      print('Error creating indexes: $e');
    }
  }

  Future<void> _createTableIfNotExists(Database db, String sql) async {
    try {
      await db.execute(sql);
      final tableName = _extractTableName(sql);
      print('✅ Table created/verified: $tableName');
    } catch (e) {
      print('❌ Table operation error: $e');
      print('SQL: ${sql.substring(0, 100)}...');
      // Table might already exist, which is fine
    }
  }

  String _extractTableName(String sql) {
    final match = RegExp(r'CREATE TABLE (?:IF NOT EXISTS )?(\w+)').firstMatch(sql);
    return match?.group(1) ?? 'unknown';
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from $oldVersion to $newVersion');

    // Handle database upgrades here
    if (oldVersion < 2) {
      // Add new overtime_requests table if upgrading from version 1
      await _createTableIfNotExists(db, '''
    CREATE TABLE IF NOT EXISTS overtime_requests(
      id TEXT PRIMARY KEY,
      project_name TEXT NOT NULL,
      project_code TEXT NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      requester_id TEXT NOT NULL,
      approver_id TEXT NOT NULL,
      status TEXT NOT NULL,
      request_time TEXT NOT NULL,
      response_message TEXT,
      response_time TEXT,
      is_synced INTEGER DEFAULT 0,
      employee_ids TEXT NOT NULL,
      sync_error TEXT,
      last_updated INTEGER
    )
    ''');
    }

    if (oldVersion < 4) {
      // Force recreate leave tables with basic structure
      await db.execute('DROP TABLE IF EXISTS leave_applications');
      await db.execute('DROP TABLE IF EXISTS leave_balances');

      // Recreate with correct schema
      await _createLeaveManagementTables(db);
    }

    if (oldVersion < 5) {
      // Add indexes for better performance
      await _createIndexes(db);

      // Ensure created_at field exists and has default values
      try {
        await db.execute('''
      UPDATE leave_applications 
      SET created_at = application_date 
      WHERE created_at IS NULL OR created_at = ''
      ''');
      } catch (e) {
        print('Error updating created_at: $e');
      }

      print('✅ Enhanced indexes and constraints added successfully');
    }

    // Version 6 upgrade - Add missing emergency leave columns
    if (oldVersion < 6) {
      print('🔄 Upgrading to version 6: Adding emergency leave support columns');

      try {
        // Add the missing columns to existing leave_applications table
        await db.execute('ALTER TABLE leave_applications ADD COLUMN is_emergency_leave INTEGER DEFAULT 0');
        print('✅ Added is_emergency_leave column');
      } catch (e) {
        print('Column is_emergency_leave might already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE leave_applications ADD COLUMN has_special_deduction INTEGER DEFAULT 0');
        print('✅ Added has_special_deduction column');
      } catch (e) {
        print('Column has_special_deduction might already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE leave_applications ADD COLUMN priority_level TEXT DEFAULT "normal"');
        print('✅ Added priority_level column');
      } catch (e) {
        print('Column priority_level might already exist: $e');
      }

      // Ensure created_at field exists
      try {
        await db.execute('ALTER TABLE leave_applications ADD COLUMN created_at TEXT');
        print('✅ Added created_at column');
      } catch (e) {
        print('Column created_at might already exist: $e');
      }

      // Update existing records to have proper values
      try {
        await db.execute('''
      UPDATE leave_applications 
      SET 
        is_emergency_leave = CASE WHEN leave_type = 'emergency' THEN 1 ELSE 0 END,
        has_special_deduction = CASE WHEN leave_type = 'emergency' THEN 1 ELSE 0 END,
        priority_level = CASE 
          WHEN leave_type = 'emergency' THEN 'high'
          WHEN leave_type = 'sick' THEN 'medium'
          ELSE 'normal'
        END,
        created_at = COALESCE(created_at, application_date)
      WHERE created_at IS NULL OR created_at = ''
      ''');
        print('✅ Updated existing records with new column values');
      } catch (e) {
        print('Error updating existing records: $e');
      }

      print('✅ Database upgrade to version 6 completed successfully');
    }

    // Version 7 upgrade - Add sync tables
    if (oldVersion < 7) {
      print('🔄 Upgrading to version 7: Adding sync and queue tables');

      // Create sync tables
      await _createSyncTables(db);

      // Add additional indexes for new tables
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_synced ON sync_queue(synced)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_type ON sync_queue(type)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_failed_syncs_retry ON failed_syncs(retry_count)');
        print('✅ Added indexes for sync tables');
      } catch (e) {
        print('Error adding sync table indexes: $e');
      }

      print('✅ Database upgrade to version 7 completed successfully');
    }

    // Version 8 upgrade - Add separate location columns
    if (oldVersion < 8) {
      print('🔄 Upgrading to version 8: Adding separate check-in/check-out location columns');

      try {
        // Add separate location columns to attendance table
        await db.execute('ALTER TABLE attendance ADD COLUMN check_in_location_id TEXT');
        print('✅ Added check_in_location_id column');
      } catch (e) {
        print('Column check_in_location_id might already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE attendance ADD COLUMN check_out_location_id TEXT');
        print('✅ Added check_out_location_id column');
      } catch (e) {
        print('Column check_out_location_id might already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE attendance ADD COLUMN check_in_location_name TEXT');
        print('✅ Added check_in_location_name column');
      } catch (e) {
        print('Column check_in_location_name might already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE attendance ADD COLUMN check_out_location_name TEXT');
        print('✅ Added check_out_location_name column');
      } catch (e) {
        print('Column check_out_location_name might already exist: $e');
      }

      // Migrate existing data from legacy location_id to check_in_location_id
      try {
        await db.execute('''
      UPDATE attendance 
      SET 
        check_in_location_id = location_id,
        check_out_location_id = location_id
      WHERE location_id IS NOT NULL 
        AND (check_in_location_id IS NULL OR check_out_location_id IS NULL)
      ''');
        print('✅ Migrated existing location data to separate columns');
      } catch (e) {
        print('Error migrating location data: $e');
      }

      // Add indexes for new location columns
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_check_in_location ON attendance(check_in_location_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_attendance_check_out_location ON attendance(check_out_location_id)');
        print('✅ Added indexes for separate location columns');
      } catch (e) {
        print('Error adding location indexes: $e');
      }

      print('✅ Database upgrade to version 8 completed successfully');
    }

    // Version 9 upgrade - Add certificate reminder columns
    if (oldVersion < 9) {
      print('🔄 Upgrading to version 9: Adding certificate reminder columns');

      try {
        await db.execute('ALTER TABLE leave_applications ADD COLUMN requires_certificate_reminder INTEGER DEFAULT 0');
        print('✅ Added requires_certificate_reminder column');
      } catch (e) {
        print('Column requires_certificate_reminder might already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE leave_applications ADD COLUMN certificate_reminder_date TEXT');
        print('✅ Added certificate_reminder_date column');
      } catch (e) {
        print('Column certificate_reminder_date might already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE leave_applications ADD COLUMN certificate_reminder_sent INTEGER DEFAULT 0');
        print('✅ Added certificate_reminder_sent column');
      } catch (e) {
        print('Column certificate_reminder_sent might already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE leave_applications ADD COLUMN certificate_reminder_count INTEGER DEFAULT 0');
        print('✅ Added certificate_reminder_count column');
      } catch (e) {
        print('Column certificate_reminder_count might already exist: $e');
      }

      try {
        await db.execute('ALTER TABLE leave_applications ADD COLUMN certificate_uploaded_date TEXT');
        print('✅ Added certificate_uploaded_date column');
      } catch (e) {
        print('Column certificate_uploaded_date might already exist: $e');
      }

      // Add indexes for certificate reminder columns
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_cert_reminder ON leave_applications(requires_certificate_reminder)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_leave_cert_reminder_sent ON leave_applications(certificate_reminder_sent)');
        print('✅ Added indexes for certificate reminder columns');
      } catch (e) {
        print('Error adding certificate reminder indexes: $e');
      }

      // Update existing sick leave records to require certificate reminders if already taken
      try {
        await db.execute('''
      UPDATE leave_applications 
      SET 
        requires_certificate_reminder = CASE 
          WHEN leave_type = 'sick' AND is_already_taken = 1 AND certificate_url IS NULL THEN 1 
          ELSE 0 
        END,
        certificate_reminder_date = CASE 
          WHEN leave_type = 'sick' AND is_already_taken = 1 AND certificate_url IS NULL 
          THEN datetime(application_date, '+1 day')
          ELSE NULL 
        END
      WHERE leave_type = 'sick' AND is_already_taken = 1
      ''');
        print('✅ Updated existing sick leave records for certificate reminders');
      } catch (e) {
        print('Error updating existing records for certificate reminders: $e');
      }

      print('✅ Database upgrade to version 9 completed successfully');
    }

    // NEW: Version 10 upgrade - Add geofence exit monitoring table
    if (oldVersion < 10) {
      print('🔄 Upgrading to version 10: Adding geofence exit monitoring table');

      try {
        await _createTableIfNotExists(db, '''
      CREATE TABLE IF NOT EXISTS geofence_exit_events(
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        employee_name TEXT NOT NULL,
        exit_time TEXT NOT NULL,
        return_time TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        location_name TEXT,
        exit_reason TEXT,
        duration_minutes INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active',
        hr_notified INTEGER DEFAULT 0,
        reminder_sent INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_error TEXT
      )
      ''');

        // Add indexes for geofence table
        await db.execute('CREATE INDEX IF NOT EXISTS idx_geofence_employee ON geofence_exit_events(employee_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_geofence_status ON geofence_exit_events(status)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_geofence_synced ON geofence_exit_events(is_synced)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_geofence_exit_time ON geofence_exit_events(exit_time)');

        print('✅ Added geofence exit monitoring table and indexes');
      } catch (e) {
        print('Error adding geofence exit monitoring table: $e');
      }

      print('✅ Database upgrade to version 10 completed successfully');
    }

    print('🎉 Database upgrade completed successfully!');
  }

  // Enhanced query methods with better error handling
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    try {
      return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('❌ Error inserting into $table: $e');
      print('📋 Data: $data');

      // Try to handle specific table creation if needed
      if (e.toString().contains('no such table')) {
        await _createMissingTable(db, table);
        // Retry insert
        return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Handle specific column errors
      if (e.toString().contains('no such column')) {
        await _handleMissingColumn(db, table, e.toString());
        // Retry insert
        return await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> query(String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    try {
      return await db.query(
        table,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      print('❌ Error querying $table: $e');
      print('📋 Where: $where, Args: $whereArgs');

      // Return empty list if table doesn't exist yet
      if (e.toString().contains('no such table')) {
        await _createMissingTable(db, table);
        return [];
      }

      // Handle missing column errors
      if (e.toString().contains('no such column')) {
        await _handleMissingColumn(db, table, e.toString());
        // Retry with basic query
        return await db.query(table, limit: limit);
      }

      rethrow;
    }
  }

  Future<int> update(String table, Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    try {
      return await db.update(
        table,
        data,
        where: where,
        whereArgs: whereArgs,
      );
    } catch (e) {
      print('❌ Error updating $table: $e');
      print('📋 Data: $data, Where: $where, Args: $whereArgs');

      // Handle missing column errors
      if (e.toString().contains('no such column')) {
        await _handleMissingColumn(db, table, e.toString());
        // Retry update
        return await db.update(table, data, where: where, whereArgs: whereArgs);
      }

      return 0;
    }
  }

  Future<int> delete(String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    try {
      return await db.delete(
        table,
        where: where,
        whereArgs: whereArgs,
      );
    } catch (e) {
      print('❌ Error deleting from $table: $e');
      return 0;
    }
  }

  // Count records in a table
  Future<int> count(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    try {
      final result = await db.query(
        table,
        columns: ['COUNT(*) as count'],
        where: where,
        whereArgs: whereArgs,
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ Error counting records in $table: $e');
      return 0;
    }
  }

  // Execute custom SQL
  Future<void> execute(String sql) async {
    final db = await database;
    try {
      await db.execute(sql);
    } catch (e) {
      print('❌ Error executing SQL: $e');
      print('📋 SQL: $sql');
      rethrow;
    }
  }

  // Execute batch operations
  Future<void> batch(Function(Batch) operations) async {
    final db = await database;
    try {
      final batch = db.batch();
      operations(batch);
      await batch.commit(noResult: true);
    } catch (e) {
      print('❌ Error executing batch: $e');
      rethrow;
    }
  }

  // ✅ Helper method to create missing tables
  Future<void> _createMissingTable(Database db, String tableName) async {
    print('🔧 Creating missing table: $tableName');

    switch (tableName) {
      case 'attendance':
        await _createTableIfNotExists(db, '''
        CREATE TABLE IF NOT EXISTS attendance(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id TEXT NOT NULL,
          date TEXT NOT NULL,
          check_in TEXT,
          check_out TEXT,
          check_in_location_id TEXT,
          check_out_location_id TEXT,
          check_in_location_name TEXT,
          check_out_location_name TEXT,
          location_id TEXT,
          is_synced INTEGER DEFAULT 0,
          sync_error TEXT,
          raw_data TEXT
        )
        ''');
        break;

      case 'leave_applications':
        await _createTableIfNotExists(db, '''
        CREATE TABLE IF NOT EXISTS leave_applications(
          id TEXT PRIMARY KEY,
          employee_id TEXT NOT NULL,
          employee_name TEXT NOT NULL,
          employee_pin TEXT NOT NULL,
          leave_type TEXT NOT NULL,
          start_date TEXT NOT NULL,
          end_date TEXT NOT NULL,
          total_days INTEGER NOT NULL,
          reason TEXT NOT NULL,
          is_already_taken INTEGER DEFAULT 0,
          certificate_url TEXT,
          certificate_file_name TEXT,
          status TEXT DEFAULT 'pending',
          application_date TEXT NOT NULL,
          line_manager_id TEXT NOT NULL,
          line_manager_name TEXT NOT NULL,
          review_date TEXT,
          review_comments TEXT,
          reviewed_by TEXT,
          is_active INTEGER DEFAULT 1,
          is_synced INTEGER DEFAULT 0,
          is_emergency_leave INTEGER DEFAULT 0,
          has_special_deduction INTEGER DEFAULT 0,
          priority_level TEXT DEFAULT 'normal',
          created_at TEXT NOT NULL,
          updated_at TEXT,
          requires_certificate_reminder INTEGER DEFAULT 0,
          certificate_reminder_date TEXT,
          certificate_reminder_sent INTEGER DEFAULT 0,
          certificate_reminder_count INTEGER DEFAULT 0,
          certificate_uploaded_date TEXT
        )
        ''');
        break;

      case 'leave_balances':
        await _createTableIfNotExists(db, '''
        CREATE TABLE IF NOT EXISTS leave_balances(
          id TEXT PRIMARY KEY,
          employee_id TEXT NOT NULL,
          year INTEGER NOT NULL,
          total_days TEXT NOT NULL,
          used_days TEXT NOT NULL,
          pending_days TEXT NOT NULL,
          last_updated TEXT,
          is_synced INTEGER DEFAULT 1
        )
        ''');
        break;

      case 'sync_queue':
        await _createTableIfNotExists(db, '''
        CREATE TABLE IF NOT EXISTS sync_queue(
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          application_id TEXT NOT NULL,
          data TEXT NOT NULL,
          created_at TEXT NOT NULL,
          synced INTEGER DEFAULT 0,
          retry_count INTEGER DEFAULT 0,
          last_retry_at TEXT,
          error_message TEXT
        )
        ''');
        break;

      case 'failed_syncs':
        await _createTableIfNotExists(db, '''
        CREATE TABLE IF NOT EXISTS failed_syncs(
          id TEXT PRIMARY KEY,
          application_id TEXT NOT NULL,
          data TEXT NOT NULL,
          created_at TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0,
          max_retries INTEGER DEFAULT 3,
          last_retry_at TEXT,
          error_message TEXT,
          next_retry_at TEXT
        )
        ''');
        break;

      case 'notification_logs':
        await _createTableIfNotExists(db, '''
        CREATE TABLE IF NOT EXISTS notification_logs(
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          application_id TEXT,
          employee_id TEXT,
          manager_id TEXT,
          title TEXT,
          body TEXT,
          data TEXT,
          sent_at TEXT NOT NULL,
          success INTEGER DEFAULT 0,
          error_message TEXT
        )
        ''');
        break;

      default:
        print('❌ Unknown table: $tableName');
    }
  }

  // ✅ Handle missing column errors
  Future<void> _handleMissingColumn(Database db, String tableName, String error) async {
    print('🔧 Handling missing column in $tableName: $error');

    // Extract column name from error message
    final columnMatch = RegExp(r'no such column: (\w+)').firstMatch(error);
    if (columnMatch == null) return;

    final columnName = columnMatch.group(1)!;
    print('🔧 Missing column: $columnName');

    try {
      switch (tableName) {
        case 'attendance':
          await _addMissingAttendanceColumn(db, columnName);
          break;
        case 'leave_applications':
          await _addMissingLeaveApplicationColumn(db, columnName);
          break;
        case 'sync_queue':
          await _addMissingSyncQueueColumn(db, columnName);
          break;
        case 'failed_syncs':
          await _addMissingFailedSyncsColumn(db, columnName);
          break;
        default:
          print('❌ Cannot handle missing column for table: $tableName');
      }
    } catch (e) {
      print('❌ Error adding missing column: $e');
    }
  }

  // ✅ NEW: Add missing attendance columns
  Future<void> _addMissingAttendanceColumn(Database db, String columnName) async {
    switch (columnName) {
      case 'check_in_location_id':
        await db.execute('ALTER TABLE attendance ADD COLUMN check_in_location_id TEXT');
        break;
      case 'check_out_location_id':
        await db.execute('ALTER TABLE attendance ADD COLUMN check_out_location_id TEXT');
        break;
      case 'check_in_location_name':
        await db.execute('ALTER TABLE attendance ADD COLUMN check_in_location_name TEXT');
        break;
      case 'check_out_location_name':
        await db.execute('ALTER TABLE attendance ADD COLUMN check_out_location_name TEXT');
        break;
      case 'location_id':
        await db.execute('ALTER TABLE attendance ADD COLUMN location_id TEXT');
        break;
      case 'is_synced':
        await db.execute('ALTER TABLE attendance ADD COLUMN is_synced INTEGER DEFAULT 0');
        break;
      case 'sync_error':
        await db.execute('ALTER TABLE attendance ADD COLUMN sync_error TEXT');
        break;
      case 'raw_data':
        await db.execute('ALTER TABLE attendance ADD COLUMN raw_data TEXT');
        break;
      default:
        print('❌ Unknown attendance column: $columnName');
    }
  }

  Future<void> _addMissingLeaveApplicationColumn(Database db, String columnName) async {
    switch (columnName) {
      case 'is_emergency_leave':
        await db.execute('ALTER TABLE leave_applications ADD COLUMN is_emergency_leave INTEGER DEFAULT 0');
        break;
      case 'has_special_deduction':
        await db.execute('ALTER TABLE leave_applications ADD COLUMN has_special_deduction INTEGER DEFAULT 0');
        break;
      case 'priority_level':
        await db.execute('ALTER TABLE leave_applications ADD COLUMN priority_level TEXT DEFAULT "normal"');
        break;
      case 'created_at':
        await db.execute('ALTER TABLE leave_applications ADD COLUMN created_at TEXT');
        break;
      case 'updated_at':
        await db.execute('ALTER TABLE leave_applications ADD COLUMN updated_at TEXT');
        break;
      case 'requires_certificate_reminder':
        await db.execute('ALTER TABLE leave_applications ADD COLUMN requires_certificate_reminder INTEGER DEFAULT 0');
        break;
      case 'certificate_reminder_date':
        await db.execute('ALTER TABLE leave_applications ADD COLUMN certificate_reminder_date TEXT');
        break;
      case 'certificate_reminder_sent':
        await db.execute('ALTER TABLE leave_applications ADD COLUMN certificate_reminder_sent INTEGER DEFAULT 0');
        break;
      case 'certificate_reminder_count':
        await db.execute('ALTER TABLE leave_applications ADD COLUMN certificate_reminder_count INTEGER DEFAULT 0');
        break;
      case 'certificate_uploaded_date':
        await db.execute('ALTER TABLE leave_applications ADD COLUMN certificate_uploaded_date TEXT');
        break;
      default:
        print('❌ Unknown leave application column: $columnName');
    }
  }

  Future<void> _addMissingSyncQueueColumn(Database db, String columnName) async {
    switch (columnName) {
      case 'last_retry_at':
        await db.execute('ALTER TABLE sync_queue ADD COLUMN last_retry_at TEXT');
        break;
      case 'error_message':
        await db.execute('ALTER TABLE sync_queue ADD COLUMN error_message TEXT');
        break;
      default:
        print('❌ Unknown sync queue column: $columnName');
    }
  }

  Future<void> _addMissingFailedSyncsColumn(Database db, String columnName) async {
    switch (columnName) {
      case 'last_retry_at':
        await db.execute('ALTER TABLE failed_syncs ADD COLUMN last_retry_at TEXT');
        break;
      case 'error_message':
        await db.execute('ALTER TABLE failed_syncs ADD COLUMN error_message TEXT');
        break;
      case 'next_retry_at':
        await db.execute('ALTER TABLE failed_syncs ADD COLUMN next_retry_at TEXT');
        break;
      default:
        print('❌ Unknown failed syncs column: $columnName');
    }
  }

  // Method to clear all data (useful for debugging)
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      // Get all table names
      final tables = await txn.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
      );

      // Drop each table
      for (final table in tables) {
        if (table['name'] != 'android_metadata' &&
            table['name'] != 'sqlite_sequence') {
          await txn.execute('DROP TABLE IF EXISTS ${table['name']}');
        }
      }
    });

    // Reinitialize the database
    await _createDb(db, 9); // ✅ Updated to version 9

    print('🧹 Database cleared and reinitialized');
  }

  // ✅ Method to get database info for debugging
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    try {
      final tables = await db.query(
        'sqlite_master',
        where: 'type = ?',
        whereArgs: ['table'],
      );

      final info = <String, dynamic>{
        'path': db.path,
        'version': await db.getVersion(),
        'tables': [],
      };

      for (final table in tables) {
        final tableName = table['name'] as String;
        if (tableName != 'android_metadata' && tableName != 'sqlite_sequence') {
          final count = await this.count(tableName);
          info['tables'].add({
            'name': tableName,
            'count': count,
          });
        }
      }

      return info;
    } catch (e) {
      print('❌ Error getting database info: $e');
      return {'error': e.toString()};
    }
  }

  // ✅ Method to vacuum database for better performance
  Future<void> vacuum() async {
    final db = await database;
    try {
      await db.execute('VACUUM');
      print('🧹 Database vacuumed successfully');
    } catch (e) {
      print('❌ Error vacuuming database: $e');
    }
  }

  // ✅ Method to check table schema
  Future<List<Map<String, dynamic>>> getTableSchema(String tableName) async {
    final db = await database;
    try {
      return await db.query('PRAGMA table_info($tableName)');
    } catch (e) {
      print('❌ Error getting table schema for $tableName: $e');
      return [];
    }
  }

  // ✅ Method to check if table exists
  Future<bool> tableExists(String tableName) async {
    final db = await database;
    try {
      final result = await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['table', tableName],
      );
      return result.isNotEmpty;
    } catch (e) {
      print('❌ Error checking if table exists: $e');
      return false;
    }
  }

  // ✅ Method to get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final info = await getDatabaseInfo();
      final stats = <String, dynamic>{
        'version': info['version'],
        'path': info['path'],
        'totalTables': info['tables'].length,
        'tableStats': <String, dynamic>{},
      };

      for (final table in info['tables']) {
        stats['tableStats'][table['name']] = table['count'];
      }

      return stats;
    } catch (e) {
      print('❌ Error getting database stats: $e');
      return {'error': e.toString()};
    }
  }

  // ✅ Diagnostic method for debugging
  Future<void> runDiagnostics() async {
    print('🔍 Running database diagnostics...');

    try {
      final stats = await getDatabaseStats();
      print('📊 Database Statistics:');
      print('   Version: ${stats['version']}');
      print('   Total Tables: ${stats['totalTables']}');

      final tableStats = stats['tableStats'] as Map<String, dynamic>;
      tableStats.forEach((table, count) {
        print('   $table: $count records');
      });

      // Check attendance table specifically
      final attendanceSchema = await getTableSchema('attendance');
      print('📋 Attendance Table Schema:');
      for (final column in attendanceSchema) {
        print('   ${column['name']}: ${column['type']}');
      }

      // Check leave applications table specifically
      final leaveAppSchema = await getTableSchema('leave_applications');
      print('📋 Leave Applications Schema:');
      for (final column in leaveAppSchema) {
        print('   ${column['name']}: ${column['type']}');
      }

      // Check sync tables
      final hasSyncQueue = await tableExists('sync_queue');
      final hasFailedSyncs = await tableExists('failed_syncs');
      print('🔄 Sync Tables:');
      print('   sync_queue: ${hasSyncQueue ? "EXISTS" : "MISSING"}');
      print('   failed_syncs: ${hasFailedSyncs ? "EXISTS" : "MISSING"}');

      print('✅ Database diagnostics completed');
    } catch (e) {
      print('❌ Error running diagnostics: $e');
    }
  }
}