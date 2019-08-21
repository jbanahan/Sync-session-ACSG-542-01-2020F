require 'open_chain/validations/password/password_length_validator'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberPasswordLengthValidator < OpenChain::Validations::Password::PasswordLengthValidator
  def self.required_password_length user
    8
  end
end; end; end; end