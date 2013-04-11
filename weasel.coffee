http = require('http')
faye = require('faye')
fs = require('fs')
events = require('events')


class Weasel extends events.EventEmitter
    setupLogging: () ->
        @bayeux.bind 'handshake', (cid) ->
            console.log "#{Date.now()} O #{cid}"
        @bayeux.bind 'subscribe', (cid, channel) ->
            console.log "#{Date.now()} + #{cid} #{channel}"
        @bayeux.bind 'unsubscribe', (cid, channel) ->
            console.log "#{Date.now()} - #{cid} #{channel}"
        @bayeux.bind 'publish', (cid, channel, data) ->
            console.log "#{Date.now()} > #{cid} #{channel}", data
        @bayeux.bind 'disconnect', (cid, channel, data) ->
            console.log "#{Date.now()} X #{cid}"

        @on 'persist_success', (cid, channel, data, res) ->
            console.log "#{Date.now()} √ #{cid} #{channel} (#{res.statusCode})"
        @on 'persist_failure', (cid, channel, data, res) ->
            console.warn "#{Date.now()} ! #{cid} #{channel} (#{res.statusCode})"

    setupPersistence: ->
        if @config.drowsy
            drowsy = @config.drowsy
        else
            console.warn "Drowsy persistence will be disabled because no 'drowsy' config was provided!"
            return

        actionMethodMap =
            create: 'POST'
            update: 'PUT'
            patch: 'PATCH'
            delete: 'DELETE'

        @bayeux.bind 'publish', (cid, channel, bcast) =>
            reqOpts =
                hostname: drowsy.hostname ? 'localhost'
                port: drowsy.port ? 9292
                path: channel
                method: actionMethodMap[bcast.action]

            # TODO: fine-tune http agent; see http://nodejs.org/api/http.html#http_class_http_agent

            req = http.request reqOpts, (res) =>
                if res.statusCode in [200...299]
                    @emit 'persist_success', cid, channel, bcast, res
                else
                    @emit 'persist_failure', cid, channel, bcast, res

            json = JSON.stringify(bcast.data)
            req.setHeader 'content-type', 'application/json'
            req.setHeader 'content-length', json.length
            req.write json
            
            req.end()

        console.log "Drowsy persistence enabled. Broadcasts will be saved to http://#{drowsy.hostname}:{drowsy.port} ..."

    loadConfig: ->
        defaults =
            port: 7777
            mount: '/faye'
            timeout: 30

        configPath = './config.json'
        if fs.existsSync(configPath)
            config = JSON.parse fs.readFileSync(configPath)

            for key,val of defaults
                config[key] ?= defaults[key]

            console.log "config.json loaded:", config
        else
            config = defaults
            console.warn "config.json not found! Using defaults:", config

        @config = config

    setupFaye: ->
        @bayeux = new faye.NodeAdapter(mount: @config.mount, timeout: @config.timeout)


    start: ->
        @bayeux.listen(@config.port)
        console.log "... awake and listening on http://localhost:#{@config.port}#{@config.mount}"


console.log "Waking the Weasel..."

weasel = new Weasel()
weasel.loadConfig()
weasel.setupFaye()
weasel.setupLogging()
weasel.setupPersistence()
weasel.start()

