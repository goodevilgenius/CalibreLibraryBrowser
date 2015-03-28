# Calibre Library Browser

Development on this application has ceased. I mostly started this as an exercise
to learn Haxe, but I've found the language more difficult to work with than I'd
like, and I don't really have the time to pursue this project further.

At some point in time, I'd like to revisit the idea for this project, but I
probably will choose a different language. I will certainly leave this here if
someone else finds it of interest.

---

This is a work-in-progress, and is barely functional at all, currently.

This is a RESTful web app that serves as a front-end to your Calibre Library. It
can generate an OPDS catalog, or an HTML catalog.

## Installation

0. If starting from source, compile the project using `haxe compile.hxml`.
0. Make sure mod_neko is installed and enabled in your Apache.
0. Move index.n and .htaccess to the same directory as your Calibre library
   root. This directory should contain a `metadata.db` file.
0. Set up an alias, or a virtual machine within your Apache config. Something
   like the following should work:

        <VirtualHost *:80>
            ServerName  books.example.com
            DocumentRoot /path/to/books
        </VirtualHost>
0. Configure the app using `prefs.sample.json`. Copy to your Calibre library
   root, and name `prefs.json`.
0. Reload apache, and browse to to your root in your browser.
0. If using from an OPDS reader, use http://books.example.com/index.xml should
   work for you.
