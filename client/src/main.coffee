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
          @set game
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
        @set
          _id: sessionStorage.getItem('player id') or null
        if @isNew()
          @save {}, success: =>
            sessionStorage.setItem 'player id', @id
            #TODO: refactor this and duplicate code below
            socket.on @id, (player) => @set player
            app.game.addPlayer @ if app.game
        else
          @fetch
            success: =>
              socket.on @id, (player) => @set player
              app.game.addPlayer @ if app.game

      idAttribute: '_id'
      name: 'player'
      points: 0
      draws: 1

      sortHand: (hand) ->
        socket.emit 'sort hand',
          player: @attributes
          hand: hand

      discard: (card) ->
        socket.emit 'discard',
          game: app.game.attributes
          player: @
          card: card

      play: (card) ->
        socket.emit 'play',
          game: app.game.attributes
          player: @
          card: card

      buy: (card) ->
        socket.emit 'buy',
          game: app.game.attributes
          player: @
          card: card

      endTurn: ->
        socket.emit 'end turn',
          game: app.game.attributes
          player: @

  # Views
  # ============================================

  views =

    Home: class extends Backbone.View
      initialize: ->
        app.view.remove() if app.view?
        app.view = @
        app.player.on 'change:name', => @render()

      id: 'home'
      template: $('#home-template').html()

      render: ->
        @$el.html Mustache.render @template,
          name: app.player.get('name')
        $('#container').append @$el
        $('#name').submit (e) ->
          e.preventDefault()
          socket.emit 'change name',
            game: {_id: 0} #FIXME: need a better way to do this
            player: app.player
            name  : $('.name').val()
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
        app.view.remove() if app.view?
        app.view = @
        app.game.on 'change:started', => @render()

        @$el = $('#container')

      template: $('#game-template').html()

      render: ->
        console.log 'render game view'
        console.log app.game
        if app.game.get 'started'
          console.log 'game started'
          @lobby.remove() if @lobby

          @hand = new views.Hand
          @hand.render()

          @discarded = new views.Discarded
          @discarded.render()

          @played = new views.Played
          @played.render()

          @points = new views.Points
          @points.render()

          @plays = new views.Plays
          @plays.render()

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

        else
          console.log 'game not started'
          @lobby = new views.Lobby
          @lobby.render()


      events:
        'click #end-turn-button': 'endTurn'
        'click #shop-button': 'toggleShop'

      endTurn: ->
        app.player.endTurn()

      toggleShop: ->
        if $('#container').css('-webkit-transform') is 'matrix(1, 0, 0, 1, 110, 0)'
          $('#container').css
            '-webkit-transform': 'translateX(0)'
        else
          $('#container').css
            '-webkit-transform': 'translateX(110px)'

    Lobby: class extends Backbone.View
      initialize: ->
        #FIXEME: on change:players doesn't register name changes
        app.view.lobby.remove() if app.view.lobby
        app.game.on 'change:players', => @render()
        app.player.on 'change:name', => @render()
        $('#container').append @$el

      id: 'lobby'

      template: $('#lobby-template').html()
      render: ->
        @$el.html Mustache.render @template,
          players: app.game.get('players')
          name: app.player.get('name')

        $('#name').submit (e) ->
          e.preventDefault()
          socket.emit 'change name',
            game: app.game
            player: app.player
            name  : $('.name').val()

      events:
        'click #start-game': 'startGame'

      startGame: ->
        socket.emit 'start game',
          game: app.game

    Mine: class extends Backbone.View
      initialize: ->
        app.game.on 'change:mine', => @render
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
        app.player.on 'change:hand', => @render()
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

      events:
        'click .card': 'play'

      play: (e) ->
        app.player.play $(e.currentTarget).attr('data-card')

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
          $('#droppable-two').append @$el
          @$el.html Mustache.render @template,
            played: app.game.get('monster')
            hp: app.game.get('monsterHP')
        else
          $('#played').remove()

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
          socket.emit 'draw',
            game: app.game.attributes
            player: app.player.attributes
            deck: 'discarded'

        $('#discarded').children().draggable
          revert: 'invalid'

        $('#hand').droppable
          accept: '#discarded > .card'
          drop: (e, ui) ->
            socket.emit 'draw',
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
        @$el.insertAfter '#shop-button'

      id: 'points'

      template: $('#points-template').html()
      render: ->
        @$el.html Mustache.render @template,
          points: app.player.get 'points'

    Plays: class extends Backbone.View
      initialize: ->
        app.player.on 'change:plays', => @render()
        @$el.insertAfter '#shop-button'

      id: 'plays'

      template: $('#plays-template').html()
      render: ->
        @$el.html Mustache.render @template,
          plays: app.player.get 'plays'

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
        console.log 'rendering players'
        console.log app.game
        unless typeof app.game.get('players')[0] is 'string'
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
          shop: ['sword', 'axe', 'pickaxe']

      events:
        'click .card': 'buy'

      buy: (e) ->
        app.player.buy $(e.currentTarget).attr('data-card')

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
        #TODO: keep focus on chat

        $('#chat').submit (e) ->
          e.preventDefault()
          socket.emit 'send message',
            game    : app.game
            player  : app.player
            message : $('.message').val()

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
      app.player = new models.Player
      new views.Home

    showGame: (id) ->
      app.game = new models.Game
        _id: id

      if app.player
        app.game.addPlayer app.player # Emits updated game model
      else
        app.player = new models.Player

      new views.Game

  app.routes = new Routes
  Backbone.history.start()
