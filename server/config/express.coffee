express = require('express')
cors = require('cors')
morgan = require('morgan')
bodyParser = require('body-parser')
staticFavicon = require('static-favicon')
serveStatic = require('serve-static')
connect = require('connect')
cookieParser = require('cookie-parser')
session = require('express-session')
RedisStore = require('connect-redis')(session)
Lazy = require('lazy.js')

module.exports = (app, config) ->
  corsOptions = {
    origin: (origin, callback) ->
      originIsWhitelisted = Lazy(config.allowedDomains).findWhere({url: origin})?
      callback(null, originIsWhitelisted)
    }
    
  app.use(staticFavicon())
  app.enable('trust proxy')

  app.use(serveStatic(config.root + '/public'))
  
  if (process.env.NODE_ENV != 'test')
    app.use(morgan('dev'))
  
  app.set('views', config.root + '/server/sections');
  app.set('view engine', 'jade');


  app.use(bodyParser({limit: '50mb'}));

  app.use(cookieParser(config.cookieSecret))

  sessionStore = new RedisStore(host: config.redis.host, port: config.redis.port, db: config.redis.db, ttl: (60*60*24*7))
  sessionStore.on 'disconnect', () ->
    console.log('Could not connect to redis/got disconnected');
    process.exit(1);

  app.use(session({
    secret: config.sessionSecret
    store: sessionStore
    cookie: { maxAge: 60*60*24*7*1000 }
  }))

  #app.use(passport.initialize());
  #app.use(passport.session());
  app.use(cors(corsOptions));
