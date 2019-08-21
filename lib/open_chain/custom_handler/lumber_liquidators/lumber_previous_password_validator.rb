require 'open_chain/validations/password/previous_password_validator'

module OpenChain; module CustomHandler; module LumberLiquidators; class LumberPreviousPasswordValidator < OpenChain::Validations::Password::PreviousPasswordValidator

  def self.password_history_length
    5
  end

end; end; end; end