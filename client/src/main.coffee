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
      name: 'game'

    Player: class extends Backbone.Model
      initialize: ->
        socket.on @id, (player) =>
          console.log 'got player broadcast'
          console.log player
          @set player
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
            app.game.set 'id', app.game.get '_id'
            console.log app.game
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
          player: app.player.attributes
        $('#container').append @$el
        return @

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
      fetchGame = ->
        # Create new backbone game from id url param.
        app.game = new models.Game
          id: id
        # Create new view.
        app.view = new views.Game
        # Tell the server to add the current player to the game.
        # The server knows whether or not the current player is
        # already in the game and will not add them if they are.
        socket.emit 'game add player',
          player: app.player
          game: app.game

      app.player = new models.Player
        id: sessionStorage.getItem('player id') or null
      if app.player.isNew()
        app.player.save {}, success: ->
          app.player.set 'id', app.player.get '_id'
          sessionStorage.setItem 'player id', app.player.id
          fetchGame()
      else
        app.player.fetch success: ->
          fetchGame()

  app.routes = new Routes
  Backbone.history.start()
