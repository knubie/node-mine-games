require.config
  baseUrl: 'js/vendor'
  shim:
    'zepto':
      exports: '$'
    'socket.io':
      exports: 'io'
    'backbone':
      deps: ['underscore', 'zepto']
      exports: 'Backbone'
    'underscore':
      exports: '_'

  paths:
    'models': '../models'
    'socket.io': 'http://mine-games.herokuapp.com/socket.io/socket.io.js'
    'views': '../views'

define (require) ->

  $ = require 'zepto'
  _ = require 'underscore'
  Backbone = require 'backbone'
  io = require 'socket.io'
  Fastclick = require 'fastclick'
  models = require 'models'
  views = require 'views'

  $ ->
    FastClick.attach document.body

    app =
      url: "http://mine-games.herokuapp.com"
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
        app.game = new models.Game
          _id: id

        app.player = new models.Player
          afterSave: ->
            app.game.addPlayer app.player
            app.view.remove() if app.view?
            app.view = new views.Game
              model: app.game
              player: app.player
            app.view.render()



    app.routes = new Routes
    Backbone.history.start()
