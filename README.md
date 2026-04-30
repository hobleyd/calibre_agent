# Calibre Agent

A Flutter desktop application for macOS, Linux, and Windows that serves your [Calibre](https://calibre-ebook.com/) library over a local HTTPS REST API. Designed to work with [Paladin](../paladin), which uses mDNS to discover and connect to Calibre Agent automatically.

## How it works

1. Point Calibre Agent at your Calibre library folder
2. Start the server — it generates a self-signed TLS certificate and begins listening on the configured port (default **10444**)
3. The server advertises itself on the local network via mDNS (`calibre-agent._http._tcp`)
4. Paladin discovers the server automatically and syncs your library

## Calibre Library Requirements

Calibre Agent reads directly from Calibre's `metadata.db` SQLite database and expects two custom columns to be present:

| Column | Type | Purpose |
|--------|------|---------|
| `custom_column_3` | Boolean | Read status (`#is_read`) |
| `custom_column_4` | DateTime | Last read date (`#last_read`) |

Create these in Calibre via **Preferences → Add your own columns**.

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Library path | _(none)_ | Path to the Calibre library folder containing `metadata.db` |
| Port | `10444` | TCP port the HTTPS server listens on |

## TLS Certificate

A self-signed RSA-2048 certificate is generated automatically on first run and stored in the app's data directory. It is valid for 10 years. Use **Regenerate Certificate** in the UI to replace it. Paladin trusts this certificate via a pinned SHA-256 fingerprint exchanged at first connection.

---

## REST API

All responses are `application/json`. All timestamps are Unix epoch seconds (integer). The server uses HTTPS; clients must either trust the self-signed certificate or bypass TLS verification on the local network.

**Base URL:** `https://<host>:<port>` (default port 10444)

**CORS:** All origins are permitted (`Access-Control-Allow-Origin: *`).

---

### `GET /` or `GET /health`

Returns server status and a summary of available endpoints.

**Response `200`**
```json
{
  "status": "running",
  "message": "Calibre Agent is running",
  "timestamp": "2026-04-30T10:00:00.000Z",
  "endpoints": {
    "GET /books": "List books (params: last_modified, limit, offset)",
    "PUT /books": "Update book data in Calibre",
    "GET /book/<uuid>": "Download EPUB file",
    "GET /count/<last_modified>/<limit>": "Count modified books",
    "GET /library": "List all UUIDs",
    "GET /details/<uuid>": "Book metadata",
    "GET /tags/<uuid>": "Book tags",
    "GET /health": "This message"
  }
}
```

---

### `GET /books`

Returns a paginated list of books, optionally filtered to those modified or read after a given timestamp.

**Query parameters**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `last_modified` | integer | `0` | Return only books with `Last_modified` or `Last_read` ≥ this Unix timestamp |
| `limit` | integer | `100` | Maximum number of books to return (capped at `1000`) |
| `offset` | integer | `0` | Number of books to skip (for pagination) |

**Response `200`** — array of [Book objects](#book-object)

```json
[
  {
    "UUID": "a1b2c3d4-...",
    "Title": "Dune",
    "Series": { "series": "Dune Chronicles" },
    "Series_index": 1.0,
    "Author": [{ "name": "Frank Herbert" }],
    "Rating": 10,
    "Is_read": true,
    "Last_read": 1714435200,
    "Last_modified": 1714435200,
    "Blurb": "A science fiction masterpiece...",
    "Tags": [{ "id": 3, "tag": "Science Fiction" }]
  }
]
```

---

### `PUT /books`

Updates read status, last-read date, and last-modified timestamp for one or more books. Also removes the `Future Reads` tag from any book that is updated.

**Request body** — a single Book update object or an array of them

```json
{
  "UUID": "a1b2c3d4-...",
  "Is_read": true,
  "Last_read": 1714435200,
  "Last_modified": 1714435200
}
```

| Field | Type | Description |
|-------|------|-------------|
| `UUID` | string | Calibre book UUID (required) |
| `Is_read` | boolean | New read status |
| `Last_read` | integer | Unix timestamp of when the book was last read |
| `Last_modified` | integer | Unix timestamp to set as the book's last-modified date |

**Response `200`**
```json
{
  "status": "success",
  "message": "Updated 1 book(s)"
}
```

**Response `400`** — missing or invalid body

---

### `GET /book/<uuid>`

Downloads the EPUB file for the specified book.

**Path parameter:** `uuid` — Calibre book UUID

**Response `200`**
- `Content-Type: application/epub+zip`
- `Content-Disposition: attachment; filename="<uuid>.epub"`
- Body: raw EPUB binary

**Response `404`** — UUID not found or EPUB file missing on disk

---

### `GET /count/<last_modified>/<limit>`

Returns the total count of books modified or read since a timestamp, plus a summary list of those books.

**Path parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `last_modified` | integer | Unix timestamp threshold |
| `limit` | integer | Maximum number of books to include in the `books` array |

**Response `200`**
```json
{
  "count": 42,
  "books": [
    {
      "title": "Dune",
      "author": "Herbert, Frank",
      "last_modified": 1714435200
    }
  ]
}
```

`count` reflects the total number of matching books; `books` is truncated to `limit`.

---

### `GET /library`

Returns the UUIDs of all books in the library, ordered by `last_modified` descending.

**Response `200`**
```json
[
  { "uuid": "a1b2c3d4-..." },
  { "uuid": "e5f6a7b8-..." }
]
```

---

### `GET /details/<uuid>`

Returns full metadata for a single book.

**Path parameter:** `uuid` — Calibre book UUID

**Response `200`** — [Book object](#book-object)

**Response `404`** — UUID not found

---

### `GET /tags/<uuid>`

Returns the tags associated with a single book.

**Path parameter:** `uuid` — Calibre book UUID

**Response `200`**
```json
[
  { "id": 3, "tag": "Science Fiction" },
  { "id": 7, "tag": "Classic" }
]
```

**Response `500`** — database error

---

## Data Types

### Book object

| Field | Type | Description |
|-------|------|-------------|
| `UUID` | string | Calibre book UUID |
| `Title` | string | Book title |
| `Series` | object | `{ "series": "Series Name" }` — empty string if not in a series |
| `Series_index` | number | Position within the series (e.g. `1.0`) |
| `Author` | array | Array of `{ "name": "Author Name" }` — multiple entries for co-authored books |
| `Rating` | integer | Calibre rating 0–10 (0 = unrated, 10 = 5 stars) |
| `Is_read` | boolean | Whether the book has been marked as read |
| `Last_read` | integer | Unix timestamp when the book was last read (`0` if never) |
| `Last_modified` | integer | Unix timestamp of the last metadata change |
| `Blurb` | string | Book description/comments from Calibre |
| `Tags` | array | Array of `{ "id": integer, "tag": "string" }` |

### Error object

All error responses use HTTP status codes and return:

```json
{ "error": "Description of the error" }
```
