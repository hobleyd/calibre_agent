class BookAuthor {
  final String name;
  const BookAuthor({required this.name});

  Map<String, dynamic> toJson() => {'name': name};
}

class BookSeries {
  final String series;
  const BookSeries({required this.series});

  Map<String, dynamic> toJson() => {'series': series};
}

class BookTag {
  final int id;
  final String tag;
  const BookTag({required this.id, required this.tag});

  Map<String, dynamic> toJson() => {'id': id, 'tag': tag};
}

class Book {
  final String uuid;
  final String title;
  final BookSeries series;
  final double seriesIndex;
  final List<BookAuthor> authors;
  final int rating;
  final bool isRead;
  final int lastRead;
  final int lastModified;
  final String blurb;
  final List<BookTag> tags;

  const Book({
    required this.uuid,
    required this.title,
    required this.series,
    required this.seriesIndex,
    required this.authors,
    required this.rating,
    required this.isRead,
    required this.lastRead,
    required this.lastModified,
    required this.blurb,
    required this.tags,
  });

  Map<String, dynamic> toJson() => {
        'UUID': uuid,
        'Title': title,
        'Series': series.toJson(),
        'Series_index': seriesIndex,
        'Author': authors.map((a) => a.toJson()).toList(),
        'Rating': rating,
        'Is_read': isRead,
        'Last_read': lastRead,
        'Last_modified': lastModified,
        'Blurb': blurb,
        'Tags': tags.map((t) => t.toJson()).toList(),
      };
}
