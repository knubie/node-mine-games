define [
  'zepto'
  'underscore'
  'backbone'
  'mustache'
  'appscroll'
  'models'
], ($, _, Backbone, Mustache, AppScroll, models) ->

  class Lobby extends Backbone.View
    initialize: ->
      console.log 'init lobby view'
      @game = @options.game
      @player = @options.player
      @listenTo @game, 'change:players', @render
      @listenTo @player, 'change:name', @render
      $('#container').append @$el
      scroller = new AppScroll
        toolbar: $('#info')[0]
        scroller: @el

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
      @listenTo @game, 'change:monster', @render
      @listenTo @game, 'change:monsterHP', @render

    id: 'mine'
    mineTemplate: $('#mine-template').html()
    monsterTemplate: $('#monster-template').html()

    render: ->
      if @game.get('monster')
        @$el.html Mustache.render @monsterTemplate,
          monster: @game.get('monster')
          hp: =>
            @game.get('monsterHP')/20*100 #TODO: get actual total hp.
      else
        @$el.html Mustache.render @mineTemplate,
          mine: @game.get('mine')

      return @$el

    events:
      'click': 'draw'
    
    draw: ->
      @player.draw 'mine', @game

  class Hand extends Backbone.View
    initialize: ->
      @game = @options.game
      @player = @options.player
      @listenTo @player, 'change:hand', @render

    id: 'hand'
    template: $('#hand-template').html()
    render: ->
      console.log 'hand changed'
      console.log @player.get('hand')
      @$el.html Mustache.render @template,
        hand: @player.get('hand')
      return @$el

    events:
      'click .card': 'play'

    play: (e) ->
      @player.play $(e.currentTarget).attr('data-card'), @game

  class Info extends Backbone.View
    initialize: ->
      console.log 'init info'
      @player = @options.player
      @game = @options.game
      @listenTo @player, 'change', @render
      $('#info').prepend @$el

    id: 'stats'
    template: $('#info-template').html()
    render: ->
      @$el.html Mustache.render @template,
        player: @player.attributes

  class Players extends Backbone.View
    initialize: ->
      console.log 'init players list'
      @listenTo @model, 'change:players', @render
      $('#info').append @$el
      #@$el.insertAfter '#info'

    id: 'players'

    template: $('#players-template').html()
    render: ->
      # Don't render if game.players isn't populated.
      unless typeof @model.get('players')[0] is 'string'
        @$el.html Mustache.render @template,
          players: @model.get('players')

  class Discarded extends Backbone.View
    initialize: ->
      @player = @options.player
      @game = @options.game
      @listenTo @player, 'change:discarded', @render

    id: 'discarded'
    template: $('#discarded-template').html()
    render: ->
      console.log @player
      if @player.get('discarded').length < 1
        empty = 'empty-card'
      else
        empty = 'deck card'
      @$el.html Mustache.render @template,
        discarded: @player.get 'discarded'
        empty: empty
      return @$el

    events:
      'click': 'draw'

    draw: ->
      @player.draw 'discarded', @game

  class Played extends Backbone.View
    initialize: ->
      @listenTo @model, 'change:monster', @render
      @listenTo @model, 'change:monsterHP', @render
      #$('#droppable-two').append @$el

    id: 'played'
    template: $('#played-template').html()
    render: ->
      if @model.get('monster')
        $('#droppable-two').append @$el
        @$el.html Mustache.render @template,
          played: @model.get('monster')
          hp: =>
            @model.get('monsterHP')/20*100
      else
        $('#played').remove()
      return @$el

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
      $('#container').append @$el
      #@$el.insertAfter '#game'

    id: 'log'
    template: $('#log-template').html()
    render: ->
      @$el.html Mustache.render @template,
        log: @model.get 'log'
      @el.scrollTop = 9999

  class Chat extends Backbone.View
    initialize: ->
      @player = @options.player
      @$el.insertAfter '#log'

    id: 'chat-container'
    template: $('#chat-template').html()
    render: -> @$el.html @template

    events:
      'submit #chat': 'sendMessage'

    sendMessage: (e) ->
      e.preventDefault()
      @player.say $('.message').val(), @model
      $('.message').val('')

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
      @listenTo @player, 'change:turn', =>
        alert "It's your turn." if @player.turn
      $('#container').append @$el


    template: $('#game-template').html()
    id: 'game'

    render: ->
      #TODO Prevent showing lobby before game is fetched.
      if @model.get 'started'
        @lobby.remove() if @lobby

        console.log @player
        @$el.html @template

        #Game board
        @mine = new Mine
          game: @model
          player: @player
        @$el.append @mine.render()

        @discarded = new Discarded
          game: @model
          player: @player
        @$el.append @discarded.render()

        @hand = new Hand
          game: @model
          player: @player
        @$el.append @hand.render()

        @played = new Played
          model: @model
        @$el.append @played.render()

        #Info bar
        @info = new Info
          game: @model
          player: @player
        @info.render()

        @players = new Players
          model: @model
        @players.render()

        @shop = new Shop
          model: @model
          player: @player
        @shop.render()

        #Log
        @log = new Log
          model: @model
          player: @player
        @log.render()

        @chat = new Chat
          model: @model
          player: @player
        @chat.render()
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

