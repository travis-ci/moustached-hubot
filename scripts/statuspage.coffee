# Description:
#   Interaction with the StatusPage.io API to open and update incidents, change component status.
#
# Configuration:
#   HUBOT_STATUS_PAGE_ORGANIZATION
#   HUBOT_STATUS_PAGE_TOKEN
#
# Commands:
#   hubot status? - Display an overall status of all components
#   hubot status <component>? - Display the status of a single component
#   hubot status <component> (degraded performance|partial outage|major outage|operational) - Set the status for a component. You can also use degraded, partial or major as shortcuts.
#   hubot status incidents - Show all unresolved incidents
#   hubot status open (investigating|identified|monitoring|resolved) <name>: <message> - Create a new incident using the specified name and message, setting it to the desired status (investigating, etc.). The message can be omitted
#   hubot status update <status> <message> - Update the latest open incident with the specified status and message.
# 
# Author:
#   roidrage
module.exports = (robot) ->
  baseUrl = "https://api.statuspage.io/v0/organizations/#{process.env.HUBOT_STATUS_PAGE_ORGANIZATION}"
  authHeader = Authorization: "OAuth #{process.env.HUBOT_STATUS_PAGE_TOKEN}"
  componentStatuses =
    degraded: 'degraded performance',
    major: 'major outage',
    partial: 'partial outage'

  robot.respond /status incidents\??/i, (msg) ->
    msg.http("#{baseUrl}/incidents.json").headers(authHeader).get() (err, res, body) ->
      response = JSON.parse body
      if response.error
        msg.send "Error talking to StatusPage.io: #{response.error}"
      else
        unresolvedIncidents = response.filter (incident) ->
          incident.status != "resolved" and incident.status != "postmortem" and incident.status != "completed"
        if unresolvedIncidents.length == 0
          msg.send "All clear, no unresolved incidents!"
        else
          msg.send "Unresolved incidents:"
          for incident in unresolvedIncidents
            do (incident) ->
              msg.send "#{incident.name} (Status: #{incident.status}, Created: #{incident.created_at})"

  robot.respond /status update (investigating|identified|monitoring|resolved) (.+)/i, (msg) ->
    msg.http("#{baseUrl}/incidents.json").headers(authHeader).get() (err, res, body) ->
      response = JSON.parse body
      if response.error
        msg.send "Error talking to StatusPage.io: #{response.error}"
      else
        unresolvedIncidents = response.filter (incident) ->
          incident.status != "resolved" and incident.status != "postmortem" and incident.status != "completed"
        if unresolvedIncidents.length == 0
          msg.send "Sorry, there are no unresolved incidents."
        else
          incidentId = unresolvedIncidents[0].id
          incident =
            status: msg.match[1]
            message: msg.match[2]
            wants_twitter_update: 't'
          params =
            incident: incident
          msg.http("#{baseUrl}/incidents/#{incidentId}.json").headers(authHeader).patch(JSON.stringify params) (err, res, body) ->
            response = JSON.parse body
            if response.error
              msg.send "Error updating incident #{unresolvedIncidents[0].name}: #{response.error}"
            else
              msg.send "Updated incident \"#{unresolvedIncidents[0].name}\""

  robot.respond /status open (investigating|identified|monitoring|resolved) ([^:]+)(: ?(.+))?/i, (msg) ->
    if msg.match.length == 5
      name = msg.match[2]
      message = msg.match[4]
    else
      name = msg.match[2]

    incident =
      status: msg.match[1]
      wants_twitter_update: "t"
      message: message
      name: name
    params = {incident: incident}
    msg.http("#{baseUrl}/incidents.json")
      .headers(authHeader)
      .post(JSON.stringify params) (err, response, body) ->
        response = JSON.parse body
        if response.error
          msg.send "Error updating incident \"#{name}\": #{response.error}"
        else
          msg.send "Created incident \"#{name}\""
    
  robot.respond /status\?$/i, (msg) ->
    msg.http("#{baseUrl}/components.json")
     .headers(authHeader)
     .get() (err, res, body) ->
       response = JSON.parse body
       components = response.filter (component) ->
         component.status != 'operational'
       if components.length == 0
         msg.send "All systems operational!"
       else
         msg.send "Systems currently in a degraded state: #{("#{component.name} (#{component.status.replace(/_/g, " ")})" for component in components).join(", ")}"

  robot.respond /status ((?!(incidents|open|update|resolve|create))(\w ?)+)\?$/i, (msg) ->
    msg.http("#{baseUrl}/components.json")
     .headers(authHeader)
     .get() (err, res, body) ->
       response = JSON.parse body
       components = response.filter (component) ->
         component.name == msg.match[1]
       if components.length == 0
         msg.send "Sorry, the component \"#{msg.match[1]}\" doesn't exist. I know of these components: #{(component.name for component in response).join(",  ")}."
       else
         msg.send "Status of #{msg.match[1]}: #{components[0].status.replace(/_/g, " ")}"
       
  robot.respond /status ((\w ?)+) (major( outage)?|degraded( performance)?|partial( outage)?|operational)/i, (msg) ->
    componentName = msg.match[1]
    status = msg.match[3]
    status = componentStatuses[status] || status
    msg.http("#{baseUrl}/components.json")
     .headers(authHeader)
     .get() (err, res, body) ->
       response = JSON.parse body
       if response.error
         msg.send "Error talking to StatusPage.io: #{response.error}"
       else
         components = response.filter (component) ->
           component.name == componentName
         if components.length == 0
           msg.send "Couldn't find a component named #{componentName}"
         else
           component = components[0]
           requestStatus = status.replace /[ ]/g, "_"
           params = {component: {status: requestStatus}}
           msg.http("#{baseUrl}/components/#{component.id}.json")
             .headers(authHeader)
             .patch(JSON.stringify params) (err, res, body) ->
               response = JSON.parse body
               if response.error
                 msg.send "Error setting the status for #{component}: #{response.error}"
               else
                 msg.send "Status for #{componentName} is now #{status} (was: #{component.status})"
