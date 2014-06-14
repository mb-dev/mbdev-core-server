googleapis = require('googleapis')
OAuth2Client = googleapis.OAuth2Client
mongoose = require('mongoose')
async = require('async')

User = mongoose.model('User')

getParams = (syncToken, pageToken) ->
  params = { calendarId: 'primary' }
  if syncToken 
    params.syncToken = syncToken
  else
    params.timeMin = '2014-01-01T00:00:00Z'
  params.pageToken = pageToken if pageToken
  params

getEvents = (oauth2Client, syncToken, callback) ->
  totalEvents = []
  params = getParams(syncToken)
  
  googleapis.discover('calendar', 'v3').execute (err, client) ->
    if err
      callback(err, [])
    else
      # get all events async
      async.doWhilst((asyncCallback) ->
        console.log 'Fetching events. Total: ', totalEvents.length, params
        client.calendar.events.list(params).withAuthClient(oauth2Client).execute (err, result) ->
          if err
            console.log('Error fetching events with params', err, params)
            asyncCallback(err) 
          else
            totalEvents = totalEvents.concat(result.items)
            params = getParams(syncToken, result.nextPageToken)
            asyncCallback()
      , ->
        params.pageToken
      , (err) ->
        callback(err, totalEvents)
      )

getCallbackUrl = (req) ->
  req.protocol + '://' + req.get('host') + '/auth/google/callback'  

module.exports = (config) ->
  exports.getEvents = (req, res) ->
    syncToken = req.query.syncToken

    oauth2Client = new OAuth2Client(config.google.clientID, config.google.clientSecret, getCallbackUrl(req))
    oauth2Client.credentials = {
      access_token: req.user.authToken,
      refresh_token: req.user.refreshToken
    };
  
    getEvents oauth2Client, syncToken, (err, events) ->
      if err
        res.json 400, err
      else
        res.json 200, events

  exports