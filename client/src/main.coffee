$ ->
  app =
    url: "http://localhost:3000"
  hand = []
  socket = io.connect(app.url)

  socket.on "alert", (message) -> alert message.text
  socket.on 'bust', ->
    $('#hand').append "<div class='card gem goblin'></div>"
    $('#hand').children().fadeOut ->
      app.player.fetch (player) ->
        app.player.set player


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
        @set 'hand', []
        socket.on @id, (player) =>
          console.log 'got player broadcast'
          console.log player
          @set player
      idAttribute: '_id'
      name: 'player'
      points: ->
        points = 0
        value =
          emerald: 1
          ruby: 3
          diamond: 5
        count =
          emerald: 0
          ruby: 0
          diamond: 0
        for card in @get('hand')
          points += value[card]
          count[card]++
        points += parseInt(count.emerald/4)*4
        points += parseInt(count.ruby/3)*9
        points += parseInt(count.diamond/2)*10
        return points

      sortHand: (hand) ->
        socket.emit 'sort hand',
          player: @
          hand: hand

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
        console.log 'new game view'
        @hand = new views.Hand
        @hand.render()
        @points = new views.Points
        @points.render()
        @players = new views.Players
        @players.render()
        @mine = new views.Mine
        @mine.render()

      template: $('#game-template').html()

    Mine: class extends Backbone.View
      initialize: ->
        app.game.on 'change:mine', => @render
        @$el.addClass 'card'
        $('#game').append @$el

      id: 'mine'
      template: $('#mine-template').html()

      render: ->
        @$el.html Mustache.render @template,
          mine: app.game.get('mine')

      events:
        'click': 'draw'
      
      draw: ->
        console.log 'drawing'
        socket.emit 'draw mine',
          game: app.game
          player: app.player



    Hand: class extends Backbone.View
      initialize: ->
        app.player.on 'change:hand', => @render()
        $('#game').append @$el

      id: 'hand'
      template: $('#hand-template').html()
      render: ->
        @$el.html Mustache.render @template,
          hand: app.player.get('hand')

        $('#hand').sortable
          update: ->
            hand = []
            $(this).children().each ->
              hand.push $(this).attr('data-card')
            app.player.sortHand hand

    Points: class extends Backbone.View
      initialize: ->
        app.player.on 'change:hand', => @render()
        $('#info').append @$el

      id: 'points'

      template: $('#points-template').html()
      render: ->
        @$el.html Mustache.render @template,
          points: app.player.points()

    Players: class extends Backbone.View
      initialize: ->
        app.game.on 'change:players', => @render()
        $('#info').append @$el

      id: 'players'

      template: $('#players-template').html()
      render: ->
        @$el.html Mustache.render @template,
          players: app.game.get('players')

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
