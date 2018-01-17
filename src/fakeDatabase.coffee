_ = require 'lodash'
sinon = require 'sinon'
firebaseMock = require 'firebase-mock'
functions = require 'firebase-functions'
admin = require 'firebase-admin'

class FakeDatabase

  constructor: (functions, admin) ->
    @functions = functions
    @admin = admin
    @projectName = 'tests'
    @database = new firebaseMock.MockFirebase()

    # allow database.ref(path)
    @database.ref = (path) ->
      if path.replace(/^\//, '') then @child path else @

    # allow database.app
    @database.app =
      database: => @database

  setFunctionsModule: (@index) ->

  override: ->
    @adminInitStub = sinon.stub @admin, 'initializeApp'
      .returns
        database: @database
    @configStub = sinon.stub @functions, 'config'
      .returns
        firebase:
          databaseURL: "https://#{@projectName}.firebaseio.com"
    @databaseStub = sinon.stub admin, 'database'
      .returns @database

  restore: ->
    @configStub.restore()
    @adminInitStub.restore()
    @databaseStub.restore()

  write: (path, delta, fromApp) ->
    # TODO: also trigger parents
    fullPath = "projects/_/instances/#{@projectName}/refs/#{path.replace(/^\//, '')}"
    resourceRegex = (fn) ->
      _.get fn, '__trigger.eventTrigger.resource', ''
      .replace /{([^}]+)}/g, '([^/]+)'
    getParamNames = (fn) ->
      (_.get(fn, '__trigger.eventTrigger.resource', '').match(/{(.*?)}/g) || [])
      .map (name) -> name.replace /[{}]/g, ''
    @database.ref path
    .once 'value'
    .then (existingSnapshot) =>
      deltaSnapshot = new @functions.database.DeltaSnapshot fromApp || @database.app , @database.app, existingSnapshot.val(), delta, path
      @database.ref path
      .set deltaSnapshot.val()
      .then => Promise.all(
        _.chain @index
        .pickBy (fn) -> _.get(fn, '__trigger.eventTrigger.eventType') == 'providers/google.firebase.database/eventTypes/ref.write'
        .map (fn, name) ->
          fnMatch = fullPath.match resourceRegex fn
          if fnMatch
            # console.log "Triggering #{name}"
            paramNames = getParamNames fn
            params = _.chain paramNames
              .map (name) -> [name, fnMatch[paramNames.indexOf(name) + 1]]
              .fromPairs()
              .value()
            fn
              params: params
              resource: fullPath
              data: deltaSnapshot
        .value()
      )

  triggerHttpsFunction: (path, query) ->
    index = @index
    new Promise (resolve, reject) ->
      # console.log "Triggering #{path}"
      index[path.replace /^\//, ''] {query: query},
        send: resolve
        sendStatus: resolve

  triggerUserDeleted: (userRecord) ->
    Promise.all(
      _.chain @index
      .pickBy (fn) -> _.get(fn, '__trigger.eventTrigger.eventType') == 'providers/firebase.auth/eventTypes/user.delete'
      .map (fn, name) ->
        # console.log "Triggering #{name}"
        fn data: userRecord
      .value()
    )

  setWithoutTriggers: (path, value) ->
    @database.ref path
    .set value

  value: (path) ->
    @database.ref path
    .once 'value'
    .then (snapshot) -> snapshot.val()

module.exports = FakeDatabase
