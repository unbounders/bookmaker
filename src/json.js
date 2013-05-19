'use strict';
var Assets, Book, Chapter, SubOutline, bookmaker, fs, path, sequence, whenjs, _;

fs = require('fs');

bookmaker = require('./index');

Assets = bookmaker.Assets;

Chapter = bookmaker.Chapter;

Book = bookmaker.Book;

SubOutline = bookmaker.SubOutline;

whenjs = require('when');

_ = require('underscore');

path = require('path');

sequence = require('when/sequence');