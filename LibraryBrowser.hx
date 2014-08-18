import sys.db.Types;
import sys.db.Connection;
import mtwin.web.Request;
import neko.Web;

class LibraryBrowser {

	var cnx:Connection;
	var dbFile:String;
	var req:mtwin.web.Request;

	public static function main() {
		var l = new LibraryBrowser();
		l.close();
	}

	public function new() {
		dbFile = neko.Web.getCwd() + "metadata.db";

		cnx = sys.db.Sqlite.open(dbFile);
		sys.db.Manager.cnx = cnx;
        sys.db.Manager.initialize();

		req = new mtwin.web.Request();
		trace(neko.Web.getURI());

		//*
		var b = Book.manager.get(2);
		trace(b.toString());
		//for (a in b.getIdentifiers()) trace(a);
		trace(b.getIdentifiers());
		//*/

	}

	public function close() {
		sys.db.Manager.cleanup();
		cnx.close();
	}
}

@:table("books")
class Book extends sys.db.Object {
	public var id: SId;
	public var title: SText;
	public var sort: SNull<SText>;
	public var timestamp: STimeStamp;
	public var pubdate: STimeStamp;
	public var series_index: SFloat;
	public var author_sort: SNull<SText>;
	public var isbn: SText;
	public var lccn: SText;
	public var path: SText;
	public var flags: SInt;
	public var uuid: SNull<SText>;
	public var has_cover: SBool;
	public var last_modified: STimeStamp;

  override public function toString() {
	return title + ' by ' + getAuthors().join(' & ');
  }

	public function getComment() :Comment {
		var r;
		for (c in Comment.manager.search({book: id})) r = c;
		return r;
	}

	public function getSeries() :Series {
		var r;
		for (s in BookSeries.manager.search({book: id})) r = s.Series;
		return r;
	}

	public function getTags() :Array<Tag> {
		var r = new Array<Tag>();
		for (t in BookTag.manager.search({book: id})) r.push(t.Tag);
		return r;
	}

	public function getAuthors() :Array<Author> {
		var r = new Array<Author>();
		for (t in BookAuthor.manager.search({book: id})) r.push(t.Author);
		return r;
	}

	public function getRatings() :Array<Rating> {
		var r = new Array<Rating>();
		for (t in BookRating.manager.search({book: id})) r.push(t.Rating);
		return r;
	}

	public function getLanguages() :Array<Language> {
		var r = new Array<Language>();
		for (t in BookLanguage.manager.search({book: id})) r.push(t.Language);
		return r;
	}

	public function getPublishers() :Array<Publisher> {
		var r = new Array<Publisher>();
		for (t in BookPublisher.manager.search({book: id})) r.push(t.Publisher);
		return r;
	}

	public function getFormats() :Array<Format> {
		var r = new Array<Format>();
		for (t in Format.manager.search({book: id})) r.push(t);
		return r;
	}

	public function getIdentifiers() :Map<String,String> {
		var r = new Map<String,String>();
		for (t in Identifier.manager.search({book: id})) r.set(t.type, t.val);
		return r;
	}

}

@:table("authors")
@:index(link,unique)
class Author extends sys.db.Object {
	public var id: SId;
	public var name: SText;
	public var sort: SNull<SText>;
	public var link: SText;

  override public function toString() {
	return name;
  }
	
	public function getBooks() :Array<Book> {
		var r = new Array<Book>();
		for (t in BookAuthor.manager.search({author: id})) r.push(t.Book);
		return r;
	}
}

@:table("books_authors_link")
@:index(book,author,unique)
class BookAuthor extends sys.db.Object {
	public var id: SId;
	@:relation(book) public var Book: Book;
	@:relation(author) public var Author: Author;
}

@:table("comments")
@:index(book,unique)
class Comment extends sys.db.Object {
	public var id: SId;
	public var book: SInt;
	public var text: SText;
}

@:table("tags")
@:index(name,unique)
class Tag extends sys.db.Object {
	public var id: SId;
	public var name: SText;

	public function getBooks() :Array<Book> {
		var r = new Array<Book>();
		for (t in BookTag.manager.search({tag: id})) r.push(t.Book);
		return r;
	}
}

@:table("books_tags_link")
@:index(book,tag,unique)
class BookTag extends sys.db.Object {
	public var id: SId;
	@:relation(book) public var Book: Book;
	@:relation(tag) public var Tag: Tag;
}

@:table("languages")
@:index(lang_code,unique)
class Language extends sys.db.Object {
	public var id: SId;
	public var lang_code: SText;
}

@:table("books_languages_link")
@:index(book,lang_code,unique)
class BookLanguage extends sys.db.Object {
	public var id: SId;
	@:relation(book) public var Book: Book;
	@:relation(lang_code) public var Language: Language;
	public var item_order: SInt;
}

@:table("publishers")
@:index(name,unique)
class Publisher extends sys.db.Object {
	public var id: SId;
	public var name: SText;
	public var sort: SText;

	public function getBooks() :Array<Book> {
		var r = new Array<Book>();
		for (t in BookPublisher.manager.search({publisher: id})) r.push(t.Book);
		return r;
	}
}

@:table("books_publishers_link")
@:index(book,unique)
class BookPublisher extends sys.db.Object {
	public var id: SId;
	@:relation(book) public var Book: Book;
	@:relation(publisher) public var Publisher: Publisher;
}


@:table("ratings")
@:index(rating,unique)
class Rating extends sys.db.Object {
	public var id: SId;
	public var rating: SInt;
}

@:table("books_ratings_link")
@:index(book,rating,unique)
class BookRating extends sys.db.Object {
	public var id: SId;
	@:relation(book) public var Book: Book;
	@:relation(rating) public var Rating: Rating;
}


@:table("series")
@:index(name,unique)
class Series extends sys.db.Object {
	public var id: SId;
	public var name: SText;
	public var sort: SText;

	public function getBooks() :Array<Book> {
		var r = new Array<Book>();
		for (t in BookSeries.manager.search({series: id})) r.push(t.Book);
		return r;
	}
}

@:table("books_series_link")
@:index(book,unique)
class BookSeries extends sys.db.Object {
	public var id: SId;
	@:relation(book) public var Book: Book;
	@:relation(series) public var Series: Series;
}

@:table("data")
@:index(book,format,unique)
class Format extends sys.db.Object {
  public var id: SId;
  @:relation(book) public var Book: Book;
  public var format: SText;
  public var uncompressed_size: SInt;
  public var name: SText;
}

@:table("identifiers")
@:index(book,type,unique)
class Identifier extends sys.db.Object {
  public var id: SId;
  @:relation(book) public var Book: Book;
  public var type: SText;
  public var val: SText;
}

