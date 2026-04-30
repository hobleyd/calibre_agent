import 'package:sqlite3/sqlite3.dart';
import '../models/book.dart';

class CalibreDatabase {
  final String libraryPath;

  CalibreDatabase(this.libraryPath);

  String get databasePath => '$libraryPath/metadata.db';

  // Open read-only connection for queries
  Database _openRead() => sqlite3.open(databasePath, mode: OpenMode.readOnly);

  // Open read-write connection for updates
  Database _openWrite() => sqlite3.open(databasePath);

  int bookCount() {
    final db = _openRead();
    try {
      final result = db.select('SELECT COUNT(*) AS count FROM books');
      return result.first['count'] as int? ?? 0;
    } finally {
      db.dispose();
    }
  }

  List<Book> queryBooks(int lastModified, int limit, int offset) {
    final db = _openRead();
    try {
      final rows = db.select('''
        SELECT uuid, title,
               COALESCE(s.sort, '') AS series,
               COALESCE(series_index, 0) AS series_index,
               author_sort AS author,
               COALESCE(r.rating, 0) AS rating,
               COALESCE(cc3.value, 0) AS is_read,
               COALESCE(strftime('%s', cc4.value), 0) AS last_read,
               strftime('%s', last_modified, 'localtime') AS last_mod,
               COALESCE(c.text, '') AS blurb
        FROM books
        LEFT JOIN custom_column_3 cc3 ON cc3.book = books.id
        LEFT JOIN custom_column_4 cc4 ON cc4.book = books.id
        LEFT JOIN books_series_link bsl ON bsl.book = books.id
        LEFT JOIN series s ON s.id = bsl.series
        LEFT JOIN comments c ON c.book = books.id
        LEFT JOIN books_ratings_link brl ON brl.book = books.id
        LEFT JOIN ratings r ON r.id = brl.id
        WHERE datetime(last_modified, 'localtime') >= datetime(?, 'unixepoch')
           OR datetime(cc4.value, 'localtime') >= datetime(?, 'unixepoch')
        LIMIT ? OFFSET ?
      ''', [lastModified, lastModified, limit, offset]);

      return rows.map((row) => _rowToBook(row, db)).toList();
    } finally {
      db.dispose();
    }
  }

  Book? queryBook(String uuid) {
    final db = _openRead();
    try {
      final rows = db.select('''
        SELECT uuid, title,
               COALESCE(s.sort, '') AS series,
               COALESCE(series_index, 0) AS series_index,
               author_sort AS author,
               COALESCE(r.rating, 0) AS rating,
               COALESCE(cc3.value, 0) AS is_read,
               COALESCE(strftime('%s', cc4.value), 0) AS last_read,
               strftime('%s', last_modified, 'localtime') AS last_mod,
               COALESCE(c.text, '') AS blurb
        FROM books
        LEFT JOIN custom_column_3 cc3 ON cc3.book = books.id
        LEFT JOIN custom_column_4 cc4 ON cc4.book = books.id
        LEFT JOIN books_series_link bsl ON bsl.book = books.id
        LEFT JOIN series s ON s.id = bsl.series
        LEFT JOIN comments c ON c.book = books.id
        LEFT JOIN books_ratings_link brl ON brl.book = books.id
        LEFT JOIN ratings r ON r.id = brl.id
        WHERE uuid = ?
      ''', [uuid]);

      if (rows.isEmpty) return null;
      return _rowToBook(rows.first, db);
    } finally {
      db.dispose();
    }
  }

  List<Map<String, dynamic>> queryBookUuids() {
    final db = _openRead();
    try {
      final rows = db.select(
          'SELECT uuid FROM books ORDER BY last_modified DESC');
      return rows.map((r) => {'uuid': r['uuid'] as String}).toList();
    } finally {
      db.dispose();
    }
  }

  List<BookTag> queryBookTags(String uuid) {
    final db = _openRead();
    try {
      return _queryTagsInternal(uuid, db);
    } finally {
      db.dispose();
    }
  }

  List<BookTag> _queryTagsInternal(String uuid, Database db) {
    final rows = db.select('''
      SELECT tags.id, tags.name
      FROM books, tags, books_tags_link btl
      WHERE uuid = ?
        AND books.id = btl.book
        AND tags.id = btl.tag
    ''', [uuid]);
    return rows
        .map((r) => BookTag(id: r['id'] as int, tag: r['name'] as String))
        .toList();
  }

  Map<String, dynamic>? queryCountModified(int lastModified, int limit) {
    final db = _openRead();
    try {
      final rows = db.select('''
        SELECT DISTINCT b.title, b.author_sort,
               unixepoch(b.last_modified) AS last_modified,
               COUNT(*) OVER() AS count
        FROM books b
        LEFT JOIN custom_column_4 cc ON b.id = cc.book
        WHERE datetime(last_modified, 'localtime') >= datetime(?, 'unixepoch')
           OR datetime(value, 'localtime') >= datetime(?, 'unixepoch')
        ORDER BY unixepoch(last_modified) DESC
        LIMIT ?
      ''', [lastModified, lastModified, limit]);

      if (rows.isEmpty) return {'count': 0, 'books': []};

      final books = rows.map((r) => {
            'title': r['title'] as String,
            'author': r['author_sort'] as String,
            'last_modified': r['last_modified'] as int,
          }).toList();

      return {'count': rows.first['count'] as int, 'books': books};
    } finally {
      db.dispose();
    }
  }

  String? queryBookFilePath(String uuid) {
    final db = _openRead();
    try {
      final rows = db.select('''
        SELECT path || '/' || name || '.' || LOWER(format) AS file_path
        FROM books JOIN data ON books.id = data.book
        WHERE format = 'EPUB' AND uuid = ?
      ''', [uuid]);
      if (rows.isEmpty) return null;
      return rows.first['file_path'] as String?;
    } finally {
      db.dispose();
    }
  }

  void updateBook(Map<String, dynamic> bookData) {
    final db = _openWrite();
    try {
      db.execute('BEGIN');

      db.execute('DROP TRIGGER IF EXISTS books_update_trg');

      final uuid = bookData['UUID'] as String;
      final isRead = bookData['Is_read'] as bool? ?? false;
      final lastRead = bookData['Last_read'] as int? ?? 0;
      final lastMod = bookData['Last_modified'] as int? ?? 0;

      db.execute('''
        INSERT INTO custom_column_3 (book, value)
        VALUES ((SELECT id FROM books WHERE uuid = ?), ?)
        ON CONFLICT (book) DO UPDATE SET value = excluded.value
      ''', [uuid, isRead ? 1 : 0]);

      db.execute('''
        INSERT INTO custom_column_4 (book, value)
        VALUES ((SELECT id FROM books WHERE uuid = ?), datetime(?, 'unixepoch', 'localtime'))
        ON CONFLICT (book) DO UPDATE SET value = excluded.value
      ''', [uuid, lastRead]);

      db.execute('''
        DELETE FROM books_tags_link
        WHERE book IN (SELECT id FROM books WHERE uuid = ?)
          AND tag IN (SELECT id FROM tags WHERE name = 'Future Reads')
      ''', [uuid]);

      db.execute('''
        UPDATE books
        SET last_modified = datetime(?, 'unixepoch', 'localtime')
        WHERE uuid = ?
      ''', [lastMod, uuid]);

      db.execute('''
        CREATE TRIGGER books_update_trg
        AFTER UPDATE ON books
        BEGIN
          UPDATE books SET sort = title_sort(NEW.title)
          WHERE id = NEW.id AND OLD.title <> NEW.title;
        END
      ''');

      db.execute('COMMIT');
    } catch (e) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      db.dispose();
    }
  }

  Book _rowToBook(Row row, Database db) {
    final uuid = row['uuid'] as String? ?? '';
    final authorStr = row['author'] as String? ?? '';
    final authors = authorStr
        .split('&')
        .map((a) => BookAuthor(name: a.trim()))
        .toList();

    return Book(
      uuid: uuid,
      title: row['title'] as String? ?? '',
      series: BookSeries(series: row['series'] as String? ?? ''),When
      seriesIndex: _toDouble(row['series_index']),
      authors: authors,
      rating: _toInt(row['rating']),
      isRead: _toBool(row['is_read']),
      lastRead: _toInt(row['last_read']),
      lastModified: _toInt(row['last_mod']),
      blurb: row['blurb'] as String? ?? '',
      tags: _queryTagsInternal(uuid, db),
    );
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value != 0;
    return false;
  }
}
