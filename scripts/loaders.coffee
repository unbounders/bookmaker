'use strict'

fs = require('fs')
path = require('path')
yaml = require('js-yaml')
utilities = require './utilities'
logger = require('./logger')

class LoaderMixin
  @loadBookDir = (directory) ->
    titlecounter = 0
    titlere = new RegExp('^# (.+)', 'm')
    stripre = new RegExp('\\W', 'g')
    mdchaptergen = (chapter) ->
      title = titlere.exec(chapter)?[1]
      if title
        return { title: title, body: chapter }
      else
        titlecounter += 1
        title = titlecounter + ""
        return { title: title, body: "# #{title}\n\n" + chapter }
    Chapter = @Chapter
    Book = this
    Assets = @Assets
    loadFile = (filename, book) ->
      if fs.existsSync path.resolve(directory, 'chapters', filename)
        file = fs.readFileSync(path.resolve(directory, 'chapters', filename), 'utf8')
      type = path.extname(filename).replace(".","")
      if type is 'md'
        doc = mdchaptergen(file)
      else
        docs = file.split('---')
        doc = yaml.safeLoad docs[1]
        doc.body = docs[2] if docs[2]?
      doc.type = type
      basepath = path.basename filename, path.extname filename
      doc.filename = 'chapters/' + basepath + '.html'
      book.addChapter(new Chapter(doc))
    loadTxt = (booktxt, book) ->
      list = booktxt.trim().split(/\n/)
      emptyline = /^\s$/
      for filename in list
        if (filename[0] is '#') or (filename.match(emptyline))
          # Do nothing
        else
          filename = filename.trim()
          loadFile(filename, book)
      logger.log.info 'BOOKDIR – chapters loaded'
      return book
    if fs.existsSync path.resolve(directory,'meta.yaml')
      meta = yaml.safeLoad fs.readFileSync path.resolve(directory,'meta.yaml'), 'utf8'
    else if fs.existsSync directory + 'meta.json'
      meta = JSON.parse fs.readFileSync directory + 'meta.json', 'utf8'
    else
      return
    logger.log.info 'BOOKDIR – Metadata loaded'
    if meta.assetsPath
      assets = new Assets(directory, meta.assetsPath)
    else
      assets = new Assets(directory, 'assets/')
    logger.log.info 'BOOKDIR – Assets prepared'
    NewBook = this
    book = new NewBook(meta, assets)
    if fs.existsSync path.resolve(directory, 'book.txt')
      booktxt = fs.readFileSync path.resolve(directory, 'book.txt'), 'utf8'
    else
      return
    loadTxt(booktxt, book)
    if book.meta.start
      unless book.meta.landmarks
        book.meta.landmarks = []
        for chapter in book.chapters
          if chapter.filename is book.meta.start
            book.meta.landmarks.push({ type: "bodymatter", title: chapter.title, href: chapter.filename })
    return book

extend = (Book) ->
  utilities.mixin Book, LoaderMixin

module.exports = {
  extend: extend
  LoaderMixin: LoaderMixin
}