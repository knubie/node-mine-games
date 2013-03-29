mongoose = require 'mongoose'
Schema = mongoose.Schema

# Schemas
exports.gameSchema = new Schema
  players: [String]
  mine: Array

exports.deckSchema = new Schema
  player:
    type: Schema.Types.ObjectId
    ref: 'Player'
  cards: Array

exports.playerSchema = new Schema
  name: String
  decks: [
    type: Schema.Types.ObjectId
    ref: 'Deck'
  ]

exports.playerSchema.method
  draw: (deck) ->
    console.log 'drawing a card'
  discard: (deck) ->
    console.log 'discarding a card'
