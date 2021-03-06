// Generated by CoffeeScript 1.4.0
(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  define(['underscore', 'backbone', 'socket.io'], function(_, Backbone, io) {
    var app, socket;
    app = {
      url: "http://localhost:3000"
    };
    socket = io.connect(app.url);
    return {
      Game: (function(_super) {

        __extends(_Class, _super);

        function _Class() {
          return _Class.__super__.constructor.apply(this, arguments);
        }

        _Class.prototype.initialize = function() {
          var _this = this;
          if (!this.isNew()) {
            return this.fetch({
              success: function() {
                return socket.on(_this.id, function(game) {
                  return _this.set(game);
                });
              }
            });
          }
        };

        _Class.prototype.idAttribute = '_id';

        _Class.prototype.name = 'game';

        _Class.prototype.monster = '';

        _Class.prototype.monsterHP = 0;

        _Class.prototype.log = [];

        _Class.prototype.addPlayer = function(player) {
          return socket.emit('join game', {
            player: player,
            game: this
          });
        };

        _Class.prototype.start = function() {
          return socket.emit('start game', {
            game: this
          });
        };

        return _Class;

      })(Backbone.Model),
      Player: (function(_super) {

        __extends(_Class, _super);

        function _Class() {
          return _Class.__super__.constructor.apply(this, arguments);
        }

        _Class.prototype.initialize = function() {
          var _this = this;
          this.set({
            _id: sessionStorage.getItem('player id') || null
          });
          if (this.isNew()) {
            return this.save({}, {
              success: function() {
                sessionStorage.setItem('player id', _this.id);
                socket.on(_this.id, function(player) {
                  _this.set(player);
                  return console.log('got player emit');
                });
                if (_this.get('afterSave')) {
                  return _this.get('afterSave')();
                }
              }
            });
          } else {
            return this.fetch({
              success: function() {
                socket.on(_this.id, function(player) {
                  console.log('got player emit');
                  return _this.set(player);
                });
                if (_this.get('afterSave')) {
                  return _this.get('afterSave')();
                }
              }
            });
          }
        };

        _Class.prototype.idAttribute = '_id';

        _Class.prototype.name = 'player';

        _Class.prototype.points = 0;

        _Class.prototype.draws = 1;

        _Class.prototype.changeName = function(name, game) {
          return socket.emit('change name', {
            game: game || {
              _id: 0
            },
            player: this,
            name: name
          });
        };

        _Class.prototype.sortHand = function(hand) {
          return socket.emit('sort hand', {
            player: this,
            hand: hand
          });
        };

        _Class.prototype.discard = function(card) {
          return socket.emit('discard', {
            game: app.game.attributes,
            player: this,
            card: card
          });
        };

        _Class.prototype.play = function(card, game) {
          return socket.emit('play', {
            game: game,
            player: this,
            card: card
          });
        };

        _Class.prototype.draw = function(deck, game) {
          return socket.emit('draw', {
            game: game,
            player: this,
            deck: deck
          });
        };

        _Class.prototype.buy = function(card, game) {
          return socket.emit('buy', {
            game: game,
            player: this,
            card: card
          });
        };

        _Class.prototype.endTurn = function(game) {
          return socket.emit('end turn', {
            game: game,
            player: this
          });
        };

        _Class.prototype.say = function(message, game) {
          return socket.emit('send message', {
            game: game,
            player: this,
            message: message
          });
        };

        return _Class;

      })(Backbone.Model)
    };
  });

}).call(this);
