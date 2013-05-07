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
    game.deal()
    console.log game.log
    game.save (err) ->
      callback game

  socket.on 'read game', (id, callback) ->
    Game.findById id, (err, game) ->
      callback game

  socket.on 'game add player', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        if game.players.length <= 4 and game.players.indexOf(player._id) is -1
          game.players.push player._id
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
        game.save -> player.save ->
          socket.broadcast.emit game.id, game
          socket.emit game.id, game
          socket.emit player._id, player

  socket.on 'create player', (model, callback) ->
    player = new Player
      name: 'Anonymous'
      turn: true
      points: 0
      draws: 1
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

          if player.hand.last() is 'goblin'
            game.monster = player.hand.last()
            game.monsterHP = 20
            player.hand.pop()
            player.draw++
            game.monsterLoot.push player.hand.splice(Number.random(player.hand.length-1), 1)
            game.log.push 'A Goblin appears!'
            game.log.push "The Goblin stole a card from #{player.name}'s hand."
          if player.hand.last() is 'werewolf'
            game.monster = player.hand.last()
            game.monsterHP = 40
            player.hand.pop()
            player.draw++
            game.monsterLoot.push player.hand.splice(Number.random(player.hand.length-1), 1)
            game.log.push "The Werewolf stole a card from #{player.name}'s hand."
            game.log.push 'A Werewolf appears!'
          if player.hand.last() is 'triclops'
            game.monster = player.hand.last()
            game.monsterHP = 80
            player.hand.pop()
            player.draw++
            game.monsterLoot.push player.hand.splice(Number.random(player.hand.length-1), 1)
            game.log.push 'A Triclops appears!'
            game.log.push "The Triclops stole a card from #{player.name}'s hand."
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

  socket.on 'play', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        player.discard req.card, ->
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
    console.log 'endin turn'
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        if player.turn
          game.log.push "#{player.name} ended his turn."
          player.turn = false
          player.draws = 1
          player.points = 0
          draws = 3 - player.hand.length
          if draws > 0
            player.drawFrom player.discarded for [1..draws]
          game.save -> player.save ->
            position = game.players.indexOf player.id
            position++
            socket.emit player._id, player
            if position > game.players.length - 1
              position = 0
            Player.findById game.players[position], (err, player) ->
              player.turn = true
              player.plays = 1
              if game.monster
                console.log 'stealin loot'
                game.monsterLoot.push player.hand.splice(Number.random(player.hand.length-1), 1)
                game.log.push "The #{game.monster} stole a card from #{player.name}'s hand."
              game.save -> player.save ->
                socket.emit player._id, player
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
            player.save ->
              socket.emit player._id, player

  socket.on 'send message', (req, callback) ->
    Game.findById req.game._id, (err, game) ->
      Player.findById req.player._id, (err, player) ->
        game.log.push "#{player.name}: #{req.message}"
        game.save ->
          socket.broadcast.emit game.id, game
          socket.emit game.id, game




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
