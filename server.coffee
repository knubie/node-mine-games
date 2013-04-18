mongoose = require 'mongoose'
models = require './models'
_ = require 'underscore'
sugar = require 'sugar'
express = require('express')

app = express()
server = require('http').createServer(app)
io = require('socket.io').listen(server, {log: false})

io.sockets.on 'connection', (socket) ->

  socket.on 'create game', (model, callback) ->
    console.log 'Creating new Game.'
    game = new Game
      players: []
      discarded: []
      mine: do ->
        mine = []
        mine.push('emerald') for [1..6]
        mine.push('ruby') for [1..6]
        mine.push('diamond') for [1..6]
        mine.push('goblin') for [1..5]
        return mine.randomize()

    game.save (err) ->
      callback game

  socket.on 'read game', (id, callback) ->
    Game.findById id, (err, game) ->
      callback game

  socket.on 'game add player', (req, callback) ->
    #TODO: limit players to four
    populateGame = ->
      Game
        .findById(req.game._id)
        .populate('players')
        .exec (err, game) ->
          socket.broadcast.emit game.id, game
          socket.emit game.id, game

    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        ps = game.players
        console.log game
        if ps.indexOf(player._id) is -1
          console.log 'adding player to game'
          ps.push player._id
          game.update players: ps, ->
            populateGame()
        else
          populateGame()

  socket.on 'create player', (model, callback) ->
    player = new Player
      name: 'Anonymous'
      turn: true
    player.save (err) ->
      if err then console.log err
      callback player

  socket.on 'read player', (id, callback) ->
    Player.findById id, (err, player) ->
      if err then console.log err
      callback player

  socket.on 'draw discarded', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        player.hand.push game.discarded.pop()
        player.save (err, player) ->
          socket.emit player._id, player
          game.save (err, game) ->
            socket.broadcast.emit game._id, game
            socket.emit game._id, game

  socket.on 'draw mine', (req, callback) ->
    populateGame = (cb) ->
      Game
        .findById(req.game._id)
        .populate('players')
        .exec (err, game) ->
          socket.broadcast.emit game._id, game
          socket.emit game._id, game
          cb() if cb?
    console.log 'draw from mine'
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        if player.turn is true
          if game.mine.length < 1
            socket.emit 'alert', text: 'The Mine is empty!'
          else
            card = game.mine.pop()
            game.save (err) ->
              if card is 'goblin'
                #player.update {hand: [], turn: false}, (err, player) ->
                player.update {hand: []}, (err, player) ->
                  populateGame ->
                    socket.emit 'bust', {}
                  #socket.emit player._id, player
              else
                Player.findByIdAndUpdate req.player._id
                , { $push: { hand: card } }, (err, player) ->
                  populateGame()
                  socket.emit player._id, player
        else
          socket.emit 'alert', text: 'Your turn is over!'

  socket.on 'discard', (req, callback) ->
    console.log req.game
    Game.findById req.game._id, (err, game) ->
      console.log game
      Player.findById req.player._id, (err, player) ->
        # Remove card from player's hand and add it to the game.discarded.
        game.discarded.push player.hand.splice(player.hand.indexOf(req.card), 1)
        player.save (err, player) ->
          socket.emit player._id, player
          game.save (err, game) ->
            socket.broadcast.emit game._id, game
            socket.emit game._id, game

  socket.on 'sort hand', (req, callback) ->
    newPoints = 0
    value =
      emerald: 1
      ruby: 3
      diamond: 5
    Player.findById req.player._id, (err, player) ->
      for card in req.hand
        newPoints += value[card]
      if newPoints == player.points
        player.update hand: req.hand, ->
          socket.broadcast.emit player._id, player
          socket.emit player._id, player

mongoose.connect 'mongodb://localhost/test'
db = mongoose.connection
db.on('error', console.error.bind(console, 'connection error:'))
db.once 'open', ->
  console.log 'Connected to mongo!'

# Create model
Game = mongoose.model 'Game', models.gameSchema
Player = mongoose.model 'Player', models.playerSchema
#Deck = mongoose.model 'Deck', models.deckSchema

server.listen 3000
console.log 'Listening on port 3000'
