require 'open_chain/email_validation_support'

module Api; module V1; class EmailsController < ApiController
  include OpenChain::EmailValidationSupport

  def validate_email_list
    is_valid = email_list_valid?(params[:email])
    render json: {valid: is_valid}
  end
end; end; end;