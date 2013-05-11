mongoose = require 'mongoose'
models = require './models'
_ = require 'underscore'
sugar = require 'sugar'
express = require('express')

#TODO: mine not updating
#TODO: goblin stealing doesn't show up on client
#TODO: goblin defeat doesn't show up on client
#TODO: fix goblin defeat log message

app = express()
server = require('http').createServer(app)
io = require('socket.io').listen(server, {log: false})

# Needed by heroku because it doesn't support websockets.. dafuq heroku..
io.configure ->
  io.set 'transports', ['xhr-polling']
  io.set 'polling duration', 10

io.sockets.on 'connection', (socket) ->

  socket.on 'create game', (model, callback) ->
    game = new Game
    game.started = false
    #game.deal()
    game.save (err) ->
      callback game

  socket.on 'read game', (id, callback) ->
    Game.findById id, (err, game) ->
      callback game

  socket.on 'start game', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      game.started = true
      position = Number.random game.players.length - 1
      Player.findById game.players[position], (err, player) ->
        player.turn = true
        game.deal()
        console.log game.players
        player.save -> game.populate 'players', (err, game) ->
          socket.emit player._id, player
          game.save ->
            socket.broadcast.emit game._id, game
            socket.emit game._id, game

  socket.on 'join game', (req, callback) ->
    console.log 'join game'
    console.log req
    # Join game being called before create player callback is fired.
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        if game.players.length <= 4 and game.players.indexOf(player._id) is -1
          game.players.push player
          game.log.push "#{player.name} joined the game."
          player.hand = []
          player.plays = 1
          player.points = 0
          player.discarded = do ->
            deck = []
            deck.push('emerald') for [1..4]
            deck.push('sword') for [1..2]
            return deck.randomize()
          player.drawFrom(player.discarded) for [1..3]
          player.draws = 1
        game.populate 'players', (err, game) ->
          game.save -> player.save ->
            socket.broadcast.emit game.id, game
            socket.emit game.id, game
            socket.emit player._id, player

  socket.on 'create player', (model, callback) ->
    console.log 'create player'
    player = new Player
      name: 'Anonymous'
      turn: false
      points: 0
      draws: 1
    player.save (err) ->
      callback player

  socket.on 'read player', (id, callback) ->
    Player.findById id, (err, player) ->
      callback player

  socket.on 'draw', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        monster = false
        monster = true if req.deck is 'mine' and game.monster
        #if player.turn and player.draws > 0 and not game.monster
        if player.turn and player.draws > 0 and not monster
          player.draws--
          deck = game.mine if req.deck is 'mine'
          deck = player.discarded if req.deck is 'discarded'
          player.drawFrom deck
          if req.deck is 'mine'
            game.log.push "#{player.name} drew a card from the Mine."
          else
            game.log.push "#{player.name} drew a card from their deck."

          if player.hand[0] is 'goblin'
            game.monster = player.hand[0]
            game.monsterHP = 20
            player.hand.splice(0, 1)
            player.draw++
            game.monsterLoot.push player.hand.splice(Number.random(player.hand.length-1), 1)
            game.log.push 'A Goblin appears!'
            game.log.push "The Goblin stole a card from #{player.name}'s hand."
          if player.hand[0] is 'werewolf'
            game.monster = player.hand[0]
            game.monsterHP = 40
            player.hand.splice(0,1)
            player.draw++
            game.monsterLoot.push player.hand.splice(Number.random(player.hand.length-1), 1)
            game.log.push "The Werewolf stole a card from #{player.name}'s hand."
            game.log.push 'A Werewolf appears!'
          if player.hand[0] is 'triclops'
            game.monster = player.hand[0]
            game.monsterHP = 80
            player.hand.splice(0,1)
            player.draw++
            game.monsterLoot.push player.hand.splice(Number.random(player.hand.length-1), 1)
            game.log.push 'A Triclops appears!'
            game.log.push "The Triclops stole a card from #{player.name}'s hand."
          game.save -> player.save ->
            socket.emit player._id, player
            socket.broadcast.emit game._id, game
            socket.emit game._id, game

  socket.on 'discard', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        player.discard req.card, game, ->
          socket.emit player._id, player
          socket.broadcast.emit game._id, game
          socket.emit game._id, game

  socket.on 'play', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        if player.turn
          player.play req.card, game, ->
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

  socket.on 'end turn', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        if player.turn
          # End turn, reset draws, points, and plays.
          # Redraw cards and save.
          game.log.push "#{player.name} ended his turn."
          player.turn = false
          player.draws = 1
          player.points = 0
          player.plays = 1
          draws = 3 - player.hand.length
          if draws > 0
            player.drawFrom player.discarded for [1..draws]
          # Save and emit change to client.
          player.save -> socket.emit player._id, player
          # Move turn to next player
          position = game.players.indexOf player.id
          position++
          if position > game.players.length - 1
            position = 0
          # Find next player and start their turn.
          Player.findById game.players[position], (err, player) ->
            player.turn = true
            if game.monster
              game.monsterLoot.push player.hand.splice(Number.random(player.hand.length-1), 1)
              game.log.push "The #{game.monster} stole a card from #{player.name}'s hand."
            player.save ->
              socket.emit player._id, player
              game.populate 'players', (err, game) -> game.save ->
                socket.broadcast.emit game._id, game
                socket.emit game._id, game

  socket.on 'buy', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        shop =
          sword: 1
          axe: 3
          pickaxe: 2
        if player.turn
          if player.points >= shop[req.card]
            player.points -= shop[req.card]
            player.hand.push req.card
            game.log.push "#{player.name} bought a #{req.card}."
            game.save -> player.save ->
              socket.emit game._id, game
              socket.broadcast.emit game._id, game
              socket.emit player._id, player

  socket.on 'send message', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        game.log.push "#{player.name}: #{req.message}"
        game.save ->
          socket.broadcast.emit game.id, game
          socket.emit game.id, game

  socket.on 'change name', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        player.name = req.name
        player.save ->
          if game
            game.populate 'players', (err, game) ->
              game.save ->
                socket.broadcast.emit game.id, game
                socket.emit game.id, game
                socket.emit player.id, player
          else
            socket.emit player.id, player

mongoose.connect process.env.MONGOLAB_URI || 'mongodb://localhost/test'
db = mongoose.connection
db.on('error', console.error.bind(console, 'connection error:'))
db.once 'open', ->
  console.log 'Connected to mongo!'

# Create model
Game = mongoose.model 'Game', models.gameSchema
Player = mongoose.model 'Player', models.playerSchema
#Deck = mongoose.model 'Deck', models.deckSchema

server.listen process.env.PORT || 3000
console.log 'Listening on some port..'
