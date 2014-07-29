module.exports = (app, config) ->
  homeSection = require('../sections/home/home')
  userSection = require('../sections/user')(config)
  dataSection = require('../sections/data')
  gcalSection = require('../sections/gcal')(config)
  
  app.get '/api/core/auth/google', userSection.authGoogle
  app.get '/api/core/auth/google/callback', userSection.authGoogleCallback
  app.get '/api/core/auth/check_login', userSection.checkLogin
  
  app.use '/api/core/data/', userSection.checkLoginFilter
  app.use '/api/core/gcal/', userSection.checkLoginFilter

  app.get '/api/core/data/get_last_modified', dataSection.getLastModified
  app.get '/api/core/data/:appName/:tableName', dataSection.getDataSet
  app.post '/api/core/data/:appName/:tableName', dataSection.postDataSet
  app.get '/api/core/gcal/', gcalSection.getEvents

  app.use (err, req, res, next) ->
      console.log 'error'
      # treat as 404
      if err.message && (err.message.indexOf('not found') >= 0 || (err.message.indexOf('Cast to ObjectId failed') >= 0))
        return next()

      # log it
      # send emails if you want
      console.error(err.stack)

      # error page
      res.status(500).render('home/500', { error: err.stack })

    # assume 404 since no middleware responded
    app.use (req, res, next) ->
      res.status(404).render('home/404', {
        url: req.originalUrl,
        error: 'Not found'
      })
