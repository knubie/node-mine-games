// Generated by CoffeeScript 1.4.0
(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  require.config({
    baseUrl: 'js/vendor',
    shim: {
      'zepto': {
        exports: '$'
      },
      'socket.io': {
        exports: 'io'
      },
      'backbone': {
        deps: ['underscore', 'zepto'],
        exports: 'Backbone'
      },
      'underscore': {
        exports: '_'
      }
    },
    paths: {
      'models': '../models',
      'socket.io': 'http://localhost:3000/socket.io/socket.io',
      'views': '../views'
    }
  });

  define(function(require) {
    var $, AppScroll, Backbone, Fastclick, io, models, views, _;
    $ = require('zepto');
    _ = require('underscore');
    Backbone = require('backbone');
    io = require('socket.io');
    Fastclick = require('fastclick');
    AppScroll = require('appscroll');
    models = require('models');
    views = require('views');
    return $(function() {
      var Routes, app, socket;
      FastClick.attach(document.body);
      app = {
        url: "http://localhost:3000"
      };
      socket = io.connect(app.url);
      Backbone.sync = function(method, model, options) {
        if (method === 'create') {
          socket.emit("create " + model.name, model, options.success);
        }
        if (method === 'read') {
          return socket.emit("read " + model.name, model.id, options.success);
        }
      };
      Routes = (function(_super) {

        __extends(Routes, _super);

        function Routes() {
          return Routes.__super__.constructor.apply(this, arguments);
        }

        Routes.prototype.routes = {
          '': 'home',
          'games/create': 'createGame',
          'games/:id': 'showGame'
        };

        Routes.prototype.home = function() {
          app.player = new models.Player;
          if (app.view != null) {
            app.view.remove();
          }
          return app.view = new views.Home({
            model: app.player,
            router: this
          });
        };

        Routes.prototype.createGame = function() {
          var _this = this;
          app.game = new models.Game;
          return app.game.save({}, {
            success: function() {
              socket.on(app.game.id, function(game) {
                return app.game.set(game);
              });
              return _this.navigate("games/" + app.game.id, {
                trigger: true
              });
            }
          });
        };

        Routes.prototype.showGame = function(id) {
          app.game = new models.Game({
            _id: id
          });
          return app.player = new models.Player({
            afterSave: function() {
              app.game.addPlayer(app.player);
              if (app.view != null) {
                app.view.remove();
              }
              app.view = new views.Game({
                model: app.game,
                player: app.player
              });
              return app.view.render();
            }
          });
        };

        return Routes;

      })(Backbone.Router);
      app.routes = new Routes;
      return Backbone.history.start();
    });
  });

}).call(this);
