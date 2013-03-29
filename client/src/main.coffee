$ ->
  SERVER_URL = "http://localhost:3000"
  socket = io.connect(SERVER_URL)
  socket.on 'news', (data) ->
    console.log(data)
    socket.emit('my other event', { my: 'data' })

  Backbone.sync = (method, model, options) ->
    socket.emit method, model

  # Models / Collections
  # ============================================

  class Game extends Backbone.Model
    initialize: ->
      console.log "initializing new Game model"
      @on 'change', =>
        console.log "game changed"

    idAttribute: "_id" # Assign mongodb's _id to the Backbone model.id

  class Games extends Backbone.Collection
    initialize: ->
      console.log 'initializing Games collection'

    model: Game

    url: "#{SERVER_URL}/game"

  class Player extends Backbone.Model
    initialize: ->
      console.log 'initializing new Player model'
      @on 'change', =>
        console.log 'player changed'

    idAttribute: "_id"

  class Players extends Backbone.Collection
    initialize: ->
      console.log 'initializing Players collection'

    model: Player

    url: "#{SERVER_URL}/player"

  # Views
  # ============================================

  class Home extends Backbone.View
    id: 'home'

    template: $('#home-template').html()

    render: ->
      @$el.html Mustache.render(@template,{newGame: 'new game'})
      $('#container').append @$el
      @

    events:
      'click #new-game': 'newGame'

    newGame: ->
      app.game = new Game
        players: if app.player.isNew() then [] else [app.player.id]
      console.log app.game
      app.games.add app.game
      app.game.save {},
        success: =>
          @remove()
          app.routes.navigate "games/#{app.game.id}",
            trigger: true # Trigger the routes event for this path.

  class Match extends Backbone.View
    initialize: ->
      mine = new Mine
        model: @model
      mine.render()

    events:
      'submit #player': 'updatePlayer'
      'click #logout': 'logout'

    id: 'match'
    template: $('#match-template').html()
    render: ->
      @$el.html Mustache.render @template,
        player: app.player.get 'name'
        players: (app.players.get(id).attributes for id in app.game.get('players'))
      $('#container').append @$el
      @

    # Event methods
    updatePlayer: (e) ->
      e.preventDefault()
      # Save player with new name.
      app.player.save {name: $('.player-name').val()},
        success: =>
          # Update sesstionStorage with new id
          sessionStorage.setItem 'player', app.player.id
          # If app.player isn't in game.players
          if app.game.get('players').indexOf(app.player.id) is -1
            # Add it.
            app.game.save
              players: app.game.get('players').concat(app.player.id)
            ,
              success: =>
                @render()
          else
            @render()

    logout: ->
      unless app.player.isNew() # Unless already logged out
        # Remove player from game.players array
        app.game.set 'players', do ->
          players = app.game.get 'players'
          playerIndex = app.game.get('players').indexOf(app.player.id)
          players.splice(playerIndex, 1)
          return players
        # Save new players array to db
        app.game.save {},
          success: =>
            # Create a new blank player
            app.player = new Player
              name: 'Anonymous'
            # Remove player sessionStore
            sessionStorage.removeItem 'player'
            # Add new black player to global players array.
            app.players.add app.player
            # Rerender Match view.
            @render()

  class Mine extends Backbone.View
    initialize: ->
      @listenTo(@model, 'change', @render)

    id: 'mine'
    template: $('#mine-template').html()
    render: ->
      @$el.html Mustache.render @template,
        mine: @model.get 'mine'
      $('#container').append @$el
      @

    events:
      'click #mine': 'draw'

    draw: ->
      $.get "#{SERVER_URL}/draw/#{@model.id}", (res) =>
        console.log res
        $('#cards').append "#{res} "
        @model.fetch()


  # Routes
  # ============================================

  class Routes extends Backbone.Router
    initialize: ->
      # Bind this function every time the router routes something,
      # Which removes the current app view if there is one.
      #@bind "all", -> app.view.remove() if app.view?

    routes:
      '': 'home'
      'games/:id': 'match'

    home: ->
      app.view.remove() if app.view?
      app.view = new Home
      app.view.render()

    match: (id) ->
      app.view.remove() if app.view?
      app.game = app.games.get id
      app.view = new Match
        model: app.game
      app.view.render()

  app = # Create global app namespace.
    games: new Games
    players: new Players

  # Fetch games from server.
  app.games.fetch
    success: ->
      # Fetch players from server.
      app.players.fetch
        success: ->
          # Get / create player data from localStorage.
          if sessionStorage.getItem('player')
            app.player = app.players.get sessionStorage.getItem('player')
          else
            app.player = new Player
              name: 'Anonymous'
            app.players.add app.player

          app.routes = new Routes
          Backbone.history.start()
