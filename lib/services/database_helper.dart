import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_dimsum.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 20, // v20: Tambah stock & min_stock di tabel shops
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 10) {
      await _createDB(db, newVersion);
    }
    if (oldVersion < 11) {
      try { await db.execute("ALTER TABLE transactions ADD COLUMN invoice_number TEXT"); } catch (_) {}
    }
    if (oldVersion < 12) {
      try {
        await db.execute("ALTER TABLE attendances ADD COLUMN shop_id INTEGER");
        await db.execute("ALTER TABLE attendances ADD COLUMN user_id INTEGER");
      } catch (_) {}
    }
    if (oldVersion < 13) {
      // Ensure commonly queried columns exist (older DB schemas may lack these)
      try { await db.execute("ALTER TABLE finances ADD COLUMN status TEXT DEFAULT 'active'"); } catch (_) {}
      try { await db.execute("ALTER TABLE finances ADD COLUMN is_synced INTEGER DEFAULT 0"); } catch (_) {}
      try { await db.execute("ALTER TABLE transactions ADD COLUMN status TEXT DEFAULT 'active'"); } catch (_) {}
      try { await db.execute("ALTER TABLE transactions ADD COLUMN is_synced INTEGER DEFAULT 0"); } catch (_) {}
      try { await db.execute("ALTER TABLE attendances ADD COLUMN status TEXT DEFAULT 'active'"); } catch (_) {}
      // Attempt to create indexes; if the underlying column doesn't exist, ignore the error
      try { await db.execute("CREATE INDEX IF NOT EXISTS idx_finances_status ON finances (status)"); } catch (_) {}
      try { await db.execute("CREATE INDEX IF NOT EXISTS idx_finances_sync ON finances (is_synced)"); } catch (_) {}
      try { await db.execute("CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions (status)"); } catch (_) {}
      try { await db.execute("CREATE INDEX IF NOT EXISTS idx_transactions_sync ON transactions (is_synced)"); } catch (_) {}
      try { await db.execute("CREATE INDEX IF NOT EXISTS idx_attendances_sync ON attendances (is_synced)"); } catch (_) {}
    }
    if (oldVersion < 14) {
      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN shop_id INTEGER");
        await db.execute("ALTER TABLE finances ADD COLUMN shop_id INTEGER");
        await db.execute("CREATE INDEX IF NOT EXISTS idx_transactions_shop ON transactions (shop_id)");
        await db.execute("CREATE INDEX IF NOT EXISTS idx_finances_shop ON finances (shop_id)");
      } catch (_) {}
    }
    if (oldVersion < 15) {
      try {
        await db.execute("ALTER TABLE products ADD COLUMN shop_id INTEGER");
        await db.execute("ALTER TABLE categories ADD COLUMN shop_id INTEGER");
        await db.execute("CREATE INDEX IF NOT EXISTS idx_products_shop ON products (shop_id)");
        await db.execute("CREATE INDEX IF NOT EXISTS idx_categories_shop ON categories (shop_id)");
      } catch (_) {}
    }
    if (oldVersion < 16) {
      try {
        // Double check for shop_id in products and categories
        await db.execute("ALTER TABLE products ADD COLUMN shop_id INTEGER");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE categories ADD COLUMN shop_id INTEGER");
      } catch (_) {}
      try {
        await db.execute("CREATE INDEX IF NOT EXISTS idx_products_shop ON products (shop_id)");
      } catch (_) {}
      try {
        await db.execute("CREATE INDEX IF NOT EXISTS idx_categories_shop ON categories (shop_id)");
      } catch (_) {}
    }
    if (oldVersion < 17) {
      // Lewati v17 yang gagal
    }
    if (oldVersion < 18) {
      try {
        await db.execute("ALTER TABLE products ADD COLUMN parent_id INTEGER");
        await db.execute("ALTER TABLE products ADD COLUMN bundle_qty INTEGER DEFAULT 1");
      } catch (_) {}
    }
    if (oldVersion < 19) {
      try {
        await db.execute("ALTER TABLE products ADD COLUMN min_stock INTEGER DEFAULT 10");
      } catch (_) {}
    }
    if (oldVersion < 20) {
      try {
        await db.execute("ALTER TABLE shops ADD COLUMN stock INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE shops ADD COLUMN min_stock INTEGER DEFAULT 100");
      } catch (_) {}
    }
  }

  Future _createDB(Database db, int version) async {
    // ... (tabel-tabel sebelumnya tetap ada)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shops (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        is_main INTEGER DEFAULT 0,
        address TEXT,
        phone TEXT,
        slogan TEXT,
        tiktok TEXT,
        instagram TEXT,
        facebook TEXT,
        web TEXT,
        latitude TEXT,
        longitude TEXT,
        logo_url TEXT,
        is_synced INTEGER DEFAULT 1,
        status TEXT DEFAULT 'active',
        stock INTEGER DEFAULT 0,
        min_stock INTEGER DEFAULT 100
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shop_id INTEGER,
        name TEXT,
        status TEXT DEFAULT 'active',
        is_synced INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        parent_id INTEGER, -- ID Produk Asal (Jika Paket)
        bundle_qty INTEGER DEFAULT 1, -- Isi dalam paket
        min_stock INTEGER DEFAULT 10, -- Batas minimal stok
        name TEXT,
        description TEXT,
        price REAL,
        cost_price REAL,
        stock INTEGER,
        image_url TEXT,
        status TEXT DEFAULT 'active',
        is_synced INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS finances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE, 
        shop_id INTEGER,
        type TEXT, 
        category TEXT,
        amount REAL,
        description TEXT,
        date TEXT,
        is_synced INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active',
        void_by TEXT,
        user_name TEXT,
        shop_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE,
        image_path TEXT,
        latitude REAL,
        longitude REAL,
        type TEXT,
        date_time TEXT,
        shop_id INTEGER,
        user_id INTEGER,
        is_synced INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE,
        shop_id INTEGER,
        items TEXT, 
        invoice_number TEXT,
        total_price REAL,
        payment_method TEXT,
        cash_received REAL,
        change REAL,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active',
        void_by TEXT,
        user_name TEXT, -- Nama Kasir
        shop_name TEXT  -- Nama Cabang
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE,
        user_id INTEGER,
        shop_id INTEGER,
        starting_cash REAL,
        closing_cash REAL,
        actual_cash REAL,
        difference REAL,
        opened_at TEXT,
        closed_at TEXT,
        note TEXT,
        is_synced INTEGER DEFAULT 0,
        status TEXT, -- open / closed
        user_name TEXT,
        shop_name TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_components (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER, -- ID Produk Paket
        child_id INTEGER,  -- ID Produk Satuan/Isi
        quantity INTEGER,  -- Jumlah isi dalam 1 paket
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  // Tambahkan fungsi untuk hapus semua data absen (Permintaan User)
  Future<void> clearAttendances() async {
    final db = await database;
    await db.delete('attendances');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
