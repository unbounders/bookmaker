'use strict';
var addTask, addTemplateTask, bookLinks, bookTemplates, callbacks, chapterLinks, chapterTemplates, extendAssets, extendBook, extendChapter, fs, glob, handlebars, helpers, loadTemplates, mangler, pagelinks, path, relative, renderEpub, sequence, temp, template, templates, tempname, toEpub, whenjs, zipStream, _,
  __hasProp = {}.hasOwnProperty;

zipStream = require('zipstream-contentment');

handlebars = require('handlebars');

helpers = require('./lib/hbs.js');

whenjs = require('when');

callbacks = require('when/callbacks');

path = require('path');

glob = require('glob');

fs = require('fs');

mangler = require('./lib/mangler');

sequence = require('when/sequence');

_ = require('underscore');

temp = require('./templates');

templates = temp.templates;

loadTemplates = temp.loadTemplates;

chapterTemplates = {
  manifest: '{{#if this.nomanifest }}\n{{else}}{{#if filename }}<item id="{{ id }}" href="{{ filename }}" media-type="application/xhtml+xml" properties="{{#if svg }}svg {{/if}}{{#if scripted }}scripted{{/if}}"/>\n{{/if}}{{#if subChapters.epubManifest}}\n{{ subChapters.epubManifest }}{{/if}}{{/if}}',
  spine: '{{#if filename }}<itemref idref="{{ id }}" linear="yes"></itemref>\n{{/if}}{{#if subChapters.epubManifest}}\n{{ subChapters.epubSpine }}{{/if}}',
  nav: '<li class="tocitem {{ id }}{{#if majornavitem}} majornavitem{{/if}}" id="toc-{{ id }}">{{#if filename }}<a href="{{ filename }}" rel="chapter">{{/if}}{{ title }}{{#if filename }}</a>\n{{/if}}\n{{ subChapters.navList }}\n</li>\n',
  ncx: '{{#if filename }}<navPoint id="navPoint-{{ navPoint }}" playOrder="{{ chapterIndex }}">\n  <navLabel>\n      <text>{{ title }}</text>\n  </navLabel>\n  <content src="{{ filename }}"></content>\n{{ subChapters.epubNCX }}</navPoint>{{else}}\n {{ subChapters.epubNCX }}\n{{/if}}'
};

bookTemplates = {
  manifest: '{{#each chapters }}{{{ this.epubManifest }}}{{/each}}',
  spine: '{{#each chapters }}{{{ this.epubSpine }}}{{/each}}',
  nav: '{{#each chapters }}{{{ this.navList }}}{{/each}}',
  ncx: '{{#each chapters }}{{{ this.epubNCX }}}{{/each}}'
};

for (tempname in chapterTemplates) {
  if (!__hasProp.call(chapterTemplates, tempname)) continue;
  template = chapterTemplates[tempname];
  chapterTemplates[tempname] = handlebars.compile(template);
}

for (tempname in bookTemplates) {
  template = bookTemplates[tempname];
  bookTemplates[tempname] = handlebars.compile(template);
}

relative = function(current, target) {
  var absolutecurrent, absolutetarget, relativetarget;

  absolutecurrent = path.dirname(path.resolve("/", current));
  absolutetarget = path.resolve("/", target);
  relativetarget = path.relative(absolutecurrent, absolutetarget);
  return relativetarget;
};

pagelinks = function(page, book) {
  var key, link, links, type, value, _ref, _ref1;

  links = (function() {
    var _ref, _results;

    _ref = page._links;
    _results = [];
    for (key in _ref) {
      value = _ref[key];
      link = {};
      link.rel = key;
      _results.push(_.extend(link, value));
    }
    return _results;
  })();
  if (book.meta.cover) {
    if (path.extname(book.meta.cover) === '.jpg') {
      type = 'image/jpeg';
    }
    if (path.extname(book.meta.cover) === '.png') {
      type = 'image/png';
    }
    if (path.extname(book.meta.cover) === '.svg') {
      type = 'image/svg+xml';
    }
    links.push({
      rel: 'cover',
      href: relative(page.filename, book.meta.cover),
      type: type,
      title: 'Cover Image'
    });
    links.push({
      rel: 'cover',
      href: relative(page.filename, 'cover.html'),
      type: ((_ref = book._state) != null ? _ref.htmltype : void 0) || "application/xhtml+xml",
      title: 'Cover Page'
    });
  }
  if (book) {
    links.push({
      rel: 'contents',
      href: relative(page.filename, 'index.html'),
      type: ((_ref1 = book._state) != null ? _ref1.htmltype : void 0) || "application/xhtml+xml",
      title: 'Table of Contents'
    });
  }
  return links;
};

bookLinks = function() {
  return pagelinks(this, this);
};

chapterLinks = function() {
  return pagelinks(this, this.book);
};

extendChapter = function(Chapter) {
  Object.defineProperty(Chapter.prototype, 'epubManifest', {
    get: function() {
      var manifest;

      manifest = chapterTemplates.manifest(this.context());
      return manifest;
    }
  });
  Object.defineProperty(Chapter.prototype, 'links', {
    get: chapterLinks
  });
  Object.defineProperty(Chapter.prototype, 'epubSpine', {
    get: function() {
      return chapterTemplates.spine(this.context());
    }
  });
  Object.defineProperty(Chapter.prototype, 'navList', {
    get: function() {
      return chapterTemplates.nav(this.context());
    }
  });
  Object.defineProperty(Chapter.prototype, 'epubNCX', {
    get: function() {
      return chapterTemplates.ncx(this.context());
    }
  });
  Chapter.prototype.addToZip = function(zip) {
    var context, deferred, fn, promise;

    deferred = whenjs.defer();
    promise = deferred.promise;
    fn = this.filename;
    if (!this.assets) {
      context = this.context();
    } else {
      context = this;
    }
    zip.addFile(templates.chapters(context), {
      name: fn
    }, deferred.resolve);
    return promise;
  };
  return Chapter;
};

extendBook = function(Book) {
  var chapterTask;

  if (!Book.prototype.init) {
    Book.prototype.init = [];
  }
  Book.prototype.init.push(function(book) {
    return handlebars.registerHelper('relative', book.relative.bind(book));
  });
  Book.prototype.init.push(function(book) {
    return handlebars.registerHelper('isCover', book.isCover.bind(book));
  });
  Book.prototype.relative = relative;
  Book.prototype.isCover = function(path) {
    if (this.meta.cover === path) {
      return new handlebars.SafeString(' properties="cover-image"');
    } else {
      return "";
    }
  };
  Object.defineProperty(Book.prototype, 'epubManifest', {
    get: function() {
      return bookTemplates.manifest(this);
    },
    enumerable: true
  });
  Object.defineProperty(Book.prototype, 'epubSpine', {
    get: function() {
      return bookTemplates.spine(this);
    },
    enumerable: true
  });
  Object.defineProperty(Book.prototype, 'navList', {
    get: function() {
      return bookTemplates.nav(this);
    },
    enumerable: true
  });
  Object.defineProperty(Book.prototype, 'epubNCX', {
    get: function() {
      return bookTemplates.ncx(this);
    },
    enumerable: true
  });
  Object.defineProperty(Book.prototype, 'chapterIndex', {
    get: function() {
      this._chapterIndex++;
      return this._chapterIndex;
    },
    enumerable: true
  });
  Object.defineProperty(Book.prototype, 'navPoint', {
    get: function() {
      this._navPoint++;
      return this._navPoint;
    },
    enumerable: true
  });
  Object.defineProperty(Book.prototype, 'links', {
    get: bookLinks
  });
  chapterTask = function(chapter, zip) {
    return function() {
      return chapter.addToZip(zip);
    };
  };
  Book.prototype.addChaptersToZip = function(zip) {
    var chapter, context, tasks, _i, _len, _ref;

    tasks = [];
    _ref = this.chapters;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      chapter = _ref[_i];
      context = chapter.context(this);
      tasks.push(chapterTask(context, zip));
    }
    return sequence(tasks);
  };
  Object.defineProperty(Book.prototype, 'optToc', {
    get: function() {
      var doc, _i, _len, _ref, _results;

      _ref = this.chapters;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        doc = _ref[_i];
        _results.push((function(doc) {
          if (doc.toc != null) {
            return "<reference type='toc' title='Contents' href='" + doc.filename + "'></reference>";
          }
        })(doc));
      }
      return _results;
    },
    enumerable: true
  });
  Book.prototype.toEpub = toEpub;
  Object.defineProperty(Book.prototype, 'globalCounter', {
    get: function() {
      var prefix, prefre;

      prefre = new RegExp("\\/", "g");
      this._globalCounter++;
      prefix = this.assets.assetsPath.replace(prefre, "");
      return prefix + this._globalCounter;
    },
    enumerable: true
  });
  return Book;
};

addTask = function(file, name, zip, store) {
  return function() {
    var deferred, promise;

    deferred = whenjs.defer();
    promise = deferred.promise;
    deferred.notify("" + name + " written to zip");
    zip.addFile(file, {
      name: name,
      store: store
    }, deferred.resolve);
    return promise;
  };
};

addTemplateTask = function(template, book, zip, name, store) {
  return function() {
    var deferred, promise;

    deferred = whenjs.defer();
    promise = deferred.promise;
    deferred.notify("" + name + " written to zip");
    zip.addFile(template(book), {
      name: name,
      store: store
    }, deferred.resolve);
    return promise;
  };
};

toEpub = function(out, options) {
  var book, final, zip;

  book = Object.create(this);
  zip = zipStream.createZip({
    level: 1
  });
  zip.pipe(out);
  final = function() {
    var deferred, promise;

    deferred = whenjs.defer();
    promise = deferred.promise;
    deferred.notify('Writing to file...');
    zip.finalize(deferred.resolve);
    return promise;
  };
  return renderEpub(book, out, options, zip).then(final);
};

renderEpub = function(book, out, options, zip) {
  var chapterIndex, navPoint, tasks;

  book._state = {};
  book._state.htmltype = "application/xhtml+xml";
  book._navPoint = 0;
  book._chapterIndex = 0;
  navPoint = function() {
    book._navPoint++;
    return book._navPoint;
  };
  chapterIndex = function() {
    book._chapterIndex++;
    return book._chapterIndex;
  };
  handlebars.registerHelper('navPoint', navPoint);
  handlebars.registerHelper('chapterIndex', chapterIndex);
  if (options != null ? options.templates : void 0) {
    loadTemplates(options.templates + '**/*.hbs');
  }
  tasks = [];
  tasks.push(addTask("application/epub+zip", 'mimetype', zip, true));
  tasks.push(addTask('<?xml version="1.0" encoding="UTF-8"?>\n<display_options>\n  <platform name="*">\n    <option name="specified-fonts">true</option>\n  </platform>\n</display_options>', 'META-INF/com.apple.ibooks.display-options.xml', zip));
  tasks.push(addTask('<?xml version="1.0" encoding="UTF-8"?>\n  <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n    <rootfiles>\n      <rootfile full-path="content.opf" media-type="application/oebps-package+xml" />\n    </rootfiles>\n  </container>', 'META-INF/container.xml', zip));
  if (book.meta.cover) {
    tasks.push(addTemplateTask(templates.cover, book, zip, 'cover.html'));
  }
  tasks.push(addTemplateTask(templates.content, book, zip, 'content.opf'));
  tasks.push(addTemplateTask(templates.toc, book, zip, 'toc.ncx'));
  tasks.push(addTemplateTask(templates.nav, book, zip, 'index.html'));
  tasks.push(function() {
    return book.addChaptersToZip(zip);
  });
  tasks.push(function() {
    return book.assets.addToZip(zip);
  });
  if (book.sharedAssets) {
    tasks.push(function() {
      return book.sharedAssets.addToZip(zip);
    });
  }
  if (options != null ? options.assets : void 0) {
    tasks.push(function() {
      return options.assets.addToZip(zip);
    });
  }
  if ((options != null ? options.obfuscateFonts : void 0) || book.obfuscateFonts) {
    tasks.push(function() {
      return book.assets.mangleFonts(zip, book.id);
    });
  }
  return sequence(tasks);
};

extendAssets = function(Assets) {
  var mangleTask;

  mangleTask = function(item, assets, zip, id) {
    return function() {
      var deferred, promise;

      deferred = whenjs.defer();
      promise = deferred.promise;
      assets.get(item).then(function(data) {
        var file;

        deferred.notify("Writing mangled " + item + " to zip");
        file = mangler.mangle(data, id);
        return zip.addFile(file, {
          name: item
        }, deferred.resolve);
      });
      return promise;
    };
  };
  Assets.prototype.addMangledFontsToZip = function(zip, id) {
    var item, tasks, _i, _j, _k, _len, _len1, _len2, _ref, _ref1, _ref2;

    tasks = [];
    _ref = this['otf'];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      item = _ref[_i];
      tasks.push(mangleTask(item, this, zip, id));
    }
    _ref1 = this['ttf'];
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      item = _ref1[_j];
      tasks.push(mangleTask(item, this, zip, id));
    }
    _ref2 = this['woff'];
    for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
      item = _ref2[_k];
      tasks.push(mangleTask(item, this, zip, id));
    }
    return sequence(tasks);
  };
  Assets.prototype.mangleFonts = function(zip, id) {
    var fonts;

    fonts = this.ttf.concat(this.otf, this.woff);
    return this.addMangledFontsToZip(zip, id).then(function() {
      var deferred, promise;

      deferred = whenjs.defer();
      promise = deferred.promise;
      zip.addFile(templates.encryption(fonts), {
        name: 'META-INF/encryption.xml'
      }, deferred.resolve);
      return promise;
    });
  };
  return Assets;
};

module.exports = {
  extend: function(Chapter, Book, Assets) {
    extendChapter(Chapter);
    extendBook(Book);
    return extendAssets(Assets);
  },
  extendChapter: extendChapter,
  extendBook: extendBook,
  extendAssets: extendAssets
};
