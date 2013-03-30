$ ->
  SERVER_URL = "http://localhost:3000"
  models = {}
  views = {}
  app = {}
  hand = []
  socket = io.connect(SERVER_URL)

  # Models / Collections
  # ============================================

  class models.Game extends Backbone.Model
    initialize: ->
      socket.on "game update #{@id}", (game) =>
        @set game
    idAttribute: "_id" # Assign mongodb's _id to the Backbone model.id

  class models.Player extends Backbone.Model
    initialize: ->
      socket.on "player update #{@id}", (player) =>
        @set player
    idAttribute: "_id"

  # Views
  # ============================================

  class views.Home extends Backbone.View
    id: 'home'
    template: $('#home-template').html()

    render: ->
      @$el.html Mustache.render @template
      $('#container').append @$el
      return @

    events:
      'click #new-game': 'createGame'

    createGame: ->
      socket.emit 'create game', {}, (model) ->
        app.game = new models.Game model
        app.routes.navigate "games/#{app.game.id}",
          trigger: true # Trigger the routes event for this path.

  class views.Game extends Backbone.View
    initialize: ->
      app.game.on 'change', =>
        @render()
        console.log 'game changed'

    id: 'game'
    template: $('#game-template').html()

    render: ->
      @$el.html Mustache.render @template,
        game: app.game.attributes
        hand: hand
      $('#container').append @$el
      return @

    events:
      'click #mine': 'draw'
    
    draw: ->
      socket.emit 'draw mine', app.game.id, (result) ->
        hand.push result.card
        app.game.set 'mine', result.mine

  # Routes
  # ============================================

  class Routes extends Backbone.Router
    routes:
      '': 'home'
      'games/:id': 'readGame'

    home: ->
      app.view.remove() if app.view?
      app.view = new views.Home
      app.view.render()

    readGame: (id) ->
      unless app.game?
        socket.emit 'read game', id, (model) ->
          app.game = new models.Game model
          app.view = new views.Game
          app.view.render()
      else
        app.view = new views.Game
        app.view.render()

  app.routes = new Routes
  Backbone.history.start()
