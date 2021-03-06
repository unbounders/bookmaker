'use strict'

chai = require 'chai'
should = chai.should()
index = require '../src/index'
Chapter = index.Chapter
Book = index.Book

testbook = {}
testchapters =  {
  'toc': {
    id: 'nav',
    filename: 'index.html',
    render: false,
    title: 'Table of Contents',
    nomanifest: true,
    majornavitem: true,
    toc: true
  },
  'title': {
    id: 'titlepage',
    filename: 'title.html',
    title: 'Title Page',
    render: true,
    template: 'title.hbs',
    majornavitem: true
  },
  'titletoc': {
    id: 'titletoc',
    filename: 'title.html',
    title: 'Contents',
    render: true,
    template: 'titletoc.hbs',
    majornavitem: true,
    toc: true
  },
  'chapter1': {
    type: 'md'
    body: '# This is Markdown!'
  }
}

testoutline = {
  id: 'titlepage',
  filename: 'title.html',
  title: 'Title Page',
  render: true,
  template: 'title.hbs',
  majornavitem: true,
  subChapters: [
    {
      id: 'nav',
      filename: 'index.html',
      render: false,
      title: 'Table of Contents',
      nomanifest: true,
      majornavitem: true,
      toc: true
    },
    {
      id: 'titlepage',
      filename: 'title.html',
      title: 'Title Page',
      render: true,
      template: 'title.hbs',
      majornavitem: true
    },
    {
      id: 'titletoc',
      filename: 'title.html',
      title: 'Contents',
      render: true,
      template: 'titletoc.hbs',
      majornavitem: true,
      toc: true
    },
    {
      type: 'md'
      body: '# This is Markdown!'
    }]
}

describe 'Book',
  () ->
    beforeEach () ->
      testbook = new Book({
        title: 'The Wonderful Wizard of Oz',
        author: 'L. Frank Baum'})
    describe '#meta',
      () ->
        it 'should contain all of the properties of the passed meta object',
          () ->
            testbook.meta.should.have.property('title', 'The Wonderful Wizard of Oz')
            testbook.meta.should.have.property('author', 'L. Frank Baum')
    describe '#docId',
      () ->
        it 'should equal doc1, doc2, and doc3',
          () ->
            testbook.docId().should.equal('doc1')
            testbook.docId().should.equal('doc2')
            testbook.docId().should.equal('doc3')
    describe '#addChapter',
      () ->
        it 'should generate the appropriate properties but no more',
          () ->
            testchapter = new Chapter(testchapters.chapter1)
            testbook.addChapter(testchapter)
            testbook.chapters[0].should.have.property('body', '# This is Markdown!')
            testbook.chapters[0].should.have.property('type', 'md')
            testbook.chapters[0].should.have.property('id', 'doc1')
            testbook.chapters[0].should.have.property('filename', 'chapters/doc1.html')
            testbook.chapters[0].should.not.have.property('title')
