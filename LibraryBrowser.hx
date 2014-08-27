import sys.db.Types;
import sys.db.Connection;
import mtwin.web.Request;
import neko.Web;
import haxe.io.Path;

/**
   LibraryBrowser is the controller class, and the main entry point
   It contains all the methods for displaying the library
**/
class LibraryBrowser {

	var cnx:Connection;
	var dbFile:String;
	var req:mtwin.web.Request;
	var uri:String;
	var ext:String;

	public static function main() {
		var l = new LibraryBrowser();
		l.run();
		l.close();
	}

	public static function textesc(resolve:String->Dynamic, str:String) {
		return StringTools.htmlEscape(str);
	}

	public static function urlesc(resolve:String->Dynamic, str:String) {
		return StringTools.replace(StringTools.urlEncode(str), "%2F", "/");
	}

	public static function getmime(resolve:String->Dynamic, path:String) {
		var newpath = neko.Web.getCwd() + "/" + path;
		if (!sys.FileSystem.exists(newpath)) return "";
		var ext = Path.extension(newpath);
		switch ext {
		  case "epub": return "application/epub+zip";
		  case "prc":  return "application/x-mobipocket-ebook";
		  case "azw3": return "application/x-mobipocket-ebook";
		  case "mobi": return "application/x-mobipocket-ebook";
		  case "htmlz":return "application/zip";
		}

		var io = new sys.io.Process("file", ["-bi", newpath]);
		var out = io.stdout.readLine();
		return out.split(';')[0];
	}

	public function new() {
		dbFile = neko.Web.getCwd() + "metadata.db";

		cnx = sys.db.Sqlite.open(dbFile);
		sys.db.Manager.cnx = cnx;
		sys.db.Manager.initialize();

		uri = neko.Web.getURI();
		ext = Path.extension(uri);
		if (ext == "" || ext == "htm") ext = "html";
		req = new mtwin.web.Request(Path.withoutExtension(uri));
	}

	public function run() {
		var part;
		var level = 0;
		var comm = "";
		var args = [];
		do {
			part = req.getPathInfoPart(level++);
			if (level == 1 && part == "index.n") continue;
			if (comm == "") comm = part;
			else if (part != "") args.push(part);
		  
		} while (part != "");

		if (["main", "new","run","close"].indexOf(comm) > -1) { do_404([]); return; }
		var todo = Reflect.field(this, comm);
		if (!Reflect.isFunction(todo)) { do_404([]); return; }
		Reflect.callMethod(this, todo, [args]);
	}

	public function close() {
		sys.db.Manager.cleanup();
		cnx.close();
	}

	public function do_404(args:Array<String>) {
		neko.Web.setReturnCode(404);
		Sys.println("Not found");
		return true;
	}

	public function test(args:Array<String>) {
		for (c in args) trace(c);
		/* // search for authors
		var search = Author.manager.search($name.like("B%"),{orderBy: name, limit:20});
		for (a in search) trace(a);
		//*/
	}

	private function runStuff(method:String, options:Dynamic):Bool {
		var template_source = haxe.Resource.getString(method + "_" + ext);
		if (template_source == null) { do_404([]); return false; }
		var template = new haxe.Template(template_source);

		var out = template.execute(options, {textesc: textesc, urlesc: urlesc, getmime: getmime});

		if (ext == "xml") neko.Web.setHeader("Content-type","application/xml");
		Sys.print(out);
		return true;
	}

	public function author(args:Array<String>):Bool {
		if (args.length < 1) args.push("1");

		var id = Std.parseInt(args[0]);
		var the_author = if (id == null) Author.manager.get(1) else Author.manager.get(id);
		var the_books = the_author.getBooks();
		var do_all = false;
		if (args.length > 1 && args[1] == "all") do_all = true;

		var options = {author:the_author
					, books: the_books
		};

		return runStuff("author", options);
	}

	public function book(args:Array<String>):Bool {
		if (args.length < 1) args.push("1");

		var id = Std.parseInt(args[0]);
		var the_book = if (id == null) Book.manager.get(1) else Book.manager.get(id);
		var options = {book:the_book
					,authors:the_book.getAuthors()
					,comment:the_book.getComment()
					,tags:the_book.getTags()
					,formats:the_book.getFormats()
					,files:the_book.getFiles()
					,files_with_formats:the_book.getFilesWithFormats()
					,identifiers:the_book.getIdentifiers()
					,external_links:the_book.getExternalLinks()
		};

		return runStuff("book", options);
	}
}

class Preferences {

	private var file:String;
	private var formats:Array<String>;

	public function new( ?prefFile:String) {
	  file = if (prefFile == null) "prefs.json" else prefFile;
	  formats = [ "EPUB", "PDF", "AZW3" ];
	}

	public function sortFormats(a:Format, b:Format) {
		if (formats.indexOf(a.format) > -1 && formats.indexOf(b.format) < 0) return -1;
	    if (formats.indexOf(b.format) > -1 && formats.indexOf(a.format) < 0) return 1;
		return formats.indexOf(a.format) - formats.indexOf(b.format);
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
		r.sort((new Preferences()).sortFormats);
		return r;
	}

	public function getFiles() :Array<String> {
		var r = new Array<String>();
		var author = getAuthors()[0];
		for (t in getFormats()) r.push(author.name + "/" + title + " (" + id + ")/" + t.toString());
		return r;
	}

	public function getFilesWithFormats() :Array<{type:String,file:String}> {
		var r = [];
		var author = getAuthors()[0];
		for (t in getFormats()) r.push({type:t.format,file:author.name + "/" + title + " (" + id + ")/" + t.toString()});
		return r;
	}

	public function getIdentifiers() :Array<Identifier> {
		var r = new Array<Identifier>();
		for (t in Identifier.manager.search({book: id})) r.push(t);
		return r;
	}

	public function getIdentifierMap() :Map<String,String> {
		var r = new Map<String,String>();
		for (t in getIdentifiers()) r.set(t.type, t.val);
		return r;
	}

	public function getExternalLinks() :Array<{name:String,link:String}> {
		var r = [];
		var map = getIdentifierMap();
		for (t in map.keys()){
			switch t {
			  case "google": r.push({name:"Google",link:"http://books.google.com/books?id=" + map.get(t)});
			  case "goodreads": r.push({name:"Goodreads",link:"https://www.goodreads.com/book/show/" + map.get(t)});
			  case "amazon": r.push({name:"Amazon",link:"http://smile.amazon.com/dp/" + map.get(t)});
			  case "fictiondb": r.push({name:"FictionDB",link:"http://www.fictiondb.com/author/" + map.get(t) + ".htm"});
			  case "barnesnoble": r.push({name:"Barnes & Noble",link:"http://www.barnesandnoble.com/" + map.get(t)});
			  }  
		}
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

	override public function toString() {
		return text;
	}
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

	override public function toString() {
		return name + "." + format.toLowerCase();
	}
	
}

@:table("identifiers")
@:index(book,type,unique)
class Identifier extends sys.db.Object {
	public var id: SId;
	@:relation(book) public var Book: Book;
	public var type: SText;
	public var val: SText;

	override public function toString() {
		return type.toLowerCase() + ":" + val;
	}
}

