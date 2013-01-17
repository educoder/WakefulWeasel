WebSocketServer = require('ws').Server
URL = require('url')
mubsub = require('mubsub')

console.log "Waking the Weasel!"

wss = new WebSocketServer(port: 7777)

wss.on 'connection', (ws) ->
    url = URL.parse(ws.upgradeReq.url)
    console.log "@ #{URL.format url}"

    [db, collection, id] = url.pathname.replace(/^\//, '').split("/")

    if db? and collection? and id?
        resourceUrl = "/#{db}/#{collection}/#{id}"
    else if db? and collection?
        resourceUrl = "/#{db}/#{collection}"
    else
        console.error "! #{url}"

    ws.on 'message', (doc) ->
        console.log "> #{resourceUrl}", doc
        channel.publish JSON.parse(doc)

    # FIXME: This probably creates a new mongodb connection for each
    #        WebSocket. Change this so that connections are shared/pooled.
    #        Might need to modify mubsub to do this.
    client = mubsub("mongodb://localhost:27017/#{db}")
    channel = client.channel("#{collection}.weasel")
    
    console.log "S #{resourceUrl}"

    # TODO: Allow custom queries.
    if id
        query = {id: id}
    else
        query = {}

    subscription = channel.subscribe {id: id}, (doc) ->
        sendUpdate = -> 
            console.log "< #{resourceUrl}", doc
            ws.send JSON.stringify(doc)
        
        if ws.readyState is 0
            ws.on 'open', sendUpdate
        else if ws.readyState is 1
            sendUpdate()
        else if ws.readyState is 2
            console.warn "WebSocket is closing; cannot send update!"
        else if ws.readyState is 4
            console.warn "WebSocket is closed; cannot send update!"
        else
            console.error "WebSocket is in a weird state!", ws.readyState

    ws.on 'close', ->
        console.log "X #{resourceUrl}"
        subscription.unsubscribe() # probably unneccessary; client.close() is enough
        client.close()
