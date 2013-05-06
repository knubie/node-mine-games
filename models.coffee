mongoose = require 'mongoose'
sugar = require 'sugar'
Schema = mongoose.Schema

# Schemas
exports.gameSchema = new Schema
  players: [
    type: Schema.Types.ObjectId
    ref: 'Player'
  ]
  mine: Array
  discarded: Array
  log: Array
  monster: String
  monsterHP: Number
  monsterLoot: Array

exports.deckSchema = new Schema
  player:
    type: Schema.Types.ObjectId
    ref: 'Player'
  cards: Array

exports.playerSchema = new Schema
  name: String
  hand: Array
  discarded: Array
  points: Number
  draws: Number
  decks: [
    type: Schema.Types.ObjectId
    ref: 'Deck'
  ]
  turn: Boolean

exports.playerSchema.method
  drawFrom: (deck) ->
    #@draws--
    if deck.length > 0 then @hand.push deck.pop()

  discard: (card, game, cb) ->
    gem =
      emerald: true
      ruby: true
      diamond: true

    #if gem[card]
      #@hand.splice(@hand.indexOf(card), 1)
    #else
    @discarded.push @hand.splice(@hand.indexOf(card), 1)
    @discarded = @discarded.randomize()

    @save -> game.save -> cb()

  play: (card, game, cb) ->
    attack = (dmg) =>
      if game.monsterHP > 0
        game.monsterHP -= dmg
        if game.monsterHP <= 0
          game.monsterHP = 0
          game.monster = ''

          #@hand.add game.monsterLoot
          @hand = @hand.concat game.monsterLoot
          game.monsterLoot = []

    cards =
    # Gems
      emerald: => @points += 1
      ruby: => @points += 2
      diamond: => @points += 3
    # Action cards
      pickaxe: => @draws += 1
      sword: => attack(5)
      axe: => attack(10)

    cards[card]()
    game.log.push "#{@name} played a #{card}."
    @save -> game.save -> cb()

