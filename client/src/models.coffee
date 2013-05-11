define [
  'jquery'
  'underscore'
  'backbone'
  'mustache'
  'socket.io'
], ($, _, Backbone, Mustache, io) ->

  app =
    url: "http://localhost:3000"
  socket = io.connect(app.url)

  Game: class extends Backbone.Model
    initialize: (@cb) ->
      unless @isNew() # Unless ID is null
        @fetch
          success: => socket.on @id, (game) => @set game

    idAttribute: '_id'
    name: 'game'
    monster: ''
    monsterHP: 0
    log: []

    addPlayer: (player) ->
      socket.emit 'join game',
        player: player
        game: @
    start: ->
      socket.emit 'start game',
        game: @

  Player: class extends Backbone.Model
    initialize: ->
      # Assign ID from session or null
      @set
        _id: sessionStorage.getItem('player id') or null
      if @isNew() # If ID is null
        @save {}, success: => # Create new player from server
          sessionStorage.setItem 'player id', @id # Store new ID
          #TODO: refactor this and duplicate code below
          socket.on @id, (player) => @set player
          @get('afterSave')() if @get('afterSave')
      else
        @fetch
          success: =>
            socket.on @id, (player) => @set player
            @get('afterSave')() if @get('afterSave')

    idAttribute: '_id'
    name: 'player'
    points: 0
    draws: 1

    changeName: (name, game) ->
      socket.emit 'change name',
        game: game or {_id: 0}
        player: @
        name  : name

    sortHand: (hand) ->
      socket.emit 'sort hand',
        player: @
        hand: hand

    discard: (card) ->
      socket.emit 'discard',
        game: app.game.attributes
        player: @
        card: card

    play: (card, game) ->
      socket.emit 'play',
        game: game
        player: @
        card: card

    draw: (deck, game) ->
      socket.emit 'draw',
        game: game
        player: @
        deck: deck

    buy: (card, game) ->
      socket.emit 'buy',
        game: game
        player: @
        card: card

    endTurn: (game) ->
      socket.emit 'end turn',
        game: game
        player: @

    say: (message, game) ->
      socket.emit 'send message',
        game    : game
        player  : @
        message : message
