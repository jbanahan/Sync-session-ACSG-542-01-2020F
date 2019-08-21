require 'open_chain/custom_handler/lumber_liquidators/lumber_password_length_validator'
require 'open_chain/custom_handler/lumber_liquidators/lumber_previous_password_validator'
require 'open_chain/validations/password/password_complexity_validator'
require 'open_chain/validations/password/username_not_password_validator'

# This is really just a way to put all the defaults together in a single spot...
# When this class is registered, the service locator will extract the child services
# and utilize them.
module OpenChain; module CustomHandler; module LumberLiquidators; class LumberPasswordValidationRegistry

  def self.child_services
    [ 
      OpenChain::CustomHandler::LumberLiquidators::LumberPasswordLengthValidator, OpenChain::Validations::Password::UsernameNotPasswordValidator,
      OpenChain::Validations::Password::PasswordComplexityValidator, OpenChain::CustomHandler::LumberLiquidators::LumberPreviousPasswordValidator
    ]
  end

end; end; end; end