// Generated by CoffeeScript 1.4.0
(function() {
  var $, Backbone, Buffer, DROWSY_URL, Drowsy, TEST_COLLECTION, TEST_DB, WEASEL_URL, btoa, should, _,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  if (typeof window !== "undefined" && window !== null) {
    $ = window.$;
    _ = window._;
    should = window.should;
    Backbone = window.Backbone;
    Drowsy = window.Drowsy;
    DROWSY_URL = window.DROWSY_URL;
    WEASEL_URL = window.WEASEL_URL;
  } else {
    $ = require('jquery');
    _ = require('underscore');
    Backbone = require('backbone');
    Backbone.$ = $;
    should = require('chai').should();
    Drowsy = require('../backbone.drowsy').Drowsy;
    DROWSY_URL = process.env.DROWSY_URL;
    WEASEL_URL = process.env.WEASEL_URL;
  }

  /*
  NOTE: These tests are done against a live DrowsyDromedary instance!
  */


  if (DROWSY_URL == null) {
    DROWSY_URL = "http://localhost:9292/";
  }

  TEST_DB = 'drowsy_test';

  TEST_COLLECTION = 'tests';

  if ((typeof TEST_USERNAME !== "undefined" && TEST_USERNAME !== null) && (typeof TEST_PASSWORD !== "undefined" && TEST_PASSWORD !== null)) {
    Buffer = require('buffer').Buffer;
    btoa = function(str) {
      return (new Buffer(str || "", "ascii")).toString("base64");
    };
    Backbone.$.ajaxSetup({
      beforeSend: function(xhr) {
        return xhr.setRequestHeader('Authorization', 'Basic ' + btoa(TEST_USERNAME + ':' + TEST_PASSWORD));
      }
    });
  }

  if (DROWSY_URL == null) {
    console.error("DROWSY_URL must point to a DrowsyDromedary server!");
  }

  describe('Drowsy', function() {
    this.timeout(5000);
    before(function(done) {
      var createTestCollection,
        _this = this;
      createTestCollection = function() {
        var db;
        db = _this.server.database(TEST_DB);
        return db.collections().done(function(colls) {
          if (__indexOf.call(_.pluck(colls, 'name'), TEST_COLLECTION) >= 0) {
            return done();
          } else {
            return db.createCollection(TEST_COLLECTION).done(function() {
              return done();
            });
          }
        });
      };
      this.server = new Drowsy.Server(DROWSY_URL);
      return this.server.databases().done(function(dbs) {
        if (__indexOf.call(_.pluck(dbs, 'name'), TEST_DB) >= 0) {
          return createTestCollection();
        } else {
          return _this.server.createDatabase(TEST_DB).done(createTestCollection);
        }
      });
    });
    describe(".generateMongoObjectId", function() {
      return it("should generate a 24-character hex string", function() {
        var id;
        id = Drowsy.generateMongoObjectId();
        return id.should.match(/^[0-9a-f]{24}$/);
      });
    });
    describe('Drowsy.Server', function() {
      describe('#url', function() {
        return it("should strip the trailing slash off the URL", function() {
          return this.server.url().slice(-1).should.not.equal('/');
        });
      });
      describe('#database', function() {
        return it("should return a new Drowsy.Database object with the given name", function() {
          var db;
          db = this.server.database(TEST_DB);
          db.should.be.an.instanceOf(Drowsy.Database);
          db.name.should.equal(TEST_DB);
          db.url.should.match(new RegExp("^" + DROWSY_URL));
          return db.url.should.match(new RegExp("" + TEST_DB + "$"));
        });
      });
      return describe('#databases', function() {
        return it("should retrieve a list of all databases from the remote server as Drowsy.Database objects", function(done) {
          return this.server.databases(function(dbs) {
            dbs[0].should.be.an.instanceOf(Drowsy.Database);
            dbs[0].name.should.not.be.empty;
            _.pluck(dbs, 'name').should.include(TEST_DB);
            return done();
          });
        });
      });
    });
    describe('Drowsy.Database', function() {
      before(function() {
        this.server = new Drowsy.Server(DROWSY_URL);
        return this.db = new Drowsy.Database(this.server, TEST_DB);
      });
      describe('constructor', function() {
        it("should assign a url based on the given server and dbName", function() {
          var db;
          db = new Drowsy.Database(this.server, TEST_DB);
          return db.url.should.equal(DROWSY_URL.replace(/\/$/, '') + "/" + TEST_DB);
        });
        it("should be able to take a url as first argument", function() {
          var _this = this;
          return (function() {
            var db;
            return db = new Drowsy.Database(DROWSY_URL, TEST_DB);
          }).should.not["throw"](/url/);
        });
        return it("should be able to take a Drowsy.Server instance as the first argument", function() {
          var _this = this;
          return (function() {
            var db;
            return db = new Drowsy.Database(_this.server, TEST_DB);
          }).should.not["throw"](/url/);
        });
      });
      describe('#collections', function() {
        it("should retrieve a list of Drowsy.Collection instances", function(done) {
          return this.db.collections(function(colls) {
            (colls.length > 0).should.equal(true);
            _.each(colls, function(coll) {
              return coll.should.be.an.instanceOf(Drowsy.Collection);
            });
            _.pluck(colls, 'name').should.include(TEST_COLLECTION);
            return done();
          });
        });
        return it("should instantiate Drowsy.Collection instances with valid urls and collectionNames", function(done) {
          return this.db.collections(function(colls) {
            _.each(colls, function(coll) {
              coll.url.should.not.match(/undefined/);
              return coll.name.should.exist;
            });
            return done();
          });
        });
      });
      describe('#createCollection', function() {
        it("should create the given collection in this database", function(done) {
          return this.db.createCollection(TEST_COLLECTION, function(result) {
            result.should.match(/created|already_exists/);
            return done();
          });
        });
        return it("should return a deferred and resolve to 'created' or 'already_exists'", function(done) {
          return this.db.createCollection(TEST_COLLECTION).always(function(result, xhr) {
            result.should.match(/created|already_exists/);
            this.state().should.equal('resolved');
            return done();
          });
        });
      });
      describe("#Document", function() {
        it("should return a Drowsy.Document class with the given collectionName", function() {
          var TestDocument, doc;
          TestDocument = (function(_super) {

            __extends(TestDocument, _super);

            function TestDocument() {
              return TestDocument.__super__.constructor.apply(this, arguments);
            }

            return TestDocument;

          })(this.db.Document(TEST_COLLECTION));
          doc = new TestDocument();
          return doc.collectionName.should.equal(TEST_COLLECTION);
        });
        return it("should return a Drowsy.Document class with a valid URL", function() {
          var TestDocument, doc;
          TestDocument = (function(_super) {

            __extends(TestDocument, _super);

            function TestDocument() {
              return TestDocument.__super__.constructor.apply(this, arguments);
            }

            return TestDocument;

          })(this.db.Document(TEST_COLLECTION));
          doc = new TestDocument();
          console.log(doc.url());
          return doc.url().should.match(new RegExp("^" + DROWSY_URL.replace(/\/$/, '') + "/" + TEST_DB + "/" + TEST_COLLECTION + "/" + "[0-9a-f]+" + "$"));
        });
      });
      return describe("#Collection", function() {
        it("should return a Drowsy.Collection class with the given collectionName", function() {
          var TestCollection, coll;
          TestCollection = (function(_super) {

            __extends(TestCollection, _super);

            function TestCollection() {
              return TestCollection.__super__.constructor.apply(this, arguments);
            }

            return TestCollection;

          })(this.db.Collection(TEST_COLLECTION));
          coll = new TestCollection();
          return coll.name.should.equal(TEST_COLLECTION);
        });
        return it("should return a Drowsy.Collection class with a valid URL", function() {
          var TestCollection, coll;
          TestCollection = (function(_super) {

            __extends(TestCollection, _super);

            function TestCollection() {
              return TestCollection.__super__.constructor.apply(this, arguments);
            }

            return TestCollection;

          })(this.db.Collection(TEST_COLLECTION));
          coll = new TestCollection();
          console.log(coll.url);
          return coll.url.should.match(new RegExp("^" + DROWSY_URL.replace(/\/$/, '') + "/" + TEST_DB + "/" + TEST_COLLECTION + "$"));
        });
      });
    });
    describe('Drowsy.Document', function() {
      describe("#parse", function() {
        it("should deal with ObjectID encoded as {$oid: '...'}", function() {
          var data, doc, parsed;
          data = JSON.parse('{"_id": {"$oid": "50f7875a1b85e10000000003"}, "foo": "bar"}');
          doc = new Drowsy.Document();
          parsed = doc.parse(data);
          parsed._id.should.equal("50f7875a1b85e10000000003");
          return parsed.foo.should.equal("bar");
        });
        it("should deal with ObjectID encoded as a plain string (without $oid)", function() {
          var data, doc, parsed;
          data = JSON.parse('{"_id": "50f7875a1b85e10000000003", "foo": "bar"}');
          doc = new Drowsy.Document();
          parsed = doc.parse(data);
          parsed._id.should.equal("50f7875a1b85e10000000003");
          return parsed.foo.should.equal("bar");
        });
        it("should deal with ISODates encoded as {$date: '...'}", function() {
          var data, doc, parsed;
          data = JSON.parse('{\
                        "_id": {"$oid": "50f7875a1b85e10000000003"}, \
                        "foo": "bar",\
                        "date1": { "$date": "2013-01-17T05:08:42.537Z" },\
                        "meh": {\
                            "date2": { "$date": "2013-01-24T02:01:35.151Z"}, \
                            "joo": 55555\
                        }\
                    }');
          doc = new Drowsy.Document();
          parsed = doc.parse(data);
          parsed._id.should.equal("50f7875a1b85e10000000003");
          parsed.foo.should.equal("bar");
          (parsed.date1 instanceof Date).should.be["true"];
          parsed.date1.getTime().should.equal((new Date("2013-01-17T05:08:42.537Z")).getTime());
          (parsed.date1 instanceof Date).should.be["true"];
          return parsed.meh.date2.getTime().should.equal((new Date("2013-01-24T02:01:35.151Z")).getTime());
        });
        it("should deal with ISODates encoded as {$date: '...'} in an Array", function() {
          var data, doc, parsed, theDate;
          data = JSON.parse('{\
                        "_id": {"$oid": "50f7875a1b85e10000000003"}, \
                        "array_of_dates": [{ "$date": "2013-01-17T05:08:42.537Z" }, { "$date": "2013-01-17T05:08:42.537Z" }],\
                        "array_of_objs_with_dates": [{"foo": { "$date": "2013-01-17T05:08:42.537Z" }}, {"foo": { "$date": "2013-01-17T05:08:42.537Z" }}]\
                    }');
          doc = new Drowsy.Document();
          parsed = doc.parse(data);
          theDate = new Date("2013-01-17T05:08:42.537Z");
          parsed._id.should.equal("50f7875a1b85e10000000003");
          parsed.array_of_dates[0].should.eql(theDate);
          parsed.array_of_dates[1].should.eql(theDate);
          parsed.array_of_objs_with_dates[0].foo.should.eql(theDate);
          return parsed.array_of_objs_with_dates[1].foo.should.eql(theDate);
        });
        it("should parse an array value as an array rather than an object", function() {
          var data, doc, parsed;
          data = JSON.parse('{\
                        "_id": {"$oid": "50f7875a1b85e10000000003"}, \
                        "foo": "bar",\
                        "arr": [\
                            {"foo": "bar"},\
                            {"joo": "gar"}\
                        ],\
                        "obj": {\
                            "0": {"foo": "bar"},\
                            "1": {"joo": "gar"}\
                        }\
                    }');
          doc = new Drowsy.Document();
          parsed = doc.parse(data);
          parsed.arr.should.be.an('array');
          parsed.arr[1].joo.should.equal('gar');
          parsed.obj.should.be.an('object');
          return parsed.obj[1].joo.should.equal('gar');
        });
        it("should parse an object with a keys with null values", function() {
          var data, doc, parsed;
          data = JSON.parse('{\
                        "_id": {"$oid": "50f7875a1b85e10000000003"}, \
                        "null1": null,\
                        "obj": {\
                            "foo": {"foo": "bar"},\
                            "bar": {"null2": null}\
                        }\
                    }');
          doc = new Drowsy.Document();
          parsed = doc.parse(data);
          should.not.exist(parsed.null1);
          return should.not.exist(parsed.obj.bar.null2);
        });
        return it("should parse an empty collection", function() {
          var coll, data, parsed;
          data = JSON.parse('[]');
          coll = new Drowsy.Collection();
          return parsed = coll.parse(data);
        });
      });
      describe("#toJSON", function() {
        it("should NOT convert _id to {$oid: '...'}", function() {
          var doc, json;
          doc = new Drowsy.Document();
          doc.set('_id', "000000000000000000000001");
          doc.id.should.equal("000000000000000000000001");
          json = doc.toJSON();
          return json._id.should.equal("000000000000000000000001");
        });
        it("should convert Dates to {$date: '...'}", function() {
          var doc, json;
          doc = new Drowsy.Document();
          doc.set('foo', new Date("2013-01-17T05:08:42.537Z"));
          doc.set('faa', {
            'another': new Date("2013-01-24T02:01:35.151Z")
          });
          doc.set('fee', 'non-date value');
          doc.set('boo', {});
          json = doc.toJSON();
          json.foo.should.eql({
            "$date": "2013-01-17T05:08:42.537Z"
          });
          json.faa.another.should.eql({
            "$date": "2013-01-24T02:01:35.151Z"
          });
          json.fee.should.equal("non-date value");
          return json.boo.should.eql({});
        });
        return it("should convert Dates to {$date: '...'} when they're inside arrays", function() {
          var doc, json, theDate;
          doc = new Drowsy.Document();
          theDate = new Date("2013-01-24T02:01:35.151Z");
          doc.set('array_of_dates', [theDate, theDate]);
          doc.set('array_of_objs_with_dates', [
            {
              foo: theDate
            }, {
              foo: theDate
            }
          ]);
          json = doc.toJSON();
          json.array_of_dates[0].should.eql({
            "$date": "2013-01-24T02:01:35.151Z"
          });
          json.array_of_dates[1].should.eql({
            "$date": "2013-01-24T02:01:35.151Z"
          });
          json.array_of_objs_with_dates[0].should.eql({
            foo: {
              "$date": "2013-01-24T02:01:35.151Z"
            }
          });
          return json.array_of_objs_with_dates[1].should.eql({
            foo: {
              "$date": "2013-01-24T02:01:35.151Z"
            }
          });
        });
      });
      return describe("#save", function() {
        return it("should upsert using a client-side generated ObjectID", function(done) {
          var MyDoc, doc;
          this.server = new Drowsy.Server(DROWSY_URL);
          this.db = new Drowsy.Database(this.server, TEST_DB);
          MyDoc = (function(_super) {

            __extends(MyDoc, _super);

            function MyDoc() {
              return MyDoc.__super__.constructor.apply(this, arguments);
            }

            return MyDoc;

          })(this.db.Document(TEST_COLLECTION));
          doc = new MyDoc();
          console.log("Doc URL is:", doc.url());
          return doc.save({}, {
            success: function(data, status, xhr) {},
            error: function(data, xhr) {
              console.log(xhr);
              return console.log("Doc save error:", JSON.parse(xhr.responseText).error);
            },
            complete: function(xhr, status) {
              xhr.status.should.equal(200);
              return done();
            }
          });
        });
      });
    });
    return describe('Drowsy.Collection', function() {});
  });

}).call(this);
