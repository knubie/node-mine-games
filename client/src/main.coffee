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
      monster: ''
      monsterHP: 0
      log: []
      addPlayer: (player) ->
        socket.emit 'game add player',
          player: player
          game: @

    Player: class extends Backbone.Model
      initialize: ->
        @set 'hand', []
        socket.on @id, (player) =>
          @set player
      idAttribute: '_id'
      name: 'player'
      points: 0
      draws: 1

      sortHand: (hand) ->
        socket.emit 'sort hand',
          player: @attributes
          hand: hand

      discard: (card) ->
        socket.emit 'discard'
          game: app.game.attributes
          player: @
          card: card

      play: (card) ->
        socket.emit 'play'
          game: app.game.attributes
          player: @
          card: card

      buy: (card) ->
        socket.emit 'buy'
          game: app.game.attributes
          player: @
          card: card

      endTurn: ->
        socket.emit 'end turn'
          game: app.game.attributes
          player: @

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

        @played = new views.Played
        @played.render()

        @points = new views.Points
        @points.render()

        @draws = new views.Draws
        @draws.render()

        @players = new views.Players
        @players.render()

        @mine = new views.Mine
        @mine.render()

        @shop = new views.Shop
        @shop.render()

        @log = new views.Log
        @log.render()

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
        @$el.insertAfter '#game > #droppable-two'
        #$('#game').append @$el

      id: 'hand'
      template: $('#hand-template').html()
      render: ->
        @$el.html Mustache.render @template,
          hand: app.player.get('hand')

        $('#hand').children().draggable()

        $('#droppable-one').droppable
          accept: '#hand > .card'
          drop: (e, ui) ->
            app.player.discard ui.draggable.attr('data-card')

        $('#droppable-two').droppable
          accept: '#hand > .card'
          drop: (e, ui) ->
            app.player.play ui.draggable.attr('data-card')

        $('#hand > .card').click ->
          app.player.play $(this).attr('data-card')

        $('#end-turn-button').click ->
          app.player.endTurn()

        $('#shop-button').click ->
          console.log $('#container').css('-webkit-transform')
          if $('#container').css('-webkit-transform') is 'matrix(1, 0, 0, 1, 110, 0)'
            $('#container').css
              '-webkit-transform': 'translateX(0)'
          else
            $('#container').css
              '-webkit-transform': 'translateX(110px)'

      events:
        'click #end-turn': 'endTurn'

      endTurn: ->
        app.player.endTurn()

    Played: class extends Backbone.View
      initialize: ->
        app.game.on 'change:monster', => @render()
        app.game.on 'change:monsterHP', => @render()
        $('#droppable-two').append @$el

      id: 'played'
      template: $('#played-template').html()
      render: ->
        if app.game.get('monster')
          @$el.html Mustache.render @template,
            played: app.game.get('monster')
            hp: app.game.get('monsterHP')

    Discarded: class extends Backbone.View
      initialize: ->
        app.game.on 'change:discarded', => @render()
        @$el.addClass 'card'
        $('#droppable-one').append @$el

      id: 'discarded'
      template: $('#discarded-template').html()
      render: ->
        @$el.html Mustache.render @template,
          discarded: app.player.get('discarded')

        $('#discarded').click ->
          socket.emit 'draw'
            game: app.game.attributes
            player: app.player.attributes
            deck: 'discarded'

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

        #$('#droppable-two').droppable
          #drop: (e, ui) ->
            #ui.draggable.css
            #app.player.discard ui.draggable.attr('data-card')

    Points: class extends Backbone.View
      initialize: ->
        app.player.on 'change:points', => @render()
        #$('#info').prepend @$el
        @$el.insertAfter '#shop-button'

      id: 'points'

      template: $('#points-template').html()
      render: ->
        @$el.html Mustache.render @template,
          points: app.player.get 'points'

    Draws: class extends Backbone.View
      initialize: ->
        app.player.on 'change:draws', => @render()
        #$('#info').prepend @$el
        @$el.insertAfter '#shop-button'

      id: 'draws'

      template: $('#draws-template').html()
      render: ->
        @$el.html Mustache.render @template,
          draws: app.player.get 'draws'

    Players: class extends Backbone.View
      initialize: ->
        app.game.on 'change:players', => @render()
        $('#info').append @$el

      id: 'players'

      template: $('#players-template').html()
      render: ->
        @$el.html Mustache.render @template,
          players: app.game.get('players')

    Shop: class extends Backbone.View
      initialize: ->
        app.game.on 'change:shop', => @render()
        @$el.insertAfter '#container'

      id: 'shop'
      template: $('#shop-template').html()
      render: ->
        @$el.html Mustache.render @template,
          shop: ['sword', 'axe', 'pickaxe', 'thief']

      events:
        'click .sword': 'buySword'
        'click .axe': 'buyAxe'
        'click .pickaxe': 'buyPickaxe'

      buySword: ->
        app.player.buy 'sword'

      buyAxe: ->
        app.player.buy 'axe'

      buyPickaxe: ->
        app.player.buy 'pickaxe'

    Log: class extends Backbone.View
      initialize: ->
        app.game.on 'change:log', => @render()
        @$el.insertAfter '#game'

      id: 'log'
      template: $('#log-template').html()
      render: ->
        @$el.html Mustache.render @template,
          log: app.game.get 'log'
        @el.scrollTop = 9999

        $('#chat').submit ->
          socket.emit 'send message'
            game: app.game
            player: app.player
            message: $('.message').val()

      #events:
        #'submit #chat': 'chat'

      #chat: (e) ->
        #e.preventDefault()

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
