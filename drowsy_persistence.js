// Generated by CoffeeScript 1.7.1
(function() {
  var DrowsyPersistence, events, http,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  http = require('http');

  events = require('events');

  DrowsyPersistence = (function(_super) {
    var actionMethodMap;

    __extends(DrowsyPersistence, _super);

    function DrowsyPersistence(config) {
      this.config = config;
    }

    DrowsyPersistence.prototype.added = function() {
      return console.log("Drowsy persistence enabled. Broadcasts will be saved to " + (this.drowsyUrl()) + " ...");
    };

    DrowsyPersistence.prototype.incoming = function(message, callback) {
      var cb2;
      return callback(message);
      if (message.channel.match(/^\/meta\//)) {
        return callback(message);
      }
      cb2 = function(message) {
        console.log("Calling callback!");
        return callback(message);
      };
      return this.persistInDrowsy(message, cb2);
    };

    actionMethodMap = {
      create: 'POST',
      update: 'PUT',
      patch: 'PATCH',
      "delete": 'DELETE'
    };

    DrowsyPersistence.prototype.persistInDrowsy = function(message, callback) {
      var channel, cid, data, json, req, reqOpts, _ref, _ref1;
      cid = message.clientId;
      channel = message.channel;
      data = message.data;
      reqOpts = {
        hostname: (_ref = this.config.hostname) != null ? _ref : 'localhost',
        port: (_ref1 = this.config.port) != null ? _ref1 : 9292,
        path: channel,
        method: actionMethodMap[data.action]
      };
      req = http.request(reqOpts, (function(_this) {
        return function(res) {
          var _i, _ref2, _results;
          if (_ref2 = res.statusCode, __indexOf.call((function() {
            _results = [];
            for (_i = 200; _i < 299; _i++){ _results.push(_i); }
            return _results;
          }).apply(this), _ref2) >= 0) {
            _this.emit('persist_success', cid, channel, data, res);
          } else {
            _this.emit('persist_failure', cid, channel, data, res);
            message.error = "Failed to persist data in Drowsy; Drowsy responded with a " + res.statusCode;
          }
          return callback(message);
        };
      })(this));
      req.on('error', (function(_this) {
        return function(err) {
          var errMsg;
          _this.emit('persist_failure', cid, channel, data, err);
          errMsg = "\n\n!!! Error while sending request to Drowsy! Is the Drowsy server up and running at " + (_this.drowsyUrl()) + "?\n " + (err.toString());
          console.error(errMsg);
          message.error = errMsg;
          callback(message);
          throw err;
        };
      })(this));
      json = JSON.stringify(data.data);
      req.setHeader('content-type', 'application/json');
      req.setHeader('content-length', json.length);
      req.write(json);
      return req.end;
    };

    DrowsyPersistence.prototype.drowsyUrl = function() {
      return "http://" + this.config.hostname + ":" + this.config.port;
    };

    return DrowsyPersistence;

  })(events.EventEmitter);

  exports.DrowsyPersistence = DrowsyPersistence;

}).call(this);
