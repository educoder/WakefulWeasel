mqtt = require('mqtt')
events = require('events')

class MQTTRelay extends events.EventEmitter
  constructor: (config, bayeux) ->
    @config = config
    @bayeux = bayeux
    @subscriptions = {}

  added: ->
    clientOpts = @config.client_options || {}
    @mqttClient = mqtt.connect(@config.broker_url, clientOpts)
    @fayeClient = @bayeux.getClient()
    console.log "MQTT relay enabled. Broadcasts will be relayed to and from #{@mqttUrl()}."

    @mqttClient.on 'connect', =>
      @emit 'connect', @config.broker_url, clientOpts

      @mqttClient.on 'message', (topic, message) =>
        payload = JSON.parse(message)
        @emit 'receive', topic, payload
        payload.mqttRelay = 'in'
        @fayeClient.publish topic, payload

  incoming: (message, callback) ->
    # We do this to prevent the same message from bouncing
    # back and forth between MQTT and Faye. That is, we ignore
    # any incoming messages that have the mqttRelay flag set.
    # Note that this could be set to 'in' or 'out', depending on
    # whether the message originated from MQTT ('in'), or originated
    # from Faye ('out'), although this is irrelevant here.
    if message.data? && message.data.mqttRelay
      return callback(message)

    if message.channel.match /^\/meta\//
      # TODO: Handle unsubscriptions.
      if message.channel.match /^\/meta\/subscribe/
        this.subscribeToMQTT message, callback
      else
        # Ignore other kinds of meta messages for now...
        #console.log "META", message
        return callback(message)
    else
      this.publishToMQTT message, callback

  subscribeToMQTT: (subMessage, callback) ->
    topic = subMessage.subscription.replace('*', '#')
    clientId = subMessage.clientId

    if @subscriptions[topic]? && Object.keys(@subscriptions[topic]).length > 0
      @subscriptions[topic][clientId] = true
      # We're already subscribed to this topic, so don't subscribe again
      #console.log("MQTT", "already subscribed to topic", topic)
      @emit 'sub_skip', topic, clientId
      return callback(subMessage)
    else
      @subscriptions[topic] = {}
      @subscriptions[topic][clientId] = 'pending'

    qos = 1 # TODO: check with Gugo which qos we should be using
    @mqttClient.subscribe topic, {qos: qos}, (err, granted) =>
      if err?
        console.error("MQTT", "FAILED TO SUBSCRIBE TO TOPIC", topic, err)
        @emit 'sub_failure', topic, clientId, {qos: qos}, err
        # TODO: Need to figure out how to best handle this upstream.
        #       See http://faye.jcoglan.com/node/extensions.html for info on how Faye deals with
        #       with errors generated inside extensions.
        subMessage.error = err
        callback(subMessage)
      else
        granted.forEach (grant) =>
          @subscriptions[grant.topic][clientId] = 'confirmed'
          #console.log("MQTT", "successfully subscribed to topic", grant.topic)
          @emit 'sub_success', grant.topic, clientId, {qos: grant.qos}
        # TODO: We'll want to listen for unsub/disconnect events and check if any subscriptions
        #       remain for the topic. When no more clients are subscribed to the Faye channel, we
        #       should unsubscribe from the corresponding MQTT topic.
        callback(subMessage)

  publishToMQTT: (message, callback) ->
    topic = message.channel
    payload = message.data
    payload.mqttRelay = 'out'
    qos = 1 # 2 seems really slow, but maybe we need it? TODO: ask Gugo about appropriate qos
    retain = false # we don't want this to be true since clients are supposed to fetch the latests
                   # state of each resource upon subscribing
    opts = {qos: qos, retain: retain}
    @mqttClient.publish topic, JSON.stringify(payload), opts, =>
      @emit 'pub_success', topic, payload, opts
      callback(message)

  mqttUrl: ->
    @config.broker_url

exports.MQTTRelay = MQTTRelay