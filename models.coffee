mongoose = require 'mongoose'
Schema = mongoose.Schema

# Schemas
exports.gameSchema = new Schema
  players: [
    type: Schema.Types.ObjectId
    ref: 'Player'
  ]
  mine: Array
  discarded: Array

exports.deckSchema = new Schema
  player:
    type: Schema.Types.ObjectId
    ref: 'Player'
  cards: Array

exports.playerSchema = new Schema
  name: String
  hand: Array
  points: Number
  decks: [
    type: Schema.Types.ObjectId
    ref: 'Deck'
  ]
  turn: Boolean

exports.playerSchema.method
  drawFrom: (deck) ->
    if deck.length > 0 then @hand.push deck.pop()

  discard: (card, game, cb) ->
    game.discarded.push @hand.splice(@hand.indexOf(card), 1)
    @save -> game.save -> cb()
