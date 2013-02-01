mubsub = require('mubsub')
weasel = require('./weasel')
Deferred = require('dfrrd')

class Mubsub
    constructor: (options = {}) ->
        @options = options
        @options.host = options.host ? 'localhost'
        @options.port = options.port ? 27017
        @channels = {}
        @subs = {}
        @logger = options.logger


    publish: (rloc, broadcast) ->
        deferredPublish = new Deferred()
        broadcast.doc_id = rloc.id if rloc.id?

        channel = @channels["#{rloc.db}/#{rloc.collection}"]
        channel.publish broadcast, (ev) ->
            deferredPublish.resolve(broadcast)

        return deferredPublish

    subscribe: (rloc, deliver) ->
        {db, collection, id, url} = rloc

        if @subs[url]?
            throw new Error("Cannot subscribe to '#{url}' because that URL is already subscribed")

        channel_key = "#{rloc.db}/#{rloc.collection}"
        if @channels[channel_key]?
            channel = @channels[channel_key]
        else
            client = mubsub("mongodb://#{@options.host}:#{@options.port}/#{db}", w: 0)
            channel = client.channel("#{collection}.wakeful", wait: 1)
            @channels[channel_key] = channel
        
        # TODO: Allow custom queries.
        if id
            query = {doc_id: id}
        else
            query = {}

        sub = channel.subscribe query, deliver
        @subs[url] = sub

    unsubscribe: (rloc) ->
        unless @subs[rloc.url]
            @logger.warn "Unsubscribing from '#{rloc.url}' but that URL is not subscribed"
            return

        sub = @subs[rloc.url]
        sub.unsubscribe() # probably unneccessary; client.close() is enough
        
        #TODO: close client/channel if no longer used
        # channel = @channels["#{rloc.db}/#{rloc.collection}"]
        # console.log channel
        # channel.close()
        
        delete @subs[rloc.url]

exports.Mubsub = Mubsub