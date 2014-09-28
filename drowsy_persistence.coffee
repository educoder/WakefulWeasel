http = require('http')
httpRequest = require('request')
events = require('events')

class DrowsyPersistence extends events.EventEmitter
  constructor: (@config) ->

  added: ->
    console.log "Drowsy persistence enabled. Broadcasts will be saved to #{@drowsyUrl()}."

  incoming: (message, callback) ->
    #return callback(message)
    if message.channel.match /^\/meta\//
      return callback(message) # ignore this message

    this.persistInDrowsy message, callback

  actionMethodMap =
    create: 'POST'
    update: 'PUT'
    patch: 'PATCH'
    delete: 'DELETE'

  persistInDrowsy: (message, callback) ->
    cid = message.clientId
    channel = message.channel
    payload = message.data

    if @config.uri?
      baseUri = @config.uri.replace(/\/$/,'')
    else
      scheme = @config.scheme ? 'http'
      hostname = @config.hostname ? 'localhost'
      port = @config.port ? 9292
      baseUri = "#{scheme}://#{hostname}:#{port}"

    path = channel

    reqOpts =
      uri: "#{baseUri}/#{path}"
      method: actionMethodMap[payload.action]
      json: payload.data

    httpRequest reqOpts, (err, res, json) =>
      if err
        @emit 'persist_failure', cid, channel, payload, err
        errMsg = "\n\n!!! Error while sending request to Drowsy!
          Is the Drowsy server up and running at #{this.drowsyUrl()}?\n
          #{err.toString()}"
        console.error errMsg
        message.error = errMsg
        callback(message)
        throw err

      if res.statusCode in [200...299]
        @emit 'persist_success', cid, channel, payload, res, json
      else
        @emit 'persist_failure', cid, channel, payload, res, json
        message.error = "Failed to persist data in Drowsy; Drowsy responded with a #{res.statusCode}"
      callback(message)

  drowsyUrl: ->
    "http://#{@config.hostname}:#{@config.port}"

exports.DrowsyPersistence = DrowsyPersistence