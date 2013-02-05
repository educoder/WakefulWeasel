http = require('http')
faye = require('faye')

PORT = 7777
MOUNT = '/faye'

console.log "Waking the Weasel..."
bayeux = new faye.NodeAdapter(mount: MOUNT, timeout: 45)

bayeux.bind 'handshake', (cid) ->
    console.log "#{Date.now()} O #{cid}"
bayeux.bind 'subscribe', (cid, channel) ->
    console.log "#{Date.now()} + #{cid} #{channel}"
bayeux.bind 'unsubscribe', (cid, channel) ->
    console.log "#{Date.now()} - #{cid} #{channel}"
bayeux.bind 'publish', (cid, channel, data) ->
    console.log "#{Date.now()} > #{cid} #{channel}", data
bayeux.bind 'disconnect', (cid, channel, data) ->
    console.log "#{Date.now()} X #{cid}"

bayeux.listen(PORT)
console.log "... awake and listening on http://localhost:#{PORT}#{MOUNT}"