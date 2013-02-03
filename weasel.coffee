WebSocket = require('ws')
WebSocketServer = WebSocket.Server
URL = require('url')
events = require('events')

#console.log "Waking the Weasel!"

class Weasel extends events.EventEmitter
    constructor: (options = {}) ->
        @options = options
        @options.port ?= 7777

        @pubusub = options.pubsub if options.pubsub?
        @logger = options.logger ? console

        # Mapping of cids (Client IDs) to WebSockets
        # e.g.:
        #   {
        #     "510c4d49e836b73af0000002": ws1,
        #     "629c4d49e836b73af0000005": ws2
        #   }
        # 
        # Clients will sometimes change websockets (when
        # for example they lose the connection and have to
        # reconnect). The cid allows subscribers to carry
        # over their subscriptions between connections.
        #
        # Subscribers must register here by issuing a
        # REGISTER request.
        @subscribers = {}

        # Mapping of URLs to cids (Client IDs);
        # e.g.:
        #   {
        #     "/mydb/mycoll/123": ["510c4d49e836b73af0000002", "629c4d49e836b73af0000005"],
        #     "/mydb/mycoll/234": ["510c4d49e836b73af0000002"],
        #     "/mydb/mycoll": ["629c4d49e836b73af0000005"] 
        #   }
        #
        # Keys (URLs) are added by SUBSCRIBE requests, with subsequent
        # SUBSCRIBEs adding to the list of cids under that key.
        @subscriptions = {}

    listen: ->
        @wss = new WebSocketServer(port: @options.port)

        @wss.on 'listening', => @emit('listening')

        @wss.on 'connection', (ws) =>

            ws.on 'message', (json) =>
                # TODO: handle JSON parse error
                req = JSON.parse(json)

                # TODO: handle invalid request type
                Weasel.protocol[req.type].call(this, req, ws)

    stop: ->
        @wss.close()
        @emit('stopped')

    broadcastToSubscribers: (rloc, bcast) ->
        bcast.url = rloc.url

        for cid in @subscriptions[rloc.url]
            ws = @clients[cid]

            send = => 
                @logger.log "< #{rloc.url}#",
                    "##{bcast.bid}", 
                    bcast.action, 
                    bcast.data,
                    bcast.origin

                ws.send JSON.stringify(bcast)
            
            if ws.readyState is WebSocket.OPEN
                send()
            else if ws.readyState is WebSocket.CONNECTING
                ws.on 'open', send
            else if ws.readyState is WebSocket.CLOSING
                @logger.warn "WebSocket is closing; cannot send update!"
            else if ws.readyState is WebSocket.CLOSED
                @logger.warn "WebSocket is closed; cannot send update!"
            else
                @logger.error "WebSocket is in a weird state!", ws.readyState


    @protocol:
        REGISTER: (req, ws) ->
            req.cid

        BROADCAST: (req, ws) ->
            rloc = new Weasel.ResourceLocator(req.url)

            bcast = 
                action: req.action
                data: req.data

            if req.bid?
                bcast.bid = req.bid
            if req.origin?
                bcast.origin = req.origin

            @pubsub.publish rloc, bcast
            @emit('published', rloc, bcast)
            
            @logger.log "> #{rloc.url}", bcast

        SUBSCRIBE: (req, ws) ->
            rloc = new Weasel.ResourceLocator(req.url)

            if @subscriptions[rloc.url]?
                # TODO: prevent multiple subscriptions to the same url from one websocket?
                @subscriptions[rloc.url].push(req.cid)
                @emit('subscribed', req.cid)
                
                @logger.log "s #{rloc.url} #{req.cid}"
            else
                @subscriptions[rloc.url] = []
                @subscriptions[rloc.url].push(ws)
                @emit('subscribed', ws)

                @pubsub.subscribe rloc, (bcast) =>
                    @broadcastToSubscribers(rloc, bcast)
                @emit('subscription', rloc)

                @logger.log "S #{rloc.url} #{req.cid}"

            @clients[req.cid] = ws

            ws.on 'close', =>
                delete @subscribers[req.cid]
                # idx = @subscribers[rloc.url].indexOf(ws)
                # @subscribers[rloc.url].splice(idx, 1)
                # @emit('unsubscribed', ws)
                # @logger.log "u #{rloc.url} #{req.cid}"
                # if @subscribers[rloc.url].length is 0
                #     @logger.log "U #{rloc.url}"
                #     @pubsub.unsubscribe rloc
                #     @emit('unsubscription', rloc)

            

class Weasel.ResourceLocator
    constructor: (url) ->
        parsedUrl = URL.parse(url)

        # TODO: we're ignoring the protocol and hostname. is this okay?
        [db, collection, id] = parsedUrl.pathname.replace(/^\//, '').split("/")

        if db? and collection? and id?
            # subscribing to single document
            normalizedUrl = "/#{db}/#{collection}/#{id}"
        else if db? and collection?
            # subscribing to entire collection
            normalizedUrl = "/#{db}/#{collection}"
        else
            # TODO: instead of throwing maybe reject deferred or something instead
            throw new Error("Invalid resource URL #{originalUrl}", originalUrl)
            @logger.error "! #{originalUrl}"

        @url = normalizedUrl
        @db = db
        @collection = collection
        @id = id if id?

    toString: -> @url

exports.Weasel = Weasel

# TODO: move this to a bin/weasel.js, using forever.js programmatically
#   see: https://github.com/nodejitsu/forever#using-forever-module-from-nodejs
if require.main is module
    console.log "Waking the Weasel!"
    pubsub = require('./mubsub')
    weasel = new Weasel
        pubsub: new pubsub.Mubsub()

    weasel.on 'listening', ->
        console.log "... now listening on ws://localhost:#{@options.port}"
    weasel.listen()

