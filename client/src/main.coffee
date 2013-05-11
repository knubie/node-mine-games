require.config
  baseUrl: 'js/vendor'
  shim:
    'socket.io':
      exports: 'io'
    'backbone':
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'underscore':
      exports: '_'

  paths:
    'models': '../models'
    'socket.io': 'http://localhost:3000/socket.io/socket.io'
    'views': '../views'

define (require) ->

  $ = require 'jquery'
  _ = require 'underscore'
  Backbone = require 'backbone'
  io = require 'socket.io'
  models = require 'models'
  views = require 'views'

  $ ->
    app =
      url: "http://localhost:3000"
    socket = io.connect(app.url)

    Backbone.sync = (method, model, options) ->
      if method is 'create'
        socket.emit "create #{model.name}", model, options.success

      if method is 'read'
        socket.emit "read #{model.name}", model.id, options.success

    # Routes
    # ============================================

    class Routes extends Backbone.Router
      routes:
        '': 'home'
        'games/create': 'createGame'
        'games/:id': 'showGame'

      home: ->
        app.player = new models.Player
        app.view.remove() if app.view?
        app.view = new views.Home
          model: app.player
          router: @

      createGame: ->
        app.game = new models.Game
        app.game.save {}, success: => # Create new player from server
          socket.on app.game.id, (game) => app.game.set game
          @navigate "games/#{app.game.id}",
            trigger: true

      showGame: (id) ->
        unless app.game and app.game.id is id
          app.game = new models.Game
            _id: id

        if app.player
          app.game.addPlayer app.player # Emits updated game model
        else
          app.player = new models.Player
            afterSave: ->
              app.game.addPlayer app.player # Emits updated game model

        app.view.remove() if app.view?
        app.view = new views.Game
          model: app.game
          player: app.player
        app.view.render()

    app.routes = new Routes
    Backbone.history.start()
