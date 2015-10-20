http = require('http')
faye = require('faye')
redis = require('faye-redis')
fs = require('fs')
events = require('events')
DrowsyPersistence = require('./drowsy_persistence').DrowsyPersistence

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
            console.log "#{Date.now()} [sub    ] #{cid} #{channel}"
        @bayeux.bind 'unsubscribe', (cid, channel) ->
            console.log "#{Date.now()} [unsub  ] #{cid} #{channel}"
        @bayeux.bind 'publish', (cid, channel, data) ->
            console.log "#{Date.now()} [pub    ] #{cid} #{channel}", data
        @bayeux.bind 'disconnect', (cid, channel, data) ->
            console.log "#{Date.now()} [disconn] #{cid}"

        @on 'persist_success', (cid, channel, data, res) ->
            console.log "#{Date.now()} [drwsy.save] #{cid} #{channel} (#{res.statusCode})"
        @on 'persist_failure', (cid, channel, data, res) ->
            console.warn "#{Date.now()} [drwsy.fail] #{cid} #{channel} (#{res.statusCode})"

    setupPersistence: ->
        if @config.drowsy
            drowsy = new DrowsyPersistence @config.drowsy
        else
            console.warn "Drowsy persistence will be disabled because no 'drowsy' config was provided!"
            return

        drowsy.on 'persist_success', (cid, channel, data, res) =>
            @emit 'persist_success', cid, channel, data, res
        drowsy.on 'persist_failure', (cid, channel, data, res) =>
            @emit 'persist_failure', cid, channel, data, res

        @bayeux.addExtension(drowsy);

    loadConfig: ->
        defaults =
            port: 7777
            mount: '/faye'
            timeout: 60
            engine:
              type: redis
              host: 'localhost'

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
weasel.setupPersistence()
weasel.start()

