express = require 'express' 
fs = require('fs')

env = process.env.NODE_ENV || 'development'
config = require('./server/config/config')[env]
mongoose = require('mongoose')

mongoose.connect(config.db)

# Bootstrap models
#models_path = __dirname + '/server/models'
#fs.readdirSync(models_path).forEach (file) ->
#  require(models_path + '/' + file) if (file.indexOf('.coffee') >= 0)
require('./server/models/user')

app = express()

require('./server/config/express')(app, config)
  
require('./server/config/routes')(app, config)
  
if process.env.NODE_ENV == 'development'
  app.listen config.serverPort, "0.0.0.0"
else
  app.listen config.serverPort

console.log "Listening on mode: #{env}, port: #{config.serverPort}"

exports = module.exports = app