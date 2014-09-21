http = require('http')
events = require('events')

class DrowsyPersistence extends events.EventEmitter
  constructor: (@config) ->

  added: ->
    console.log "Drowsy persistence enabled. Broadcasts will be saved to #{@drowsyUrl()} ..."

  incoming: (message, callback) ->
    return callback(message)
    if message.channel.match /^\/meta\//
      return callback(message) # ignore this message

    cb2 = (message) ->
      console.log("Calling callback!")
      callback(message)
    this.persistInDrowsy message, cb2

  actionMethodMap =
      create: 'POST'
      update: 'PUT'
      patch: 'PATCH'
      delete: 'DELETE'

  persistInDrowsy: (message, callback) ->
    cid = message.clientId
    channel = message.channel
    data = message.data

    reqOpts =
      hostname: @config.hostname ? 'localhost'
      port: @config.port ? 9292
      path: channel
      method: actionMethodMap[data.action]

    # TODO: fine-tune http agent; see http://nodejs.org/api/http.html#http_class_http_agent

    req = http.request reqOpts, (res) =>
      if res.statusCode in [200...299]
        @emit 'persist_success', cid, channel, data, res
      else
        @emit 'persist_failure', cid, channel, data, res
        message.error = "Failed to persist data in Drowsy; Drowsy responded with a #{res.statusCode}"
      callback(message)

    req.on 'error', (err) =>
      @emit 'persist_failure', cid, channel, data, err
      errMsg = "\n\n!!! Error while sending request to Drowsy!
        Is the Drowsy server up and running at #{this.drowsyUrl()}?\n
        #{err.toString()}"
      console.error errMsg
      message.error = errMsg
      callback(message)
      throw err

    json = JSON.stringify(data.data)
    req.setHeader 'content-type', 'application/json'
    req.setHeader 'content-length', json.length
    req.write json
    req.end

  drowsyUrl: ->
    "http://#{@config.hostname}:#{@config.port}"

exports.DrowsyPersistence = DrowsyPersistence