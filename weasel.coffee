WebSocket = require('ws')
WebSocketServer = WebSocket.Server
URL = require('url')
mubsub = require('mubsub')
events = require('events')

#console.log "Waking the Weasel!"

class Weasel extends events.EventEmitter
    constructor: (options = {}) ->
        @options = options
        @options.port ?= 7777

        @pubusub = options.pubsub if options.pubsub?
        @logger = options.logger ? console

        @websockets = []

        # mapping of URLs to WebSockets;
        # e.g.:
        #   {
        #     "/mydb/mycoll/123": [ws1, ws2],
        #     "/mydb/mycoll/234": [ws3],
        #     "/mydb/mycoll": [ws2] 
        #   }
        @subscribers = {}

    listen: ->
        @wss = new WebSocketServer(port: @options.port)

        @wss.on 'listening', => @emit('listening')

        @wss.on 'connection', (ws) =>
            # clients are assigned client ids (cids) incrementally;
            # cids are never re-used within a Weasel instance
            cid = @websockets.length
            @websockets[cid] = ws

            ws.on 'close', =>
                delete @websockets[cid]

            ws.on 'message', (json) =>
                # TODO: handle JSON parse error
                req = JSON.parse(json)

                req.cid = cid
                ws.cid = cid

                # TODO: handle invalid request type
                Weasel.protocol[req.type].call(this, req)

    stop: ->
        @wss.close()
        @emit('stopped')

    broadcast: (rloc, bcast) ->
        for ws in @subscribers[rloc.url]
            #ws = @websockets[cid]

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
        PUBLISH: (req) ->
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

        SUBSCRIBE: (req) ->
            rloc = new Weasel.ResourceLocator(req.url)

            ws = @websockets[req.cid]

            if @subscribers[rloc.url]?
                # TODO: prevent multiple subscriptions to the same url from one websocket?
                @subscribers[rloc.url].push(ws)
                @emit('subscribed', ws)
                
                @logger.log "s #{rloc.url} #{req.cid}"
            else
                @subscribers[rloc.url] = []
                @subscribers[rloc.url].push(ws)
                @emit('subscribed', ws)

                @pubsub.subscribe rloc, (bcast) =>
                    @broadcast(rloc, bcast)
                @emit('subscription', rloc)

                @logger.log "S #{rloc.url} #{req.cid}"



            ws.on 'close', =>
                idx = @subscribers[rloc.url].indexOf(ws)
                @subscribers[rloc.url].splice(idx, 1)
                @emit('unsubscribed', ws)
                @logger.log "u #{rloc.url} #{req.cid}"
                if @subscribers[rloc.url].length is 0
                    @logger.log "U #{rloc.url}"
                    @pubsub.unsubscribe rloc
                    @emit('unsubscription', rloc)

            

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
