mongoose = require('mongoose')
User = mongoose.model('User')
googleapis = require('googleapis')
OAuth2Client = googleapis.OAuth2Client

User = mongoose.model('User')
Lazy = require('lazy.js')

jwt = require('jsonwebtoken')

module.exports = (config) ->
  completeSite = (req, requestingSite) ->
      fullSite = 'http://' + req.host.replace('api', requestingSite)

      item = Lazy(config.allowedDomains).find((item) -> Lazy(item.url).startsWith(fullSite))
      if item then item.url else item
   
  getCallbackUrl = (req) ->
    req.protocol + '://' + req.get('host') + '/auth/google/callback'

  exports = {}
  exports.authGoogle = (req, res) ->
    req.session.requestingSite = req.query.site
    oauth2Client = new OAuth2Client(config.google.clientID, config.google.clientSecret, getCallbackUrl(req))
    authUrl = oauth2Client.generateAuthUrl({
      access_type: 'offline',
      scope: 'https://www.googleapis.com/auth/plus.login profile email'
      state: req.get('host')
    })
    res.redirect(authUrl)

  exports.authGoogleCallback = (req, res) ->
    oauth2Client = new OAuth2Client(config.google.clientID, config.google.clientSecret, getCallbackUrl(req))
    code = req.query.code
    callbackUrl = req.query.state

    requestingSite = req.session.requestingSite
    fullSite = completeSite(req, requestingSite)
    
    if !fullSite
      console.log 'You are trying to reach site that is not allowed: ', requestingSite
      res.send(400, 'You are trying to reach site that is not allowed')
      return

    # functions
    getAccessToken = (callback) ->
      oauth2Client.getToken code, (err, tokens) ->
        oauth2Client.setCredentials(tokens)
        console.log(tokens)
        callback()

    getUserProfile = (callback) ->
      googleapis.discover('plus', 'v1').execute (err, client) ->
        client
        .plus.people.get({ userId: 'me' })
        .withAuthClient(oauth2Client)
        .execute(callback)

    performAuthWithProfile = (profile, callback) -> 
      User.findOne { googleId: profile.id }, (err, user) ->
        if !user
          user = new User({
            name: profile.displayName,
            email: profile.emails[0].value,
            provider: 'google',
            googleId: profile.id,
            authToken: oauth2Client.credentials.access_token
          })
          user.save (err) ->
            if (err) 
              console.log(err)
            else
              console.log 'saved user for session', user
              callback(err, user)
        else
          user.name = profile.displayName
          user.email = profile.emails[0].value
          user.authToken = oauth2Client.credentials.access_token
          user.save (err) ->
            callback(err, user)

    #  method body
    getAccessToken ->
      getUserProfile (err, profile) ->
        performAuthWithProfile profile, (err, user) ->
          profile = {
            id: user.id
          }
          token = jwt.sign(profile, config.sessionSecret, { expiresInMinutes: (60*60*24*7) });
          res.redirect(fullSite + '/login_success?token=' + token)

  exports.checkLogin = (req, res) ->
    fail = -> res.json 401, {reason: 'not_logged_in'}
    token = req.headers.authorization
    if !token
      console.log('fail auth, no token')
      fail()
    else
      jwt.verify token, config.sessionSecret, (err, profile) ->
        if err
          console.log('failed due to error:', err)
          fail()
        else
          User.findById profile.id, (err, user) ->
            if err
              console.log('failed due to find user error', err)
              fail()
            else
              res.json 200, {user: {id: user.id, email: user.email, lastModifiedDate: user.lastModifiedDate, name: user.name }}        

  exports.checkLoginFilter = (req, res, next) ->
    fail = -> res.json 401, {reason: 'not_logged_in'}
    token = req.headers.authorization
    if !token
      console.log('fail auth, no token')
      fail()
    else
      jwt.verify token, config.sessionSecret, (err, profile) ->
        if err
          console.log('failed due to error:', err)
          fail()
        else
          User.findById profile.id, (err, user) ->
            if err
              console.log('failed due to find user error', err)
              fail()
            else
              console.log('found user, setting: ', user)
              req.user = user
              next()

  exports.register = (req, res) ->
    if !req.body.email || !req.body.password  || !req.body.name
      res.json 400, { error: 'Missing any of the following: email, password, name' }

    User.findOne { 'email' :  req.body.email }, (err, user) ->
      if (err)
        res.json 500, { error: err }
        return   
      
      if (user) 
        res.json 400, { error: 'Email is already taken' }
        return
      
      newUser = new User()
      newUser.email    = req.body.email
      newUser.password = req.body.password
      newUser.name = req.body.name

      newUser.save (err) ->
        if (err)
          res.json 500, { error: err }
          return         
        else
          res.json 200, { success: true }

  exports.login = (req, res) ->
    res.json 200, {user: {id: req.user.id, email: req.user.email, lastModifiedDate: req.user.lastModifiedDate, name: req.user.name }}

  exports