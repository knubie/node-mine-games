$ ->
  app =
    url: "http://localhost:3000"
  hand = []
  socket = io.connect(app.url)

  Backbone.sync = (method, model, options) ->
    if method is 'create'
      socket.emit "create #{model.name}", model, options.success

    if method is 'read'
      socket.emit "read #{model.name}", model.id, options.success

  # Models / Collections
  # ============================================

  models =
    
    Game: class extends Backbone.Model
      initialize: ->
        socket.on @id, (game) =>
          console.log 'got game broadcast'
          console.log game
          @set game
      idAttribute: '_id'
      name: 'game'
      addPlayer: (player) ->
        socket.emit 'game add player',
          player: player
          game: @

    Player: class extends Backbone.Model
      initialize: ->
        socket.on @id, (player) =>
          console.log 'got player broadcast'
          console.log player
          @set player
      idAttribute: '_id'
      name: 'player'

  # Views
  # ============================================

  views =

    Home: class extends Backbone.View
      id: 'home'
      template: $('#home-template').html()

      render: ->
        @$el.html Mustache.render @template
        $('#container').append @$el
        return @

      events:
        'click #new-game': 'createGame'

      createGame: ->
        app.game = new models.Game
        app.game.save {},
          success: ->
            console.log app.game.get '_id'
            app.routes.navigate "games/#{app.game.id}",
              trigger: true # Trigger the routes event for this path.

    Game: class extends Backbone.View
      initialize: ->
        app.game.on 'change', => @render()
        app.player.on 'change', => @render()

      id: 'game'
      template: $('#game-template').html()

      render: ->
        @$el.html Mustache.render @template,
          game: app.game.attributes
          players: app.game.get('players')
          hand: app.player.get('hand')
        $('#container').append @$el
        $('#hand').sortable
          update: ->
            hand = []
            $(this).children().each ->
              hand.push $(this).attr('data-card')
            console.log hand
            socket.emit 'sort hand',
              player: app.player
              hand: hand

      events:
        'click #mine': 'draw'
      
      draw: ->
        socket.emit 'draw mine',
          game: app.game
          player: app.player

  # Routes
  # ============================================

  class Routes extends Backbone.Router
    routes:
      '': 'home'
      'games/:id': 'showGame'

    home: ->
      app.view.remove() if app.view?
      app.view = new views.Home
      app.view.render()

    showGame: (id) ->
      app.view.remove() if app.view?

      fetchGame = ->
        app.game = new models.Game
          _id: id
        app.view = new views.Game
        app.game.addPlayer app.player

      app.player = new models.Player
        _id: sessionStorage.getItem('player id') or null
      if app.player.isNew()
        app.player.save {}, success: ->
          sessionStorage.setItem 'player id', app.player.id
          app.player = new models.Player # Create model to update socket.on
            _id: app.player.id
          fetchGame()
      else
        app.player.fetch success: ->
          fetchGame()

  app.routes = new Routes
  Backbone.history.start()
