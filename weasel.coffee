http = require('http')
faye = require('faye')
fs = require('fs')
events = require('events')

DrowsyPersistence = require('./drowsy_persistence').DrowsyPersistence
MQTTRelay = require('./mqtt_relay').MQTTRelay

argv = require('optimist')
  .usage('Usage:\n\t$0 [-c config.json]')
  .argv

if argv.c?
    CONFIG = argv.c
else
    CONFIG = './config.json'

class Weasel extends events.EventEmitter
  setupLogging: () ->
    @bayeux.bind 'handshake', (cid) ->
      console.log "#{Date.now()} [handshk] #{cid}"
    @bayeux.bind 'subscribe', (cid, channel) ->
      console.log "#{Date.now()} [sub       ] #{cid} #{channel}"
    @bayeux.bind 'unsubscribe', (cid, channel) ->
      console.log "#{Date.now()} [unsub     ] #{cid} #{channel}"
    @bayeux.bind 'publish', (cid, channel, data) ->
      console.log "#{Date.now()} [pub       ] #{cid} #{channel}", data
    @bayeux.bind 'disconnect', (cid, channel, data) ->
      console.log "#{Date.now()} [disconnect] #{cid}"

    @on 'drowsy.persist_success', (cid, channel, data, res) ->
      console.log "#{Date.now()} [drwsy.save] #{cid} #{channel} (#{res.statusCode})"
    @on 'drowsy.persist_failure', (cid, channel, data, res) ->
      console.warn "#{Date.now()} [drwsy.fail] #{cid} #{channel} (#{res.statusCode})"

    @on 'mqtt.connect', (brokerUrl, clientOpts) =>
      console.log "#{Date.now()} [mqtt.conn  ] #{brokerUrl}", clientOpts
    @on 'mqtt.receive', (topic, payload) =>
      console.log "#{Date.now()} [mqtt.receiv] #{topic}", payload
    @on 'mqtt.pub_success', (topic, payload, opts) =>
      console.log "#{Date.now()} [mqtt.pub   ] #{topic}", payload, opts
    @on 'mqtt.sub_success', (topic, clientId, opts) =>
      console.log "#{Date.now()} [mqtt.sub   ] #{topic} #{clientId}"
    @on 'mqtt.sub_skip', (topic, clientId) =>
      console.log "#{Date.now()} [mqtt.subskp] #{topic} #{clientId}"
    @on 'mqtt.sub_failure', (topic, clientId, opts, err) =>
      console.log "#{Date.now()} [mqtt.suberr] #{topic} #{clientId}", err

  setupDrowsyPersistence: ->
    if @config.drowsy
      drowsy = new DrowsyPersistence @config.drowsy

      drowsy.on 'persist_success', (cid, channel, data, res) =>
        @emit 'drowsy.persist_success', cid, channel, data, res
      drowsy.on 'persist_failure', (cid, channel, data, res) =>
        @emit 'drowsy.persist_failure', cid, channel, data, res

      @bayeux.addExtension drowsy
    else
      console.warn "Drowsy persistence will be disabled because no 'drowsy' config was provided."
      return

  setupMQTTRelay: ->
    if @config.mqtt
      mqtt = new MQTTRelay @config.mqtt, @bayeux

      mqtt.on 'connect', (brokerUrl, clientOpts) =>
        @emit 'mqtt.connect', brokerUrl, clientOpts
      mqtt.on 'receive', (topic, payload) =>
        @emit 'mqtt.receive', topic, payload
      mqtt.on 'pub_success', (topic, payload, opts) =>
        @emit 'mqtt.pub_success', topic, payload, opts
      mqtt.on 'sub_success', (topic, clientId, opts) =>
        @emit 'mqtt.sub_success', topic, clientId, opts
      mqtt.on 'sub_skip', (topic, clientId) =>
        @emit 'mqtt.sub_skip', topic, clientId
      mqtt.on 'sub_failure', (topic, clientId, opts, err) =>
        @emit 'mqtt.sub_failure', topic, clientId, opts, err

      @bayeux.addExtension mqtt
    else
      console.warn "MQTT relay will be disabled because no 'mqtt' config was provided."

  loadConfig: ->
    defaults =
      port: 7777
      mount: '/faye'
      timeout: 30

    configPath = CONFIG

    if fs.existsSync(configPath)
      config = JSON.parse fs.readFileSync(configPath)

      for key,val of defaults
        config[key] ?= defaults[key]

      console.log "Configuration loaded from '#{CONFIG}':", config
    else
      config = defaults
      console.warn "Configuration file '#{CONFIG}' not found! Using defaults:", config

    @config = config

  setupFaye: ->
    @bayeux = new faye.NodeAdapter(mount: @config.mount, timeout: @config.timeout)


  start: ->
    server = http.createServer()
    @bayeux.attach(server)
    server.listen(@config.port)
    console.log "... awake and listening on http://localhost:#{@config.port}#{@config.mount}"


console.log "Waking the Weasel..."

weasel = new Weasel()
weasel.loadConfig()
weasel.setupFaye()
weasel.setupLogging()
weasel.setupDrowsyPersistence()
weasel.setupMQTTRelay()
weasel.start()

