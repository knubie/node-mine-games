mongoose = require 'mongoose'
sugar = require 'sugar'
Schema = mongoose.Schema

# Schemas
exports.gameSchema = new Schema
  mine        : Array
  discarded   : Array
  started     : Boolean
  log         : Array
  monster     : String
  monsterHP   : Number
  monsterLoot : Array
  players: [
    type: Schema.Types.ObjectId
    ref: 'Player'
  ]

exports.gameSchema.method
  deal: ->
    @players = []
    @discarded = []
    @log = ['Creating new game.']
    @mine = do ->
      mine1 = []
      mine2 = []
      mine3 = []
      mine1.push('emerald') for [1..5]
      mine1.push('ruby') for [1..4]
      mine1.push('diamond') for [1..2]
      mine1.push('goblin') for [1..5]

      mine2.push('emerald') for [1..4]
      mine2.push('ruby') for [1..5]
      mine2.push('diamond') for [1..2]
      mine2.push('werewolf') for [1..5]

      mine3.push('emerald') for [1..2]
      mine3.push('ruby') for [1..4]
      mine3.push('diamond') for [1..5]
      mine3.push('triclops') for [1..5]

      mine1 = mine1.randomize()
      mine2 = mine2.randomize()
      mine3 = mine3.randomize()
      return mine3.concat mine2, mine1

exports.deckSchema = new Schema
  player:
    type: Schema.Types.ObjectId
    ref: 'Player'
  cards: Array

exports.playerSchema = new Schema
  name      : String
  hand      : Array
  discarded : Array
  points    : Number
  draws     : Number
  plays     : Number
  turn      : Boolean
  decks: [
    type: Schema.Types.ObjectId
    ref: 'Deck'
  ]

exports.playerSchema.method
  drawFrom: (deck) ->
    #@draws--
    if deck.length > 0 then @hand.unshift deck.pop()

  discard: (card) ->
    @discarded.push @hand.splice(@hand.indexOf(card), 1)
    @discarded = @discarded.randomize()

  play: (card, game, cb) ->
    gem =
      emerald: true
      ruby: true
      diamond: true

    attack = (dmg) =>
      if game.monsterHP > 0
        game.monsterHP -= dmg
        game.log.push "The #{game.monster} takes #{dmg} points of damage."
        if game.monsterHP <= 0
          game.monsterHP = 0
          game.monster = ''

          #@hand.add game.monsterLoot
          @hand = @hand.concat game.monsterLoot
          game.log.push "#{@name} defeats the #{game.monster} and collects its loot."
          game.monsterLoot = []

    play =
    # Gems
      emerald: => @points += 1
      ruby: => @points += 2
      diamond: => @points += 3
    # Action cards
      pickaxe: => @draws += 1
      sword: => attack(5)
      axe: => attack(10)

    if gem[card] or @plays > 0 # If card is a gem
      console.log "discarding, points: #{@points}"
      @discard card
      play[card]()
      @plays-- if not gem[card]
      game.log.push "#{@name} played a #{card}."

    @save -> game.save -> cb()
