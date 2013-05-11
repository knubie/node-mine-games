define [
  'jquery'
  'underscore'
  'backbone'
  'mustache'
  'models'
], ($, _, Backbone, Mustache, models) ->

  class Lobby extends Backbone.View
    initialize: ->
      console.log 'init lobby view'
      @game = @options.game
      @player = @options.player
      @listenTo @game, 'change:players', @render
      @listenTo @player, 'change:name', @render
      $('#container').append @$el

    id: 'lobby'

    template: $('#lobby-template').html()
    render: ->
      @$el.html Mustache.render @template,
        players: @game.get('players')
        name: @player.get('name')

    events:
      'click #start-game': 'startGame'
      'submit #name': 'changeName'

    startGame: ->
      @game.start()

    changeName: (e) ->
      e.preventDefault()
      @player.changeName $('.name').val(), @game

  class Mine extends Backbone.View
    initialize: ->
      @game = @options.game
      @player = @options.player
      @listenTo @game, 'change:mine', @render
      @$el.addClass 'card'
      @$el.insertBefore '#game > #droppable-one'
      #$('#game').prepend @$el

    id: 'mine'
    template: $('#mine-template').html()

    render: ->
      @$el.html Mustache.render @template,
        mine: @game.get('mine')

    events:
      'click': 'draw'
    
    draw: ->
      @player.draw 'mine', @game

  class Hand extends Backbone.View
    initialize: ->
      @game = @options.game
      @player = @options.player
      @listenTo @player, 'change:hand', @render
      @$el.insertAfter '#game > #droppable-two'

    id: 'hand'
    template: $('#hand-template').html()
    render: ->
      @$el.html Mustache.render @template,
        hand: @player.get('hand')

    events:
      'click .card': 'play'

    play: (e) ->
      @player.play $(e.currentTarget).attr('data-card'), @game

  class Discarded extends Backbone.View
    initialize: ->
      @player = @options.player
      @game = @options.game
      @listenTo @player, 'change:discarded', @render
      @$el.addClass 'card'
      $('#droppable-one').append @$el

    id: 'discarded'
    template: $('#discarded-template').html()
    render: ->
      @$el.html Mustache.render @template,
        discarded: @player.get 'discarded'

    events:
      'click': 'draw'

    draw: ->
      @player.draw 'discarded', @game

  class Played extends Backbone.View
    initialize: ->
      @listenTo @model, 'change:monster', @render
      @listenTo @model, 'change:monsterHP', @render
      $('#droppable-two').append @$el

    id: 'played'
    template: $('#played-template').html()
    render: ->
      if @model.get('monster')
        $('#droppable-two').append @$el
        @$el.html Mustache.render @template,
          played: @model.get('monster')
          hp: @model.get('monsterHP')
      else
        $('#played').remove()

  class Points extends Backbone.View
    initialize: ->
      @listenTo @model, 'change:points', @render
      @$el.insertAfter '#shop-button'

    id: 'points'

    template: $('#points-template').html()
    render: ->
      @$el.html Mustache.render @template,
        points: @model.get 'points'

  class Plays extends Backbone.View
    initialize: ->
      @listenTo @model, 'change:plays', @render
      @$el.insertAfter '#shop-button'

    id: 'plays'

    template: $('#plays-template').html()
    render: ->
      @$el.html Mustache.render @template,
        plays: @model.get 'plays'

  class Draws extends Backbone.View
    initialize: ->
      @listenTo @model, 'change:draws', @render
      #$('#info').prepend @$el
      @$el.insertAfter '#shop-button'

    id: 'draws'

    template: $('#draws-template').html()
    render: ->
      @$el.html Mustache.render @template,
        draws: @model.get 'draws'

  class Players extends Backbone.View
    initialize: ->
      @listenTo @model, 'change:players', @render
      $('#info').append @$el

    id: 'players'

    template: $('#players-template').html()
    render: ->
      unless typeof @model.get('players')[0] is 'string'
        @$el.html Mustache.render @template,
          players: @model.get('players')

  class Shop extends Backbone.View
    initialize: ->
      @player = @options.player
      @game = @options.game
      @listenTo @model, 'change:shop', @render
      @$el.insertAfter '#container'

    id: 'shop'
    template: $('#shop-template').html()
    render: ->
      @$el.html Mustache.render @template,
        shop: ['sword', 'axe', 'pickaxe']

    events:
      'click .card': 'buy'

    buy: (e) ->
      @player.buy $(e.currentTarget).attr('data-card'), @model

  class Log extends Backbone.View
    initialize: ->
      @player = @options.player
      @listenTo @model, 'change:log', @render
      @$el.insertAfter '#game'

    id: 'log'
    template: $('#log-template').html()
    render: ->
      @$el.html Mustache.render @template,
        log: @model.get 'log'
      @el.scrollTop = 9999
      #TODO: keep focus on chat

      $('#chat').submit (e) ->
        e.preventDefault()
        socket.emit 'send message',
          game    : @model
          player  : @player
          message : $('.message').val()

    #events:
      #'submit #chat': 'chat'

    #chat: (e) ->
      #e.preventDefault()

  Home: class extends Backbone.View
    initialize: ->
      console.log 'init home view'
      @router = @options.router
      @listenTo @model, 'change:name', @render

    id: 'home'
    template: $('#home-template').html()

    render: ->
      @$el.html Mustache.render @template,
        name: @model.get('name')
      $('#container').append @$el

    events:
      'click #new-game': 'newGame'
      'submit #name': 'changeName'

    newGame: ->
      @router.navigate "games/create",
        trigger: true # Trigger the routes event for this path.


    changeName: (e) ->
      e.preventDefault()
      @model.changeName $('.name').val()

  Game: class extends Backbone.View
    initialize: ->
      console.log 'init game view'
      @player = @options.player
      @listenTo @model, 'change:started', @render
      @$el = $('#container')

    template: $('#game-template').html()

    render: ->
      #TODO Prevent showing lobby before game is fetched.
      if @model.get 'started'
        @lobby.remove() if @lobby

        #Game board
        @mine = new Mine
          game: @model
          player: @player
        @mine.render()

        @hand = new Hand
          game: @model
          player: @player
        @hand.render()

        @discarded = new Discarded
          game: @model
          player: @player
        @discarded.render()

        @played = new Played
          model: @model
        @played.render()

        #Info bar
        @points = new Points
          model: @player
        @points.render()

        @plays = new Plays
          model: @player
        @plays.render()

        @draws = new Draws
          model: @player
        @draws.render()

        @players = new Players
          model: @model
        @players.render()

        @shop = new Shop
          model: @model
          player: @player
        @shop.render()

        @log = new Log
          model: @model
          player: @player
        @log.render()
      else
        @lobby.remove() if @lobby
        @lobby = new Lobby
          game: @model
          player: @options.player
        @lobby.render()

    events:
      'click #end-turn-button': 'endTurn'
      'click #shop-button': 'toggleShop'

    endTurn: ->
      @player.endTurn @model

    toggleShop: ->
      if $('#container').css('-webkit-transform') is 'matrix(1, 0, 0, 1, 110, 0)'
        $('#container').css
          '-webkit-transform': 'translateX(0)'
      else
        $('#container').css
          '-webkit-transform': 'translateX(110px)'

