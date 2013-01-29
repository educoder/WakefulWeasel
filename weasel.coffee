WebSocket = require('ws')
WebSocketServer = WebSocket.Server
URL = require('url')
mubsub = require('mubsub')

console.log "Waking the Weasel!"

wss = new WebSocketServer(port: 7777)

wss.on 'connection', (ws) ->
    url = URL.parse(ws.upgradeReq.url)
    console.log "@ #{URL.format url}"

    [db, collection, id, wid] = url.pathname.replace(/^\//, '').split("/")

    if db? and collection? and id?
        resourceUrl = "/#{db}/#{collection}/#{id}"
    else if db? and collection?
        resourceUrl = "/#{db}/#{collection}"
    else
        console.error "! #{url}"

    ws.on 'message', (broadcastJSON) ->
        if typeof broadcastJSON is 'string'
            try
                broadcast = JSON.parse(broadcastJSON)
            catch e
                console.error "Couldn't parse JSON message: ", broadcastJSON
                return
        else
            broadcast = broadcastJSON

        broadcast.docId = broadcast.data._id

        channel.publish broadcast, ->
            console.log "> #{resourceUrl}",
                "##{broadcast.bid}", 
                broadcast.action.toUpperCase(), 
                broadcast.data,
                broadcast.origin

    # FIXME: This probably creates a new mongodb connection for each
    #        WebSocket. Change this so that connections are shared/pooled.
    #        Might need to modify mubsub to do this.
    client = mubsub("mongodb://localhost:27017/#{db}")
    channel = client.channel("#{collection}.weasel")
    
    # TODO: Allow custom queries.
    if id
        query = {docId: id}
    else
        query = {}

    
    subscription = channel.subscribe query, (broadcast) ->
        sendUpdate = -> 
            console.log "< #{resourceUrl}##{wid}",
                "##{broadcast.bid}", 
                broadcast.action.toUpperCase(), 
                broadcast.data,
                broadcast.origin

            ws.send JSON.stringify(broadcast)
        
        if ws.readyState is WebSocket.OPEN
            sendUpdate()
        else if ws.readyState is WebSocket.CONNECTING
            ws.on 'open', sendUpdate
        else if ws.readyState is WebSocket.CLOSING
            console.warn "WebSocket is closing; cannot send update!"
        else if ws.readyState is WebSocket.CLOSED
            console.warn "WebSocket is closed; cannot send update!"
        else
            console.error "WebSocket is in a weird state!", ws.readyState

    ws.on 'close', ->
        console.log "X #{resourceUrl}##{wid}"
        subscription.unsubscribe() # probably unneccessary; client.close() is enough
        client.close()

    ack = 
        status: "SUCCESS",
        url: URL.format(url),
        db: db,
        collection: collection,
        id: id,
        wid: wid

    console.log "S #{resourceUrl}##{wid}"
    ws.send JSON.stringify(ack)

