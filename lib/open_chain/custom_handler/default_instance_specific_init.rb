require 'open_chain/validations/password/password_complexity_validator'
require 'open_chain/validations/password/password_length_validator'
require 'open_chain/validations/password/previous_password_validator'
require 'open_chain/validations/password/username_not_password_validator'
require 'open_chain/password_validation_registry'

module OpenChain; module CustomHandler; class DefaultInstanceSpecificInit
  def self.init
    if PasswordValidationRegistry.registered_for_valid_password.blank?
      [OpenChain::Validations::Password::PasswordLengthValidator, OpenChain::Validations::Password::UsernameNotPasswordValidator, OpenChain::Validations::Password::PasswordComplexityValidator].each do |klass|
        OpenChain::PasswordValidationRegistry.register klass
      end
    end
  end
end; end; end
