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
        mine.push('emerald') for [1..7]
        mine.push('ruby') for [1..7]
        mine.push('diamond') for [1..7]
        #mine.push('goblin') for [1..5]
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
        if ps.indexOf(player._id) is -1
          ps.push player._id
          game.update players: ps, ->
            populateGame()
        else
          populateGame()

  socket.on 'create player', (model, callback) ->
    player = new Player
      name: 'Anonymous'
      turn: true
      points: 0
    player.save (err) ->
      if err then console.log err
      callback player

  socket.on 'read player', (id, callback) ->
    Player.findById id, (err, player) ->
      if err then console.log err
      callback player

  socket.on 'draw', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        if player.turn is true
          player.drawFrom game[req.deck]
          player.save -> socket.emit player._id, player
          game.save ->
            socket.broadcast.emit game._id, game
            socket.emit game._id, game

  socket.on 'discard', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        player.discard req.card, game, ->
          socket.emit player._id, player
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
