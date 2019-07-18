require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'

module OpenChain; module CustomHandler; module AnnInc; module AnnFtzValidationHelper
  extend ActiveSupport::Concern

  included do
    include OpenChain::CustomHandler::AnnInc::AnnCustomDefinitionSupport
  end

  CLASSIFICATION_TYPES = ["Multi", "Decision"]

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions [:classification_type, :percent_of_value, :key_description, :manual_flag]
  end
  
end; end; end; end
