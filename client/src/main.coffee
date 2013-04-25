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

  socket.on 'score', ->
    $('#hand').append "<div class='card gem emerald'></div>"
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
          @set game
          app.view.mine.render()
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
          console.log 'player updated'
          @set player
          console.log player
      idAttribute: '_id'
      name: 'player'

      sortHand: (hand) ->
        socket.emit 'sort hand',
          player: @attributes
          hand: hand

      discard: (card) ->
        socket.emit 'discard'
          game: app.game.attributes
          player: @
          card: card

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
            app.routes.navigate "games/#{app.game.id}",
              trigger: true # Trigger the routes event for this path.

    Game: class extends Backbone.View
      initialize: ->
        @hand = new views.Hand
        @hand.render()
        @discarded = new views.Discarded
        @discarded.render()
        @points = new views.Points
        @points.render()
        @players = new views.Players
        @players.render()
        @mine = new views.Mine
        @mine.render()

      template: $('#game-template').html()

    Mine: class extends Backbone.View
      initialize: ->
        app.game.on 'change', => @render
        @$el.addClass 'card'
        @$el.insertBefore '#game > #droppable-one'
        #$('#game').prepend @$el

      id: 'mine'
      template: $('#mine-template').html()

      render: ->
        @$el.html Mustache.render @template,
          mine: app.game.get('mine')

      events:
        'click': 'draw'
      
      draw: ->
        socket.emit 'draw',
          game: app.game
          player: app.player
          deck: 'mine'

    Hand: class extends Backbone.View
      initialize: ->
        app.player.on 'change', => @render()
        @$el.insertAfter '#game > #droppable-one'
        #$('#game').append @$el

      id: 'hand'
      template: $('#hand-template').html()
      render: ->
        console.log 'render hand'
        @$el.html Mustache.render @template,
          hand: app.player.get('hand')

        #$('#hand').sortable()

        $('#hand').children().draggable()
          #connectToSortable: '#hand'

        $('#droppable-one').droppable
          accept: '#hand > .card'
          drop: (e, ui) ->
            app.player.discard ui.draggable.attr('data-card')

        #$('#droppable-two').droppable
          #drop: (e, ui) ->
            #ui.draggable.css
            #app.player.discard ui.draggable.attr('data-card')

        #--- sorting ---
        #$('#hand').sortable
          #update: ->
            #hand = []
            #$(this).children().each ->
              #hand.push $(this).attr('data-card')
            #app.player.sortHand hand
        #--- stacking ---
        #for card in ['emerald', 'ruby', 'diamond']
          #top = 0
          #$(".#{card}").each ->
            #$(this).css 'top', top
            #top += 5

    Discarded: class extends Backbone.View
      initialize: ->
        app.game.on 'change:discarded', => @render()
        $('#droppable-one').append @$el

      id: 'discarded'
      template: $('#discarded-template').html()
      render: ->
        @$el.html Mustache.render @template,
          discarded: app.game.get('discarded')

        $('#discarded').children().draggable
          revert: 'invalid'

        $('#hand').droppable
          accept: '#discarded > .card'
          drop: (e, ui) ->
            socket.emit 'draw'
              game: app.game.attributes
              player: app.player.attributes
              deck: 'discarded'

            #app.player.discard ui.draggable.attr('data-card')

        $('#droppable-two').droppable
          drop: (e, ui) ->
            ui.draggable.css
            app.player.discard ui.draggable.attr('data-card')

    Points: class extends Backbone.View
      initialize: ->
        app.player.on 'change:points', => @render()
        $('#info').prepend @$el

      id: 'points'

      template: $('#points-template').html()
      render: ->
        @$el.html Mustache.render @template,
          points: app.player.get 'points'

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
