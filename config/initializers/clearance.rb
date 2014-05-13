# This password strategy mimics what Authlogic used, we need to use the same password strategy
# otherwise we'll force every user to have to change their password after this goes in.
# If we really want to use one of the built in Clearance strategies at some point then we'll
# need to create a migration in here to move validated passwords into the new format after we've
# verified the cleartext password we receive is valid.
require 'digest/sha2'

module Sha512PasswordStrategy

  def authenticated?(password)
    encrypted_password == encrypt(password)
  end

  def password=(cleartext_password)
    @password = cleartext_password
    initialize_salt_if_necessary

    if cleartext_password.present?
      self.encrypted_password = encrypt(cleartext_password)
    end
  end

  private

    def encrypt(string)
      generate_hash "#{string}#{password_salt}"
    end

    def generate_hash(digest)
      20.times { digest = Digest::SHA512.hexdigest(digest) }
      digest
    end

    def initialize_salt_if_necessary
      if password_salt.blank?
        self.password_salt = SecureRandom.hex(64)
      end
    end
end

class LoginAllowedGuard < Clearance::SignInGuard
  def call
    if signed_in? && User.access_allowed?(current_user)
      next_guard
    else
      failure("")
    end
  end
end

Clearance.configure do |config|
  config.mailer_sender = OpenMailer.default_params[:from]
  config.password_strategy = Sha512PasswordStrategy
  config.sign_in_guards = [LoginAllowedGuard]
  config.cookie_expiration = lambda {|cookies|
    # Basically, since the clearance devs are a tad bit opinionated and they
    # don't really want to implement a remember function when logging
    # in, we have use this hack with a secondary remember me cookie
    # that's set if the user logs in w/ the "Remember Me" checked.
    # See UserSessionsController

    # Keep in mind that this is called with every single request as well
    cookies[:remember_me] ? 20.years.from_now : nil
  } 
end
