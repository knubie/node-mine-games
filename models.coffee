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
  decks: [
    type: Schema.Types.ObjectId
    ref: 'Deck'
  ]
  turn: Boolean

exports.playerSchema.virtual('points').get ->
  points = 0
  value =
    emerald: 1
    ruby: 3
    diamond: 5
  for card in @hand
    points += value[card]

  return points


exports.playerSchema.method
  draw: (deck) ->
    console.log 'drawing a card'
  discard: (deck) ->
    console.log 'discarding a card'
