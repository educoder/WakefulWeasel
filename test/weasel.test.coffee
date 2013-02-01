should = require('chai').should()
_ = require('underscore')
Deferred = require('dfrrd')
Weasel = require('../weasel').Weasel
WebSocket = require('ws')

DROWSY_URL = "http://localhost:9292"
WAKEFUL_URL = undefined
TEST_DB = 'weasel_test'
TEST_COLLECTION = 'tests'

PORT = 7778 # will be incremented by one for each test

PUBSUB_BACKENDS = {}

mubsub = require('../mubsub')
PUBSUB_BACKENDS['mubsub'] = mubsub.Mubsub

describe 'WakefulWeasel', ->

    beforeEach (done) ->
        @fakePubsub =
            publish: (rloc, bcast) ->
                #override me
            subscribe: (rloc, deliver) ->
                #override me
            unsubscribe: (rloc) ->
                #override me

        WAKEFUL_URL = "ws://localhost:"

        logger =
            error: (args...) -> console.error.apply(console, args)
            warn: (args...) -> console.warn.apply(console, args)
            log: ->

        @weasel = new Weasel
            logger: logger
            port: PORT

        WAKEFUL_URL = "ws://localhost:#{PORT}"

        @weasel.pubsub = @fakePubsub
        @weasel.on 'listening', -> 
            #console.log("#{WAKEFUL_URL} LISTENING")
            done()
        @weasel.listen()

        PORT++


    # afterEach (done) ->
    #     @weasel.on 'stopped', -> 
    #         console.log("#{WAKEFUL_URL} GONE DEAF")
    #         setTimeout(done, 1000)
    #     @weasel.stop()

    #     PORT++

    describe "#stop", ->
        it "should stop the server", (done) ->
            @weasel.on 'stopped', -> done()
            @weasel.stop()

    describe ".protocol", ->

        describe "#SUBSCRIBE", ->
            it "should trigger the pubsub's subscribe() only for the first subscriber to a URL", (done) ->
                reqCount = 0
                @weasel.on 'subscribed', ->
                    reqCount++

                subs = {}
                @weasel.pubsub.subscribe = (rloc, deliver) =>
                    subs[rloc.url] ?= 0
                    subs[rloc.url]++
                    if reqCount is 3
                        subs[rloc1.url].should.equal 1
                        subs[rloc2.url].should.equal 1
                        @weasel.subscribers[rloc1.url].length.should.equal 2
                        @weasel.subscribers[rloc2.url].length.should.equal 1
                        done()


                url1 = "#{DROWSY_URL}/#{TEST_DB}/#{TEST_COLLECTION}/000000000000000000000001"
                url2 = "#{DROWSY_URL}/#{TEST_DB}/#{TEST_COLLECTION}/000000000000000000000002"
                rloc1 = new Weasel.ResourceLocator(url1)
                rloc2 = new Weasel.ResourceLocator(url2)

                req1 = { type: 'SUBSCRIBE', url: url1 }
                req2 = { type: 'SUBSCRIBE', url: url2 }

                ws = new WebSocket(WAKEFUL_URL)
                ws.on 'open', ->
                    ws.send JSON.stringify(req1)
                    ws.send JSON.stringify(req1)
                    ws.send JSON.stringify(req2)

            it "should be able to handle subscriptions from multiple WebSockets", (done) ->
                reqCount = 0
                @weasel.on 'subscribed', =>
                    reqCount++
                    if reqCount is 4
                        subscribers = @weasel.subscribers[rloc1.url]
                        subscribers.length.should.equal 4

                        # we have two subscriptions from ws2, so only 3 unique websocket subscribers
                        uniqSubscribers = _.uniq(subscribers)
                        uniqSubscribers.length.should.equal 3

                        subs[rloc1.url].should.equal 1
                        done()

                url1 = "#{DROWSY_URL}/#{TEST_DB}/#{TEST_COLLECTION}/000000000000000000000001"
                rloc1 = new Weasel.ResourceLocator(url1)

                subs = {}
                @weasel.pubsub.subscribe = (rloc, deliver) =>
                    subs[rloc.url] ?= 0
                    subs[rloc.url]++
                req1 =
                    type: 'SUBSCRIBE'
                    url: url1

                ws1 = new WebSocket(WAKEFUL_URL)
                ws1.on 'open', ->
                    @send JSON.stringify(req1)

                ws2 = new WebSocket(WAKEFUL_URL)
                ws2.on 'open', ->
                    @send JSON.stringify(req1)
                    @send JSON.stringify(req1)

                ws3 = new WebSocket(WAKEFUL_URL)
                ws3.on 'open', ->
                    @send JSON.stringify(req1)


            it "should unsubscribe correctly when the WebSocket closes", (done) ->
                reqCount = 0
                @weasel.on 'subscribed', =>
                    reqCount++
                    if reqCount is 3
                        @weasel.subscribers[rloc1.url].length.should.equal 2
                        @weasel.subscribers[rloc2.url].length.should.equal 1
                        ws1.close() # should trigger pubsub.unsubscribe() and then the 'unsubscription' event

                unsubscribed = false
                @weasel.pubsub.unsubscribe = (rloc) =>
                    @weasel.subscribers[rloc1.url].length.should.equal 1
                    @weasel.subscribers[rloc2.url].length.should.equal 0
                    unsubscribed = true

                @weasel.on 'unsubscription', =>
                    @weasel.subscribers[rloc1.url].length.should.equal 1
                    @weasel.subscribers[rloc2.url].length.should.equal 0
                    unsubscribed.should.be.true
                    done()


                url1 = "#{DROWSY_URL}/#{TEST_DB}/#{TEST_COLLECTION}/000000000000000000000001"
                url2 = "#{DROWSY_URL}/#{TEST_DB}/#{TEST_COLLECTION}/000000000000000000000002"
                rloc1 = new Weasel.ResourceLocator(url1)
                rloc2 = new Weasel.ResourceLocator(url2)

                req1 = { type: 'SUBSCRIBE', url: url1 }
                req2 = { type: 'SUBSCRIBE', url: url2 }

                ws1 = new WebSocket(WAKEFUL_URL)
                ws1.on 'open', ->
                    @send JSON.stringify(req1)
                    @send JSON.stringify(req2)

                ws2 = new WebSocket(WAKEFUL_URL)
                ws2.on 'open', ->
                    @send JSON.stringify(req1)

        describe "#PUBLISH", ->
            it "should trigger the pubsub's publish()", (done) ->
                @weasel.pubsub.publish = (rloc, bcast) ->
                    bcast.action.should.equal 'update'
                    bcast.data.foo.should.equal 'blah'
                    bcast.origin.should.equal 'test1'
                    done()

                url1 = "#{DROWSY_URL}/#{TEST_DB}/#{TEST_COLLECTION}/000000000000000000000001"
                rloc1 = new Weasel.ResourceLocator(url1)

                req =
                    type: 'PUBLISH'
                    url: url1
                    action: 'update'
                    data: {foo: 'blah'}
                    origin: 'test1'

                ws = new WebSocket(WAKEFUL_URL)
                ws.on 'open', =>
                    ws.send JSON.stringify(req)

            it "should broadcast to all subscribers for a doc URL", (done) ->
                done()

    describe 'PubSub Backends', ->

        before ->
            @WSClient = class extends WebSocket
                sendWhenReady: (data) ->
                    if @readyState is WebSocket.OPEN
                        @send JSON.stringify data
                    else
                        @on 'open', -> @send JSON.stringify data


        Object.keys(PUBSUB_BACKENDS).forEach (name) ->
            backend = PUBSUB_BACKENDS[name]
            describe name, ->
                beforeEach ->
                    @weasel.pubsub = new backend
                        logger: @weasel.logger

                it "should transmit doc broadcast to all subscribers of doc", (done) ->
                    url1 = "#{DROWSY_URL}/#{TEST_DB}/#{TEST_COLLECTION}/000000000000000000000001"
                    rloc1 = new Weasel.ResourceLocator(url1)

                    reqSub1 = 
                        type: 'SUBSCRIBE'
                        url: url1
                    reqPub1 =
                        type: 'PUBLISH'
                        url: url1
                        action: 'update'
                        data: {foo: 'blah'}
                        origin: 'test1'

                    clients = []

                    for i in [1..3]
                        ws = new @WSClient(WAKEFUL_URL)
                        clients.push(ws)

                    received = []

                    for ws in clients
                        ws.sendWhenReady reqSub1
                        ws.on 'message', (msg) ->
                            bcast = JSON.parse(msg)
                            received.push(bcast)
                            if received.length is clients.length
                                done()
                    
                    subCount = 0
                    @weasel.on 'subscribed', ->
                        subCount++
                        if subCount is clients.length
                            clients[0].sendWhenReady reqPub1

                it "should transmit doc and collection broadcast to all subscribers of collection", (done) ->
                    doc_url1 = "#{DROWSY_URL}/#{TEST_DB}/#{TEST_COLLECTION}/000000000000000000000001"
                    doc_rloc1 = new Weasel.ResourceLocator(doc_url1)
                    
                    doc_url2 = "#{DROWSY_URL}/#{TEST_DB}/#{TEST_COLLECTION}/000000000000000000000002"
                    doc_rloc2 = new Weasel.ResourceLocator(doc_url2)

                    coll_url = "#{DROWSY_URL}/#{TEST_DB}/#{TEST_COLLECTION}"
                    coll_rloc = new Weasel.ResourceLocator(coll_url)

                    reqSub = 
                        type: 'SUBSCRIBE'
                        url: coll_url
                    reqPub =
                        type: 'PUBLISH'
                        url: undefined
                        action: 'update'
                        data: undefined
                        origin: 'test1'

                    clients = []

                    for i in [1..3]
                        ws = new @WSClient(WAKEFUL_URL)
                        clients.push(ws)

                    received = []

                    for ws in clients
                        ws.sendWhenReady reqSub
                        ws.on 'message', (msg) ->
                            bcast = JSON.parse(msg)
                            received.push(bcast)
                            if received.length is clients.length * 2
                                foo = received.reduce ((tot,r) -> tot + r.data.foo), 0
                                bar = received.reduce ((tot,r) -> tot + r.data.bar), 0
                                foo.should.equal 3
                                bar.should.equal 3
                                done()
                    
                    subCount = 0
                    @weasel.on 'subscribed', ->
                        subCount++
                        if subCount is clients.length
                            reqPub.url = doc_url1
                            reqPub.data = {foo: 1, bar: 0}
                            clients[0].sendWhenReady reqPub
                            reqPub.url = doc_url2
                            reqPub.data = {foo: 0, bar: 1}
                            clients[1].sendWhenReady reqPub

                



