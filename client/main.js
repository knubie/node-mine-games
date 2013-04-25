// Generated by CoffeeScript 1.4.0
(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  $(function() {
    var Routes, app, hand, models, socket, views;
    app = {
      url: "http://localhost:3000"
    };
    hand = [];
    socket = io.connect(app.url);
    socket.on("alert", function(message) {
      return alert(message.text);
    });
    socket.on('bust', function() {
      $('#hand').append("<div class='card gem goblin'></div>");
      return $('#hand').children().fadeOut(function() {
        return app.player.fetch(function(player) {
          return app.player.set(player);
        });
      });
    });
    socket.on('score', function() {
      $('#hand').append("<div class='card gem emerald'></div>");
      return $('#hand').children().fadeOut(function() {
        return app.player.fetch(function(player) {
          return app.player.set(player);
        });
      });
    });
    Backbone.sync = function(method, model, options) {
      if (method === 'create') {
        socket.emit("create " + model.name, model, options.success);
      }
      if (method === 'read') {
        return socket.emit("read " + model.name, model.id, options.success);
      }
    };
    models = {
      Game: (function(_super) {

        __extends(_Class, _super);

        function _Class() {
          return _Class.__super__.constructor.apply(this, arguments);
        }

        _Class.prototype.initialize = function() {
          var _this = this;
          return socket.on(this.id, function(game) {
            _this.set(game);
            return app.view.mine.render();
          });
        };

        _Class.prototype.idAttribute = '_id';

        _Class.prototype.name = 'game';

        _Class.prototype.addPlayer = function(player) {
          return socket.emit('game add player', {
            player: player,
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
          this.set('hand', []);
          return socket.on(this.id, function(player) {
            console.log('player updated');
            _this.set(player);
            return console.log(player);
          });
        };

        _Class.prototype.idAttribute = '_id';

        _Class.prototype.name = 'player';

        _Class.prototype.sortHand = function(hand) {
          return socket.emit('sort hand', {
            player: this.attributes,
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

        return _Class;

      })(Backbone.Model)
    };
    views = {
      Home: (function(_super) {

        __extends(_Class, _super);

        function _Class() {
          return _Class.__super__.constructor.apply(this, arguments);
        }

        _Class.prototype.id = 'home';

        _Class.prototype.template = $('#home-template').html();

        _Class.prototype.render = function() {
          this.$el.html(Mustache.render(this.template));
          $('#container').append(this.$el);
          return this;
        };

        _Class.prototype.events = {
          'click #new-game': 'createGame'
        };

        _Class.prototype.createGame = function() {
          app.game = new models.Game;
          return app.game.save({}, {
            success: function() {
              return app.routes.navigate("games/" + app.game.id, {
                trigger: true
              });
            }
          });
        };

        return _Class;

      })(Backbone.View),
      Game: (function(_super) {

        __extends(_Class, _super);

        function _Class() {
          return _Class.__super__.constructor.apply(this, arguments);
        }

        _Class.prototype.initialize = function() {
          this.hand = new views.Hand;
          this.hand.render();
          this.discarded = new views.Discarded;
          this.discarded.render();
          this.points = new views.Points;
          this.points.render();
          this.players = new views.Players;
          this.players.render();
          this.mine = new views.Mine;
          return this.mine.render();
        };

        _Class.prototype.template = $('#game-template').html();

        return _Class;

      })(Backbone.View),
      Mine: (function(_super) {

        __extends(_Class, _super);

        function _Class() {
          return _Class.__super__.constructor.apply(this, arguments);
        }

        _Class.prototype.initialize = function() {
          var _this = this;
          app.game.on('change', function() {
            return _this.render;
          });
          this.$el.addClass('card');
          return this.$el.insertBefore('#game > #droppable-one');
        };

        _Class.prototype.id = 'mine';

        _Class.prototype.template = $('#mine-template').html();

        _Class.prototype.render = function() {
          return this.$el.html(Mustache.render(this.template, {
            mine: app.game.get('mine')
          }));
        };

        _Class.prototype.events = {
          'click': 'draw'
        };

        _Class.prototype.draw = function() {
          return socket.emit('draw', {
            game: app.game,
            player: app.player,
            deck: 'mine'
          });
        };

        return _Class;

      })(Backbone.View),
      Hand: (function(_super) {

        __extends(_Class, _super);

        function _Class() {
          return _Class.__super__.constructor.apply(this, arguments);
        }

        _Class.prototype.initialize = function() {
          var _this = this;
          app.player.on('change', function() {
            return _this.render();
          });
          return this.$el.insertAfter('#game > #droppable-one');
        };

        _Class.prototype.id = 'hand';

        _Class.prototype.template = $('#hand-template').html();

        _Class.prototype.render = function() {
          console.log('render hand');
          this.$el.html(Mustache.render(this.template, {
            hand: app.player.get('hand')
          }));
          $('#hand').children().draggable();
          return $('#droppable-one').droppable({
            accept: '#hand > .card',
            drop: function(e, ui) {
              return app.player.discard(ui.draggable.attr('data-card'));
            }
          });
        };

        return _Class;

      })(Backbone.View),
      Discarded: (function(_super) {

        __extends(_Class, _super);

        function _Class() {
          return _Class.__super__.constructor.apply(this, arguments);
        }

        _Class.prototype.initialize = function() {
          var _this = this;
          app.game.on('change:discarded', function() {
            return _this.render();
          });
          return $('#droppable-one').append(this.$el);
        };

        _Class.prototype.id = 'discarded';

        _Class.prototype.template = $('#discarded-template').html();

        _Class.prototype.render = function() {
          this.$el.html(Mustache.render(this.template, {
            discarded: app.game.get('discarded')
          }));
          $('#discarded').children().draggable({
            revert: 'invalid'
          });
          $('#hand').droppable({
            accept: '#discarded > .card',
            drop: function(e, ui) {
              return socket.emit('draw', {
                game: app.game.attributes,
                player: app.player.attributes,
                deck: 'discarded'
              });
            }
          });
          return $('#droppable-two').droppable({
            drop: function(e, ui) {
              ui.draggable.css;
              return app.player.discard(ui.draggable.attr('data-card'));
            }
          });
        };

        return _Class;

      })(Backbone.View),
      Points: (function(_super) {

        __extends(_Class, _super);

        function _Class() {
          return _Class.__super__.constructor.apply(this, arguments);
        }

        _Class.prototype.initialize = function() {
          var _this = this;
          app.player.on('change:points', function() {
            return _this.render();
          });
          return $('#info').prepend(this.$el);
        };

        _Class.prototype.id = 'points';

        _Class.prototype.template = $('#points-template').html();

        _Class.prototype.render = function() {
          return this.$el.html(Mustache.render(this.template, {
            points: app.player.get('points')
          }));
        };

        return _Class;

      })(Backbone.View),
      Players: (function(_super) {

        __extends(_Class, _super);

        function _Class() {
          return _Class.__super__.constructor.apply(this, arguments);
        }

        _Class.prototype.initialize = function() {
          var _this = this;
          app.game.on('change:players', function() {
            return _this.render();
          });
          return $('#info').append(this.$el);
        };

        _Class.prototype.id = 'players';

        _Class.prototype.template = $('#players-template').html();

        _Class.prototype.render = function() {
          return this.$el.html(Mustache.render(this.template, {
            players: app.game.get('players')
          }));
        };

        return _Class;

      })(Backbone.View)
    };
    Routes = (function(_super) {

      __extends(Routes, _super);

      function Routes() {
        return Routes.__super__.constructor.apply(this, arguments);
      }

      Routes.prototype.routes = {
        '': 'home',
        'games/:id': 'showGame'
      };

      Routes.prototype.home = function() {
        if (app.view != null) {
          app.view.remove();
        }
        app.view = new views.Home;
        return app.view.render();
      };

      Routes.prototype.showGame = function(id) {
        var fetchGame;
        if (app.view != null) {
          app.view.remove();
        }
        fetchGame = function() {
          app.game = new models.Game({
            _id: id
          });
          app.view = new views.Game;
          return app.game.addPlayer(app.player);
        };
        app.player = new models.Player({
          _id: sessionStorage.getItem('player id') || null
        });
        if (app.player.isNew()) {
          return app.player.save({}, {
            success: function() {
              sessionStorage.setItem('player id', app.player.id);
              app.player = new models.Player({
                _id: app.player.id
              });
              return fetchGame();
            }
          });
        } else {
          return app.player.fetch({
            success: function() {
              return fetchGame();
            }
          });
        }
      };

      return Routes;

    })(Backbone.Router);
    app.routes = new Routes;
    return Backbone.history.start();
  });

}).call(this);
