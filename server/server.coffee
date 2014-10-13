# server


Meteor.publish 'directory', ->
    return Meteor.users.find({}, {fields: {emails: 1, profile: 1}})


Meteor.publish 'parties', ->
    return Parties.find({$or: [{'public': true}, {invited: @userId}, {owner: @userId}]})



