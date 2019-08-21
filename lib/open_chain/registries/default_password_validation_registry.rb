require 'open_chain/validations/password/password_complexity_validator'
require 'open_chain/validations/password/password_length_validator'
require 'open_chain/validations/password/previous_password_validator'
require 'open_chain/validations/password/username_not_password_validator'


# This is really just a way to put all the defaults together in a single spot...
# When this class is registered, the service locator will extract the child services
# and utilize them.
module OpenChain; module Registries; class DefaultPasswordValidationRegistry

  def self.child_services
    [
      OpenChain::Validations::Password::PasswordLengthValidator, OpenChain::Validations::Password::UsernameNotPasswordValidator, 
      OpenChain::Validations::Password::PasswordComplexityValidator, OpenChain::Validations::Password::PreviousPasswordValidator
    ]
  end

end; end; end;