// Generated by CoffeeScript 1.4.0
(function() {
  var MOUNT, PORT, bayeux, faye, http;

  http = require('http');

  faye = require('faye');

  PORT = 7777;

  MOUNT = '/faye';

  console.log("Waking the Weasel...");

  bayeux = new faye.NodeAdapter({
    mount: MOUNT,
    timeout: 45
  });

  bayeux.bind('handshake', function(cid) {
    return console.log("" + (Date.now()) + " O " + cid);
  });

  bayeux.bind('subscribe', function(cid, channel) {
    return console.log("" + (Date.now()) + " + " + cid + " " + channel);
  });

  bayeux.bind('unsubscribe', function(cid, channel) {
    return console.log("" + (Date.now()) + " - " + cid + " " + channel);
  });

  bayeux.bind('publish', function(cid, channel, data) {
    return console.log("" + (Date.now()) + " > " + cid + " " + channel, data);
  });

  bayeux.bind('disconnect', function(cid, channel, data) {
    return console.log("" + (Date.now()) + " X " + cid);
  });

  bayeux.listen(PORT);

  console.log("... awake and listening on http://localhost:" + PORT + MOUNT);

}).call(this);
