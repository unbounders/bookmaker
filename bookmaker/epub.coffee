'use strict'

zipStream = require('zipstream-contentment')
handlebars = require('handlebars')
helpers = require('./lib/hbs.js')
whenjs = require('when')
callbacks = require 'when/callbacks'
# templates = require '../lib/templates'
path = require('path')
glob = require 'glob'
fs = require 'fs'
mangler = require './lib/mangler'
sequence = require('when/sequence')
_ = require 'underscore'
temp = require './templates'
templates = temp.templates
loadTemplates = temp.loadTemplates
utilities = require './utilities'

# landmarksOPF -> returns all guide reference for the OPF
# landmarksHTML -> returns all landmarks for index nav.
# Labels are chapters that lack a filename and generate no spine, ncx, or manifest entries.

chapterTemplates = {
  manifest: '''{{#if this.nomanifest }}
    {{else}}{{#if filename }}<item id="{{ id }}" href="{{ filename }}" media-type="application/xhtml+xml" properties="{{#if svg }}svg {{/if}}{{#if scripted }}scripted{{/if}}"/>\n{{/if}}{{#if subChapters.epubManifest}}
    {{ subChapters.epubManifest }}{{/if}}{{/if}}'''
  spine: '''{{#if filename }}<itemref idref="{{ id }}" linear="yes"></itemref>\n{{/if}}{{#if subChapters.epubManifest}}
    {{ subChapters.epubSpine }}{{/if}}'''
  nav: '''<li class="tocitem {{ id }}{{#if majornavitem}} majornavitem{{/if}}" id="toc-{{ id }}">{{#if filename }}<a href="{{ filename }}" rel="chapter">{{/if}}{{ title }}{{#if filename }}</a>\n{{/if}}
{{ subChapters.navList }}
</li>\n'''
  ncx: '''
{{#if filename }}<navPoint id="navPoint-{{ navPoint }}" playOrder="{{ chapterIndex }}">
  <navLabel>
      <text>{{ title }}</text>
  </navLabel>
  <content src="{{ filename }}"></content>
{{ subChapters.epubNCX }}</navPoint>{{else}}
 {{ subChapters.epubNCX }}
{{/if}}'''
}

bookTemplates = {
  manifest: '{{#each chapters }}{{{ this.epubManifest }}}{{/each}}'
  spine: '{{#each chapters }}{{{ this.epubSpine }}}{{/each}}'
  nav: '{{#each chapters }}{{{ this.navList }}}{{/each}}'
  ncx: '{{#each chapters }}{{{ this.epubNCX }}}{{/each}}'
}

for own tempname, template of chapterTemplates
  chapterTemplates[tempname] = handlebars.compile template

for tempname, template of bookTemplates
  bookTemplates[tempname] = handlebars.compile template

relative = utilities.relative

pagelinks = utilities.pageLinks


bookLinks = () ->
  pagelinks(this, this)

chapterLinks = () ->
  pagelinks(this, @book)

extendChapter = (Chapter) ->
  Object.defineProperty Chapter.prototype, 'epubManifest', {
    get: ->
      manifest = chapterTemplates.manifest(@context())
      return manifest
  }

  Object.defineProperty Chapter.prototype, 'links', {
    get: chapterLinks
  }
  Object.defineProperty Chapter.prototype, 'epubSpine', {
    get: ->
      chapterTemplates.spine(@context())
  }

  Object.defineProperty Chapter.prototype, 'navList', {
    get: ->
      chapterTemplates.nav(@context())
  }

  Object.defineProperty Chapter.prototype, 'epubNCX', {
    get: ->
      chapterTemplates.ncx(@context())
  }

  Chapter.prototype.addToZip = (zip) ->
    deferred = whenjs.defer()
    promise = deferred.promise
    fn = @filename
    if !@assets
      context = @context()
    else
      context = this
    zip.addFile(templates.chapters(context), { name: fn }, deferred.resolve)
    return promise
  return Chapter

extendBook = (Book) ->
  Book.prototype.init = [] unless Book.prototype.init
  Book.prototype.init.push((book) -> handlebars.registerHelper 'relative', book.relative.bind(book))
  Book.prototype.init.push((book) -> handlebars.registerHelper 'isCover', book.isCover.bind(book))
  Book.prototype.relative = relative
  Book.prototype.isCover = (path) ->
    if @meta.cover is path
      return new handlebars.SafeString(' properties="cover-image"')
    else
      return ""
  Object.defineProperty Book.prototype, 'epubManifest', {
    get: ->
      bookTemplates.manifest(this)
    enumerable: true
  }

  Object.defineProperty Book.prototype, 'epubSpine', {
    get: ->
      bookTemplates.spine(this)
    enumerable: true
  }

  Object.defineProperty Book.prototype, 'navList', {
    get: ->
      bookTemplates.nav(this)
    enumerable: true
  }

  Object.defineProperty Book.prototype, 'epubNCX', {
    get: ->
      bookTemplates.ncx(this)
    enumerable: true
  }
  Object.defineProperty Book.prototype, 'chapterIndex', {
    get: ->
      @_chapterIndex++
      return @_chapterIndex
    enumerable: true
  }
  Object.defineProperty Book.prototype, 'navPoint', {
    get: ->
      @_navPoint++
      return @_navPoint
    enumerable: true
  }

  Object.defineProperty Book.prototype, 'links', {
    get: bookLinks
  }

  chapterTask = (chapter, zip) ->
    return () ->
      chapter.addToZip(zip)
  Book.prototype.addChaptersToZip = (zip) ->
    tasks = []
    for chapter in @chapters
      context = chapter.context(this)
      tasks.push(chapterTask(context, zip))
    sequence(tasks)


  Object.defineProperty Book.prototype, 'optToc', {
    get: ->
      for doc in @chapters
        do (doc) ->
          if doc.toc?
            return "<reference type='toc' title='Contents' href='#{doc.filename}'></reference>"
    enumerable: true
  }
  Book.prototype.toEpub = toEpub
  Object.defineProperty Book.prototype, 'globalCounter', {
    get: ->
      prefre = new RegExp("\\/", "g")
      @_globalCounter++
      prefix = @assets.assetsPath.replace(prefre, "")
      return prefix + @_globalCounter
    enumerable: true
  }

  return Book


addTask = (file, name, zip, store) ->
  return () ->
    deferred = whenjs.defer()
    promise = deferred.promise
    deferred.notify "#{name} written to zip"
    zip.addFile(file, { name: name, store: store }, deferred.resolve)
    return promise
# addFsTask = (path, name, zip, store) ->
#   return () ->
#     deferred = whenjs.defer()
#     promise = deferred.promise
#     fs.readFile(path, (err, data) ->
#       if err
#         deferred.reject
#       else
#         deferred.notify "#{name} written to zip"
#         zip.addFile(data, { name: name, store: store }, deferred.resolve))
#     return promise
addTemplateTask = (template, book, zip, name, store) ->
  return () ->
    deferred = whenjs.defer()
    promise = deferred.promise
    deferred.notify "#{name} written to zip"
    zip.addFile(template(book), { name: name, store: store }, deferred.resolve)
    return promise

toEpub = (out, options) ->
  book = Object.create this
  zip = zipStream.createZip({ level: 1 })
  zip.pipe(out)
  final = () ->
    deferred = whenjs.defer()
    promise = deferred.promise
    deferred.notify 'Writing to file...'
    zip.finalize(deferred.resolve)
    return promise
  renderEpub(book, out, options, zip).then(final)

renderEpub = (book, out, options, zip) ->
  book._state = {}
  book._state.htmltype = "application/xhtml+xml"
  book._navPoint = 0
  book._chapterIndex = 0
  navPoint = ->
    book._navPoint++
    return book._navPoint
  chapterIndex = ->
    book._chapterIndex++
    return book._chapterIndex
  handlebars.registerHelper 'navPoint', navPoint
  handlebars.registerHelper 'chapterIndex', chapterIndex
  if options?.templates
    loadTemplates(options.templates + '**/*.hbs')
  # if book.assets.js
  #   book.scripted = true
  tasks = []
  tasks.push(addTask("application/epub+zip", 'mimetype', zip, true))
  tasks.push(addTask('''
      <?xml version="1.0" encoding="UTF-8"?>
      <display_options>
        <platform name="*">
          <option name="specified-fonts">true</option>
        </platform>
      </display_options>
      ''', 'META-INF/com.apple.ibooks.display-options.xml', zip))
  tasks.push(addTask('''
    <?xml version="1.0" encoding="UTF-8"?>
      <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
        <rootfiles>
          <rootfile full-path="content.opf" media-type="application/oebps-package+xml" />
        </rootfiles>
      </container>
      ''', 'META-INF/container.xml', zip))
  if book.meta.cover
    tasks.push(addTemplateTask(templates.cover, book, zip, 'cover.html'))
  tasks.push(addTemplateTask(templates.content, book, zip, 'content.opf'))
  tasks.push(addTemplateTask(templates.toc, book, zip, 'toc.ncx'))
  tasks.push(addTemplateTask(templates.nav, book, zip, 'index.html'))
  tasks.push(() -> book.addChaptersToZip(zip))
  tasks.push(() -> book.assets.addToZip(zip))
  if book.sharedAssets
    tasks.push(() -> book.sharedAssets.addToZip(zip))
  if options?.assets
    tasks.push(() -> options.assets.addToZip(zip))
  if options?.obfuscateFonts or book.obfuscateFonts
    tasks.push(() -> book.assets.mangleFonts(zip, book.id))
  sequence(tasks)

extendAssets = (Assets) ->
  mangleTask = (item, assets, zip, id) ->
    return () ->
      deferred = whenjs.defer()
      promise = deferred.promise
      assets.get(item).then((data) ->
        deferred.notify "Writing mangled #{item} to zip"
        file = mangler.mangle(data, id)
        zip.addFile(file, { name: item }, deferred.resolve))
      return promise

  Assets.prototype.addMangledFontsToZip = (zip, id) ->
    tasks = []
    for item in this['otf']
      tasks.push(mangleTask(item, this, zip, id))
    for item in this['ttf']
      tasks.push(mangleTask(item, this, zip, id))
    for item in this['woff']
      tasks.push(mangleTask(item, this, zip, id))
    sequence tasks
  Assets.prototype.mangleFonts = (zip, id) ->
    fonts = @ttf.concat(@otf, @woff)
    @addMangledFontsToZip(zip, id).then(()->
      deferred = whenjs.defer()
      promise = deferred.promise
      zip.addFile(templates.encryption(fonts), { name: 'META-INF/encryption.xml' }, deferred.resolve)
      return promise)
  return Assets

module.exports = {
  extend: (Chapter, Book, Assets) ->
    extendChapter Chapter
    extendBook Book
    extendAssets Assets
  extendChapter: extendChapter
  extendBook: extendBook
  extendAssets: extendAssets
}