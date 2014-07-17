module.exports = (app, config) ->
  homeSection = require('../sections/home/home')
  userSection = require('../sections/user')(config)
  dataSection = require('../sections/data')
  gcalSection = require('../sections/gcal')(config)
  
  app.get '/auth/google', userSection.authGoogle
  app.get '/auth/google/callback', userSection.authGoogleCallback
  app.get '/auth/check_login', userSection.checkLogin
  
  app.use '/data/', userSection.checkLoginFilter
  app.use '/gcal/', userSection.checkLoginFilter

  app.get '/data/get_last_modified', dataSection.getLastModified
  app.get '/data/:appName/:tableName', dataSection.getDataSet
  app.post '/data/:appName/:tableName', dataSection.postDataSet
  app.get '/gcal/', gcalSection.getEvents
  app.get '/*', homeSection.index

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
