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
            console.log('got game broadcast');
            console.log(game);
            return _this.set(game);
          });
        };

        _Class.prototype.name = 'game';

        return _Class;

      })(Backbone.Model),
      Player: (function(_super) {

        __extends(_Class, _super);

        function _Class() {
          return _Class.__super__.constructor.apply(this, arguments);
        }

        _Class.prototype.initialize = function() {
          var _this = this;
          return socket.on(this.id, function(player) {
            console.log('got player broadcast');
            console.log(player);
            return _this.set(player);
          });
        };

        _Class.prototype.name = 'player';

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
              app.game.set('id', app.game.get('_id'));
              console.log(app.game);
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
          var _this = this;
          app.game.on('change', function() {
            return _this.render();
          });
          return app.player.on('change', function() {
            return _this.render();
          });
        };

        _Class.prototype.id = 'game';

        _Class.prototype.template = $('#game-template').html();

        _Class.prototype.render = function() {
          this.$el.html(Mustache.render(this.template, {
            game: app.game.attributes,
            players: app.game.get('players'),
            hand: app.player.get('hand'),
            player: app.player.attributes
          }));
          $('#container').append(this.$el);
          return this;
        };

        _Class.prototype.events = {
          'click #mine': 'draw'
        };

        _Class.prototype.draw = function() {
          return socket.emit('draw mine', {
            game: app.game,
            player: app.player
          });
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
        fetchGame = function() {
          app.game = new models.Game({
            id: id
          });
          app.view = new views.Game;
          return socket.emit('game add player', {
            player: app.player,
            game: app.game
          });
        };
        app.player = new models.Player({
          id: sessionStorage.getItem('player id') || null
        });
        if (app.player.isNew()) {
          return app.player.save({}, {
            success: function() {
              app.player.set('id', app.player.get('_id'));
              sessionStorage.setItem('player id', app.player.id);
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
