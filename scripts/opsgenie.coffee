# Description:
#    Interaction with the OpsGenie API to list and acknowledge alerts, and to manipulate the on-call schedule.
#
# Configuration:
#   OPSGENIE_CUSTOMER_KEY
#
# Commands:
#   hubot genie status - Lists open alerts
#   hubot genie me as email@example.com - Store custom email address to interact with OpsGenie. Defaults to the Campfire email address
#   hubot genie ack - Acknowledge all unacknowledged, open alerts
#   hubot genie close - Close all open alerts
#   hubot genie ack id - Acknoledge a specific alert. The ids are listed in the status output.
#   hubot genie close id - Close a specific alert.
#
# Author:
#   roidrage
module.exports = (robot) ->
  baseUrl = "https://api.opsgenie.com/v1/json/"
  customerKey = process.env.HUBOT_OPSGENIE_CUSTOMER_KEY

  robot.respond /genie me as (.+)$/i, (msg) ->
    email = msg.match[1]
    msg.message.user.opsGenieEmail = email
    msg.send "I'll remember your OpsGenie email as #{email}"

  robot.respond /genie status\??$/i, (msg) ->
    createdSince = new Date()
    createdSince.setTime(createdSince.getTime() - 48 * 60 * 60 * 1000)
    createdSince = parseInt(createdSince.getTime() * 1000 * 1000)
    msg.http("#{baseUrl}/alert").
        query({customerKey: customerKey, status: 'open', createdAfter: createdSince}).
        get() (err, res, body) ->
      response = JSON.parse body
      alerts = response.alerts
      if alerts.length == 0
        msg.send "No open alerts, go back to sleep"
      else
        unacked = (alert for alert in alerts when not alert.acknowledged)
        acked = (alert for alert in alerts when alert.acknowledged)
        msg.send "Found #{acked.length} acked and #{unacked.length} unacked alerts"
        for alert in alerts
          msg.http("#{baseUrl}/alert").
              query({customerKey: customerKey, id: alert.id}).
              get() (err, res, body) ->
            alert = JSON.parse body
            msg.send "#{alert.tinyId}:  #{alert.message} (source: #{alert.source}, #{if alert.acknowledged then "acked by #{alert.owner}" else "unacked"})"

  robot.respond /genie ack$/i, (msg) ->
    msg.http("#{baseUrl}/alert").
        query({customerKey: customerKey, status: 'open'}).
        get() (err, res, body) ->
      response = JSON.parse body
      if response.alerts.length == 0
        msg.send "No unacknowledged open alerts"
      else
        acked = 0
        for alert in response.alerts
          if not alert.acknowledged
            acked += 1
            body = JSON.stringify {
              customerKey: customerKey,
              alertId: alert.id,
              user: opsGenieUser(msg)
            }
            msg.http("#{baseUrl}/alert/acknowledge").post(body) (err, res, body) ->
              msg.send "Acknowledged: #{alert.message}"

        msg.send "Acknowledged #{acked} unacked alerts"

  robot.respond /genie ack ([0-9]+)$/i, (msg) ->
    tinyId = msg.match[1]
    msg.http("#{baseUrl}/alert").
        query({customerKey: customerKey, tinyId: tinyId}).
        get() (err, res, body) ->
      alert = JSON.parse body
      if alert.error
        msg.send "I had problems finding an alert with the id #{tinyId}"
      else
        body = JSON.stringify {
          customerKey: customerKey,
          alertId: alert.id,
          user: opsGenieUser(msg)
        }
        msg.http("#{baseUrl}/alert/acknowledge").post(body) (err, res, body) ->
          msg.send "Acknowledged: #{alert.message}"

  robot.respond /genie close ([0-9]+)$/i, (msg) ->
    tinyId = msg.match[1]
    msg.http("#{baseUrl}/alert").
        query({customerKey: customerKey, tinyId: tinyId}).
        get() (err, res, body) ->
      alert = JSON.parse body
      if alert.error
        msg.send "I had problems finding an alert with the id #{tinyId}"
      else
        body = JSON.stringify {
          customerKey: customerKey,
          alertId: alert.id,
          user: opsGenieUser(msg)
        }
        msg.http("#{baseUrl}/alert/close").post(body) (err, res, body) ->
          msg.send "Closed: #{alert.message}"

  robot.respond /genie close$/i, (msg) ->
    msg.http("#{baseUrl}/alert").
        query({customerKey: customerKey, status: 'open'}).
        get() (err, res, body) ->
      response = JSON.parse body
      alerts = response.alerts
      if alerts.length == 0
        msg.send "No open alerts"
      else
        acked = 0
        for alert in alerts
            body = JSON.stringify {
              customerKey: customerKey,
              alertId: alert.id,
              user: opsGenieUser(msg)
            }
            msg.http("#{baseUrl}/alert/close").post(body) (err, res, body) ->
              msg.send "Closed: #{alert.message}"

        msg.send "Closed #{alerts.length} open alerts"

  opsGenieUser = (msg) ->
    msg.message.user.opsGenieEmail || msg.message.user.email_address
