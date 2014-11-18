# All Tomorrow's Parties -- client
Meteor.subscribe "directory"
Meteor.subscribe "parties"

# If no party selected, select one.
Meteor.startup ->
  Meteor.autorun ->
    unless Session.get("selected")
      party = Parties.findOne()
      Session.set "selected", party._id  if party



#/////////////////////////////////////////////////////////////////////////////
# Party details sidebar
Template.details.party = ->
  Parties.findOne Session.get("selected")

Template.details.anyParties = ->
  Parties.find().count() > 0

Template.details.creatorName = ->
  owner = Meteor.users.findOne(@owner)
  return "me"  if owner._id is Meteor.userId()
  displayName owner

Template.details.canRemove = ->
  @owner is Meteor.userId() and attending(this) is 0

Template.details.maybeChosen = (what) ->
  myRsvp = _.find(@rsvps, (r) ->
    r.user is Meteor.userId()
  ) or {}
  (if what is myRsvp.rsvp then "chosen btn-inverse" else "")

Template.details.events
  "click .rsvp_yes": ->
    Meteor.call "rsvp", Session.get("selected"), "yes"
    false

  "click .rsvp_maybe": ->
    Meteor.call "rsvp", Session.get("selected"), "maybe"
    false

  "click .rsvp_no": ->
    Meteor.call "rsvp", Session.get("selected"), "no"
    false

  "click .invite": ->
    openInviteDialog()
    false

  "click .remove": ->
    Parties.remove @_id
    false


#/////////////////////////////////////////////////////////////////////////////
# Party attendance widget
Template.attendance.rsvpName = ->
  user = Meteor.users.findOne(@user)
  displayName user

Template.attendance.outstandingInvitations = ->
  party = Parties.findOne(@_id)
  Meteor.users.find $and: [
    _id: # they're invited
      $in: party.invited
  ,
    _id: # but haven't RSVP'd
      $nin: _.pluck(party.rsvps, "user")
  ]

Template.attendance.invitationName = ->
  displayName this

Template.attendance.rsvpIs = (what) ->
  @rsvp is what

Template.attendance.nobody = ->
  not @public and (@rsvps.length + @invited.length is 0)

Template.attendance.canInvite = ->
  not @public and @owner is Meteor.userId()


#/////////////////////////////////////////////////////////////////////////////
# Map display

# Use jquery to get the position clicked relative to the map element.
coordsRelativeToElement = (element, event) ->
  offset = $(element).offset()
  x = event.pageX - offset.left
  y = event.pageY - offset.top
  x: x
  y: y

Template.map.events
  "mousedown circle, mousedown text": (event, template) ->
    Session.set "selected", event.currentTarget.id

  "dblclick .map": (event, template) ->
    # must be logged in to create events
    return  unless Meteor.userId()
    coords = coordsRelativeToElement(event.currentTarget, event)
    openCreateDialog coords.x / 500, coords.y / 500

Template.map.rendered = ->
  self = this
  self.node = self.find("svg")
  unless self.handle
    self.handle = Meteor.autorun(->
      selected = Session.get("selected")
      selectedParty = selected and Parties.findOne(selected)
      radius = (party) ->
        10 + Math.sqrt(attending(party)) * 10


      # Draw a circle for each party
      updateCircles = (group) ->
        group.attr("id", (party) ->
          party._id
        ).attr("cx", (party) ->
          party.x * 500
        ).attr("cy", (party) ->
          party.y * 500
        ).attr("r", radius).attr("class", (party) ->
          (if party.public then "public" else "private")
        ).style "opacity", (party) ->
          (if selected is party._id then 1 else 0.6)


      circles = d3.select(self.node).select(".circles").selectAll("circle").data(Parties.find().fetch(), (party) ->
        party._id
      )
      updateCircles circles.enter().append("circle")
      updateCircles circles.transition().duration(250).ease("cubic-out")
      circles.exit().transition().duration(250).attr("r", 0).remove()

      # Label each with the current attendance count
      updateLabels = (group) ->
        group.attr("id", (party) ->
          party._id
        ).text((party) ->
          attending(party) or ""
        ).attr("x", (party) ->
          party.x * 500
        ).attr("y", (party) ->
          party.y * 500 + radius(party) / 2
        ).style "font-size", (party) ->
          radius(party) * 1.25 + "px"


      labels = d3.select(self.node).select(".labels").selectAll("text").data(Parties.find().fetch(), (party) ->
        party._id
      )
      updateLabels labels.enter().append("text")
      updateLabels labels.transition().duration(250).ease("cubic-out")
      labels.exit().remove()

      # Draw a dashed circle around the currently selected party, if any
      callout = d3.select(self.node).select("circle.callout").transition().duration(250).ease("cubic-out")
      if selectedParty
        callout.attr("cx", selectedParty.x * 500).attr("cy", selectedParty.y * 500).attr("r", radius(selectedParty) + 10).attr("class", "callout").attr "display", ""
      else
        callout.attr "display", "none"
    )

Template.map.destroyed = ->
  @handle and @handle.stop()


#/////////////////////////////////////////////////////////////////////////////
# Create Party dialog
openCreateDialog = (x, y) ->
  Session.set "createCoords",
    x: x
    y: y

  Session.set "createError", null
  Session.set "showCreateDialog", true

Template.page.showCreateDialog = ->
  Session.get "showCreateDialog"

Template.createDialog.events
  "click .save": (event, template) ->
    title = template.find(".title").value
    description = template.find(".description").value
    public_ = not template.find(".private").checked
    coords = Session.get("createCoords")
    if title.length and description.length
      Meteor.call "createParty",
        title: title
        description: description
        x: coords.x
        y: coords.y
        public: public_
      , (error, party) ->
        unless error
          Session.set "selected", party
          openInviteDialog()  if not public_ and Meteor.users.find().count() > 1

      Session.set "showCreateDialog", false
    else
      Session.set "createError", "It needs a title and a description, or why bother?"

  "click .cancel": ->
    Session.set "showCreateDialog", false

Template.createDialog.error = ->
  Session.get "createError"


#/////////////////////////////////////////////////////////////////////////////
# Invite dialog
openInviteDialog = ->
  Session.set "showInviteDialog", true

Template.page.showInviteDialog = ->
  Session.get "showInviteDialog"

Template.inviteDialog.events
  "click .invite": (event, template) ->
    Meteor.call "invite", Session.get("selected"), @_id

  "click .done": (event, template) ->
    Session.set "showInviteDialog", false
    false

Template.inviteDialog.uninvited = ->
  party = Parties.findOne(Session.get("selected"))
  return []  unless party # party hasn't loaded yet
  Meteor.users.find $nor: [
    _id:
      $in: party.invited
  ,
    _id: party.owner
  ]

Template.inviteDialog.displayName = ->
  displayName this
