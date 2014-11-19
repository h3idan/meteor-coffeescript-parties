# all tomorrow's parties -- client


Meteor.subscribe("directory")
Meteor.subscribe("parties")


# if no party selected, or if the selected party was deleted, select one
Meteor.startup ->
    Dps.autorun ->
        selected = Session.get('selected')
        if not selected or Parties.findOne(selected)
            party = Parties.findOne()
            if party
                Session.set('selected', party._id)
            else
                Session.set('selected', null)


# party 内容工具条

Template.details.party = ->
    Parties.findOne(Session.get("selected"))

Template.details.anyParties = ->
    Parties.find().count() > 0

Template.details.creatorName = ->
    owner = Meteor.users.findOne(@owner)
    if owner._id = Meteor.userId()
        return 'me'
    displayName(owner)

Template.details.canRemove = ->
    @owner is Meteor.userId() and attending(this) is 0

Template.details.maybeChosen = (what) ->
    myRsvp = _.find(@rsvps, (r) -> r.user is Meteor.userId()) or {}
    #what is if myRsvp.rsvp then 'chosen btn-inverse' else ''
    (if what is myRsvp.rsvp then "chosen btn-inverse" else "")

Template.details.events
    'click .rsvp_yes': ->
        Meteor.call('rsvp', Session.get('selected'), 'yes')
        false

    'click .rsvp_maybe': ->
        Meteor.call('rsvp', Session.get('selected'), 'maybe')
        false

    'click .rsvp_no': ->
        Meteor.call('rsvp', Session.get('selected'), 'no')
        false

    'click .invite': ->
        openInviteDialog()
        false

    'click .remove': ->
        Parties.remove(@_id)
        false


# party attendance widget

Template.attendance.rsvpName = ->
    user = Meteor.users.findOne(@user)
    displayName(user)

Template.attendance.outstandingInvitations = ->
    party = Parties.findOne(@_id)
    Meteor.users.find({$and: [
        {_id: {$in: party.invited}},
        {_id: {$nin: _.pluck(party.rsvps, 'user')}}
    ]})

Template.attendance.invitationName = ->
    displayName(this)

Template.attendance.rsvpIs = (what) ->
    @rsvp is what

Template.attendance.nobody = ->
    not @public and @rsvps.length + @invited.length is 0

Template.attendance.canInvite = ->
    not @public and @owner is Meteor.userId()


# map display
# use jquery to get postion clicked relative to the map element

coordsRelativeToElement = (element, event) ->
    offset = $(element).offset()
    x = event.pageX - offset.left
    y = event.pageY - offset.top
    {x: x, y: y}

Template.map.events
    'mousedown circle, mousedown text': (event, template) ->
        Session.set('selected', event.currentTarget.id)

    'dblclick .map': (event, template) ->
        if not Meteor.userId()
            return
        coords = coordsRelativeToElement(event.currentTarget, event)
        openCreateDialog(coords.x / 500, coords.y / 500)

Template.map.rendered = ->
    self = this
    self.node = self.find('svg')

    if not self.handle
        self.handle = Deps.autorun(->
            selected = Session.get('selected')
            selectedParty = selected and Parties.findOne(selected)
            radius = (party) ->
                10 + Math.sqrt(attending(party)) * 10

            # draw a circle for each party
            updateCircles = (group) ->
                group.attr('id', (party) -> party._id)
                    .attr('cx', (party) -> party.x * 500)
                    .attr('cy', (party) -> party.y * 500)
                    .attr('r', radius)
                    .attr('class', (party) -> if party.public then 'public' else 'private')
                    .style('opacity', (party) -> if selected is party._id then 1 else 0.6)

            circles = d3.select(self.node).select('.circles').selectAll('circle')
                .data(Parties.find().fetch(), (party) -> party._id)

            updateCircles(circles.enter().append('circle'))
            updateCircles(circles.transition().duration().ease('cubic-out'))
            circles.exit().transition().duration(250).attr('r', 0).remove()

            # Label each with the current attendance count
            updateLabels = (group) ->
                group.attr('id', (party) -> party._id)
                    .text((party) -> attending(party) || '')
                    .attr('x', (party) -> party.x * 500)
                    .attr('y', (party) -> party.y * 500 + radius(party)/2)
                    .style('font-site', (party) -> radius(party) * 1.25 + 'px')

            labels = d3.select(self.node).select('.labels').selectAll('text')
                .data(Parties.find().fetch(), (party) -> party._id)

            updateLabels(labels.enter().append("text"))
            updateLabels(labels.transition().duration(250).ease("cubic-out"))
            labels.exit().remove()

            # Draw a dashed circle around the currently selected party, if any
            callout = d3.select(self.node).select('circle.callout')
                .transition().duration(250).ease('cubic-out')
            if selectedParty
                callout.attr('cx', selectedParty.x * 500)
                    .attr('cy', selectedParty.y * 500)
                    .attr('r', radius(selectedParty) + 10)
                    .attr('class', 'callout')
                    .attr('display', '')
            else
                callout.attr('display', 'none')
        )


Template.map.destroyed = ->
    @handle and @handle.stop()


# create Party dialog

openCreateDialog = (x, y) ->
    Session.set('createCoords', {x: x, y: y})
    Session.set('createError', null)
    Session.set('showCreateDialog', true)

Template.page.showCreateDialog = ->
    Session.get('showCreateDialog')

Template.createDialog.events
    'click .save': (event, template) ->
        title = template.find('.title').value
        description = template.find('.description').value
        public_var = not template.find('.private').checked
        coords = Session.get('createCoords')

        if title.length and description.length
            id = createParty(
                title: title,
                description: description,
                x: coords.x,
                y: coords.y,
                public: public_var,
            )

            Session.set('selected', id)
            openInviteDialog() if not public_var and Meteor.users.find().count() > 1
            Session.set('showCreateDialog', false)
        else
            Session.set('createError', 'it needs a title and a description, or why bother?')

    'click .cancel': ->
        Session.set('showCreateDialog', false)

Template.createDialog.error = ->
    Session.get('createError')



# invite dialog

openInviteDialog = ->
    Session.get('showInviteDialog', true)

Template.page.showInviteDialog = ->
    Session.get('showInviteDialog')

Template.inviteDialog.events
    'click .invite': (event, template) ->
        Meteor.call('invite', Session.get('selected'), @_id)

    'click .done': (event, template) ->
        Session.set('showInviteDialog', false)
        false

Template.inviteDialog.uninvited = ->
    party = Parties.findOne(Session.get('selected'))
    if not party
        return []
    Meteor.users.find({$nor: [
        {_id: {$in: party.invited}},
        {_id: party.owner}
    ]})

Template.inviteDialog.displayName = ->
    displayname(this)
