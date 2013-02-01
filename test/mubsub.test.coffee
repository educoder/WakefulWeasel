should = require('chai').should()
Deferred = require('dfrrd')
Weasel = require('../weasel').Weasel



randomMongoId = ->
    id = "000000000000000000000000" + Math.floor(Math.random()*(0xffffffff-1)).toString(16)
    id.substring(id.length - 24)

xdescribe "pubsub via mubsub", ->
    @timeout 6000 # mubsub is really slow for some reason

    beforeEach ->
        @pubsub = require('../mubsub')

    it "should broadcast to all subscribers of doc url", (done) ->
        id = randomMongoId()

        doc_url = "http://test.com/weasel_test/tests/#{id}"
        doc_rid = new Weasel.ResourceID(doc_url)

        got1 = []

        dfs1 =
            A: new Deferred()
            B: new Deferred()


        @pubsub.subscribe doc_rid, (broadcast) ->
            got1.push broadcast.data.foo
            dfs1[broadcast.data.foo].resolve()
        
        @pubsub.publish doc_rid, {data: {foo: 'A'}}
        @pubsub.publish doc_rid, {data: {foo: 'B'}}


        $.when(dfs1.A,dfs1.B).then ->
            got1.should.include 'A'
            got1.should.include 'B'
            done()

    it "should broadcast to all subscribers of collection url", (done) ->
        id1 = randomMongoId()
        id2 = randomMongoId()

        doc1_url = "http://test.com/weasel_test/tests/#{id1}"
        doc1_rid = new Weasel.ResourceID(doc1_url)

        doc2_url = "http://test.com/weasel_test/tests/#{id2}"
        doc2_rid = new Weasel.ResourceID(doc2_url)

        coll_url = "http://test.com/weasel_test/tests"
        coll_rid = new Weasel.ResourceID(coll_url)

        dfs =
            a: new Deferred()
            b: new Deferred()
            c: new Deferred()
            d: new Deferred()

        got = []

        @pubsub.subscribe coll_rid, (broadcast) ->
            got.push(broadcast.data.foo)
            dfs[broadcast.data.foo].resolve()
       
        @pubsub.publish doc1_rid, {data: {foo: 'a'}}
        @pubsub.publish doc1_rid, {data: {foo: 'b'}}
        @pubsub.publish doc2_rid, {data: {foo: 'c'}}
        @pubsub.publish coll_rid, {data: {foo: 'd'}}

        $.when(dfs.a,dfs.b,dfs.c,dfs.d).then ->
            got.should.include 'a'
            got.should.include 'b'
            got.should.include 'c'
            got.should.include 'd'
            done()

    it "should allow unsubscribing", (done) ->
        # NOTE: we don't really have a good way of testing that it works here...

        id = randomMongoId()

        doc_url = "http://test.com/weasel_test/tests/#{id}"
        doc_rid = new Weasel.ResourceID(doc_url)
        
        @pubsub.subscribe doc_rid, (broadcast) -> # nada
        
        @pubsub.unsubscribe doc_rid
        done()

        