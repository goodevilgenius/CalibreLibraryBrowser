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
	var prefs:Preferences;

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

		prefs = new Preferences();
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

	private function runStuff(type:String, options:Dynamic, ?ret: Bool):String {
		var template_source = haxe.Resource.getString(type + "_" + ext);
		if (template_source == null) { do_404([]); return "failed"; }
		var template = new haxe.Template(template_source);

		var out = template.execute(options, {textesc: textesc, urlesc: urlesc, getmime: getmime});

		if (ret) return out;
		else {
			switch ext {
				case "xml": neko.Web.setHeader("Content-type","application/xml");
			}
			Sys.print(out);
			return "";
		}
	}

	private function getBookOptions(the_book:Book) {
		return {book:the_book
			,authors:the_book.getAuthors()
			,comment:the_book.getComment()
			,tags:the_book.getTags()
			,formats:the_book.getFormats()
			,files:the_book.getFiles()
			,files_with_formats:the_book.getFilesWithFormats()
			,identifiers:the_book.getIdentifiers()
			,external_links:the_book.getExternalLinks()
			,self: this
		};
	}

	private function getBookEntry(the_book:Book) {

	}

	public function index(args:Array<String>):Bool {
		return true;
	}

	public function author(args:Array<String>):Bool {
		if (args.length < 1) args.push("1");

		var id:Int = Std.parseInt(args[0]);
		var the_author:Author = if (id == null) Author.manager.get(1) else Author.manager.get(id);
		var the_books: Array<Book> = the_author.getBooks();
		//var full_books:Array<{book:Book, props:Dynamic}> = null;
		var do_all:Bool = false;
		var page:Int = null;
		var entries:Array<String> = [];

		// select timestamp from books where id in (select book from books_authors_link where author=137) order by timestamp desc limit 1;
		var tsRes = cnx.request('SELECT timestamp FROM books WHERE id IN (SELECT book FROM books_authors_link WHERE author=' + id + ') ORDER BY timestamp DESC LIMIT 1');
		var ts:STimeStamp = if (tsRes.length > 0) tsRes.next().timestamp else null;
		// Maybe an STimeStamp
		//$type(ts);
		//Sys.println(ts);
		// RFC3339: var d = DateTools.format(ts,%Y-%m-%dT%H:%M:%S%z); d = d.substr(0,d.length-2) + ":" + d.substr(-2);

		if (args.length > 1 && args[1] == "all") do_all = true;
		if (args.length > 2) {
			if (args[args.length - 2] == "page") page = Std.parseInt(args[args.length - 1]);
		}
		if (page == null || page < 0) page = 0;
		var next_page = page + 1;
		var last_page = page - 1;
		var next_page_link:String = null;
		var last_page_link:String = null;

		if (do_all) {
			// We need to get all the information for each book
			//full_books = new Array<{book:Book, props:Dynamic}>();
			var this_book_num = page * prefs.page_length;
			while (this_book_num < the_books.length && this_book_num < (page+1) * prefs.page_length) {
				var the_book:Book = the_books[this_book_num];
				var opts = {
						book: the_book
						, title: the_book.name
						, id: "calibre:book:" + the_book.id
						, published: the_book.pubdate
						, links: []
						, props: getBookOptions(the_books[this_book_num])
				};
				entries.push(runStuff("short_book_entry", opts, true));
				/*
				trace(the_book);
				trace(the_book.name);
				trace(the_book.title);
				//*/
				this_book_num++;
			}
			var next_page_num = next_page * prefs.page_length;
			if (next_page_num < the_books.length) next_page_link = "/author/" + id + "/all/page/" + next_page + ".xml";
			if (last_page >= 0) last_page_link = "/author/" + id + "/all/page/" + last_page + ".xml";
		}

		/*
		var options = {author:the_author
					, do_all: do_all
					, books: if (do_all) full_books else the_books
					, series: the_author.getSeries()
					, self: this
					};
		*/
		var options = {title:the_author.name
					   , id: "calibre:author:" + the_author.id
					   , updated: ts
					   , breadcrumb: [] // !!!!
					   , next_page: next_page_link
					   , last_page: last_page_link
					   , entries: entries
					, self: this
					};


		return runStuff("feed", options) == "";
	}

	public function book(args:Array<String>):Bool {
		if (args.length < 1) args.push("1");

		var id = Std.parseInt(args[0]);
		var the_book = if (id == null) Book.manager.get(1) else Book.manager.get(id);
		var options = getBookOptions(the_book);

		return runStuff("book", options) == "";
	}
}

class Preferences {

	private var file:String;
	private var formats:Array<String>;

	public var page_length(default, null):Int;
	public var url_base(default, null):String;
	public var catalog_name(default, null):String;

	public function new( ?prefFile:String) {
		file = if (prefFile == null) "prefs.json" else prefFile;
		formats = [ "EPUB", "PDF", "AZW3" ];
		page_length = 20;
		url_base = "";
		catalog_name = "Danjones' Library";
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

	@:skip public var name(get,never):String;

	public function get_name():String { 
		return title + ' by ' + getAuthors().join(' & ');
	}

	override public function toString() {
		return name;
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

	public function getSeries() :Array<Series> {
		var r = new Array<Series>();
		for (b in getBooks()) {
			var s = b.getSeries();
			if (r.indexOf(s) == -1 && s != null) r.push(s);
		}
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

	override public function toString() {
		return name;
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

