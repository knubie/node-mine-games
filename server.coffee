mongoose = require 'mongoose'
models = require './models'
_ = require 'underscore'
express = require('express')

app = express()
server = require('http').createServer(app)
io = require('socket.io').listen(server)

io.sockets.on 'connection', (socket) ->
  socket.on 'create game', (model, callback) ->
    console.log 'Creating new Game.'
    game = new Game
      #players: model.players
      players: []
      mine: do ->
        mine = []
        mine.push('copper') for [1..20]
        mine.push('silver') for [1..10]
        mine.push('gold') for [1..5]
        mine.push('goblin') for [1..5]
        return _.shuffle(mine)

    console.log 'made game.'
    game.save (err) ->
      if err then console.log err
      console.log 'game saved.'
      callback game

  socket.on 'read game', (id, callback) ->
    Game.findById id, (err, game) ->
      if err then console.log err
      callback game

  socket.on 'draw mine', (id, callback) ->
    console.log 'draw from mine'
    Game.findById id, (err, game) ->
      if err then console.log err
      card = game.mine.pop()
      game.save (err) ->
        socket.broadcast.emit "game update #{id}", game
        callback
          mine: game.mine
          card: card

cors = (req, res, next) ->
  res.header("Access-Control-Allow-Origin", "*")
  res.header("Access-Control-Allow-Headers", "accept, origin, content-type, X-Requested-With")
  res.header('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE')
  next()

app.use express.bodyParser()
app.use cors

mongoose.connect 'mongodb://localhost/test'
db = mongoose.connection
db.on('error', console.error.bind(console, 'connection error:'))
db.once 'open', ->
  console.log 'connected to mongo!'

# Create model
Game = mongoose.model 'Game', models.gameSchema
Player = mongoose.model 'Player', models.playerSchema
#Deck = mongoose.model 'Deck', models.deckSchema

app.options '*', (req, res) ->
  res.send(200)

app.get '/draw/:id', (req, res) ->
  Game.findOne({ _id: req.params.id }).exec (err, game) ->
    card = game.mine.pop()
    game.save()
    res.send(card)

app.get '/game', (req, res) ->
  Game.find({}).exec (err, games) ->
    res.send(games)

app.post '/game', (req, res) ->
  console.log 'Creating new Game.'
  game = new Game
    #players: do ->
      #players = []
      #for player in req.body.players
        #Player.findByIdAndUpdate player.id, player,
          #upsert: true # Create if not found
        #, (err, doc) ->
          #doc.save (err) ->
            #palyers.push doc.id
      #return players
    players: req.body.players
    mine: do ->
      mine = []
      mine.push('copper') for [1..20]
      mine.push('silver') for [1..10]
      mine.push('gold') for [1..5]
      return _.shuffle(mine)

  game.save (err) ->
    if err then console.log err
    res.send(game)

app.get '/game/:id', (req, res) ->
  console.log 'game get'
  Game.findOne({ _id: req.params.id })
  .exec (err, game) ->
    res.send(game)

app.put '/game/:id', (req, res) ->
  console.log 'Updating game.'
  Game.findByIdAndUpdate req.params.id, {players:req.body.players}, ->
    res.end()

app.delete '/game/:id', (req, res) ->
  console.log 'game delete'
  Game.findOne({ _id: req.params.id })
  .exec (err, game) ->
    game.remove()
    res.send(game)

app.get '/player', (req, res) ->
  Player.find({}).exec (err, players) ->
    res.send(players)

app.post '/player', (req, res) ->
  player = new Player
    name: req.body.name
  player.save (err) ->
    res.send(player)

app.get '/player/:id', (req, res) ->
  Player.findOne({ _id: req.params.id })
  .exec (err, player) ->
    res.send(player)

app.put '/player/:id', (req, res) ->
  console.log 'Updating player.'
  #Player.update { _id: req.params.id }, req.body, ->
  Player.findByIdAndUpdate req.params.id, {name:req.body.name}, ->
    res.end()

app.delete '/player/:id', (req, res) ->
  Player.findOne({ _id: req.params.id })
  .exec (err, player) ->
    player.remove()
    res.send(player)

server.listen 3000
console.log 'Listening on port 3000'
