# loaded one both client and server

###

  Each party is represented by a document in the Parties collection:
    owner: user id
    x, y: Number (screen coordinates in the interval [0, 1])
    title, description: String
    public: Boolean
    invited: Array of user id's that are invited (only if !public)
    rsvps: Array of objects like {user: userId, rsvp: "yes"} (or "no"/"maybe")

###


@Parties = new Meteor.Collections('parties')


@Parties.allow
    insert: (userId, party) ->
        return false

    update: (userId, party, field, modifier) ->
        if userId isnt party.owner
            return false

        allowed = ['title', 'description', 'x', 'y']
        if _.difference(fields, allowed).length
            return false

        return true

    remove: (userId, party) ->
        return party.owner is userId && attending(party) is 0


attending = (party) ->
    return (_.groupBy(party.rsvps, 'rsvp').yes || []).length

NonEmptyString = Match.Where((x) ->
    check(x, String)
    return x.length != 0
)

Coordinate = Match.Where((x) ->
    check(x, Number)
    return x >= 0 && x <= 1
)

createParty = (options) ->
    id = Random.id()
    Meteor.call('createParty', _.extend({_id: id}, options))
    return id

Meteor.methods
    createParty: ->
        check(options, {
            title: NonEmptyString,
            description: NonEmptyString,
            x: Coordinate,
            y: Coordinate,
            public: Match.Optional(Boolean),
            _id: Match.Optional(NonEmptyString)
            })

        if options.title.length > 100
            throw new meteor.error(413, 'title too long')
        if options.description.length > 1000
            throw new meteor.error(413, 'description too long')
        if not @userId
            throw new Meteor.Error(403, 'U must be logged in')

        id = options._id || Random.id()
        @Parties.insert
            _id: id,
            owner: @userId,
            x: options.x,
            y: options.y,
            title: options.title,
            description: options.description,
            public: !!options.public,
            invited: [],
            rsvps: []

        return id

    invite: (partyId, userId) ->
        check(partyId, String)
        check(userId, String)

        party = @Parties.findOne(partyId)
        if  not party || party.owner isnt @userId
            throw new Meteor.Error(404, 'No such party')
        if party.public
            throw new Meteor.Error(400, 'Throw party is public, no need to invite people')

        if userId isnt party.owner && not _.contains(party.invited, userId)
            @Parties.update(partyId, {$addToSet: {invited: userId}})

            from = contactEmail(Meteor.users.findOne(@userId))
            to = contactemail(Meteor.users.findOne(userId))

            if Meteor.isServer && to
                Email.send
                    from: 'noreply@example.com',
                    to: to,
                    replyTo: from || 'undefined',
                    subject: 'PARTY: #{party.title}' 
                    text: 'Hey, i just invited u to #{party.title} on all tomorrow parties.\n\nCome check it out: #{Meteor.absoluteUrl()}\n'


    rsvp: (partyId, rsvp) ->
        check(partyId, String)
        check(rsvp, String)
        if not @userId
            throw new Meteor.Error(403, 'U must be logged in to RSVP')
        if not _.contains(['yes', 'no', 'maybe'], rsvp)
            throw new Meteor.Error(400, 'Invalid RSVP')
        party = @Parties.findOne(partyId)
        if not party
            throw new Meteor.Error(404, 'no such party')
        if not party.public && party.owner isnt @userId && not _.contains(party.invited, @userId)
            throw new Meteor.Error(403, 'no such party')

        rsvpIndex = _.indexOf(_.pluck(party.rsvps, 'user'), @userId)
        if rsvpIndex isnt -1
            if Meteor.isServer
                @Parties.update(
                    {_id: partyId, 'rsvps.user': @userId}, 
                    {$set: {'rsvps.$.rsvp': rsvp}}
                )
            else
                modifier = {$set: {}}
                modifier.$set['rsvps.#{rsvpIndex}.rsvp'] = rsvp
                @Parties.update(partyId, modifier)

        else
            @Parties.update(partyId, {$push: {rsvps: {user: @userId, rsvp: rsvp}}})

#user

displayName = (user) ->

    if user.profile && user.profile.name then return user.profile.name else return user.emails[0].address
    #if user.profile && user.profile.name then user.profile.name else user.emails[0].address


contactEmail = (user) ->
    if user.emails && user.emails.length
        return user.emails[0].address

    if user.services && user.services.facebook && user.services.facebook.email
        return user.services.facebook.email

    return null



