_ = require 'lodash'
functions = require 'firebase-functions'

class MockFunctions

  constructor: (database) ->
    @database = database
    @projectName = 'test'

  setFunctionsModule: (@index) ->

  writeAndTrigger: (path, delta, fromApp) ->
    # TODO: also trigger parents
    fullPath = "projects/_/instances/#{@projectName}/refs/#{path.replace(/^\//, '')}"
    resourceRegex = (fn) ->
      _.get fn, ['__trigger', 'eventTrigger', 'resource'], ''
      .replace /{([^}]+)}/g, '([^/]+)'
    getParamNames = (fn) ->
      (_.get(fn, ['__trigger', 'eventTrigger', 'resource'], '').match(/{(.*?)}/g) || [])
      .map (name) -> name.replace /[{}]/g, ''
    @database.ref path
    .once 'value'
    .then (existingSnapshot) =>
      deltaSnapshot = new functions.database.DeltaSnapshot fromApp || @database.app, @database.app, existingSnapshot.val(), delta, path
      @database.ref path
      .set deltaSnapshot.val()
      .then => Promise.all(
        _.chain @index
        .pickBy (fn) -> _.get(fn, ['__trigger', 'eventTrigger', 'eventType']) == 'providers/google.firebase.database/eventTypes/ref.write'
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
              eventId: 'fakeEventId'
              eventType: fn.__trigger.eventTrigger.eventType
              params: params
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

  writeWithoutTriggers: (path, value) ->
    @database.ref path
    .set value

  value: (path) ->
    @database.ref path
    .once 'value'
    .then (snapshot) -> snapshot.val()

module.exports = MockFunctions
