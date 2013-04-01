player1 = require('casper').create()
player2 = require('casper').create()

player1.start 'file://localhost/Users/Matt/Development/node-mine-games/client/index.html'

player1.then ->
  @test.assertExists '#new-game', 'Home view rendered.'

currentUrl = ''
player1.thenClick '#new-game', ->
  currentUrl = @getCurrentUrl()
  @test.assert /.*#games\/\d+\w+\d+/.test(@getCurrentUrl())
  , 'Game created with ID in url.'

  @test.assertSelectorHasText '#mine', 'Mine (40)'
  , 'Mine has correct number of cards (40).'

  @test.assertSelectorHasText '#players', 'Players: 1'
  , 'View has correct number of players (1).'

  @test.assertSelectorHasText '#players', 'Anonymous'
  , 'View has correct player name (Anonymous).'

  @reload ->
    @test.comment 'Reloaded.'
    @test.assertSelectorHasText '#players', 'Players: 1'
    , 'View still has correct number of players(1) after reloading.'

    player2.start currentUrl
    player2.then ->
      @test.comment 'Starting new session with current game.'
      @test.assertSelectorHasText '#players', 'Players: 2'
      , 'View has correct number of players(2).'

      player1.click '#mine'

    player2.then ->
      @test.comment 'Drawing from mine.'
      player1.test.assertSelectorHasText '#mine', 'Mine (39)'
      , 'Player1: Correct number of cards in mine(39).'

      player1.test.assertExists '.card'
      , 'Player1: Hand has updated with a new card.'

      player2.test.assertSelectorHasText '#mine', 'Mine (39)'
      , 'Player2: Correct number of cards in mine(39).'


player1.run ->
  player2.run()
