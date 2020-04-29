# Be sure to restart your server when you modify this file.

# This can be changed to json once we've had the rails version upgrade deployed for some time..they hybrid just means that
# it handles Marshal'ed cookes if they come in, but any new cookies are written in json.  After some time, the marshal'ed cookies
# will be gone and we can just use json.
Rails.application.config.action_dispatch.cookies_serializer = :hybrid