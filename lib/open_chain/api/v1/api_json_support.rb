require 'open_chain/api/api_entity_jsonizer'
require 'open_chain/api/v1/api_model_field_support'

module OpenChain; module Api; module V1; module ApiJsonSupport
  extend ActiveSupport::Concern
  include OpenChain::Api::V1::ApiModelFieldSupport

  attr_reader :jsonizer

  def initialize jsonizer: OpenChain::Api::ApiEntityJsonizer.new
    @jsonizer = jsonizer
  end

  # Utilizes the internal jsonizer object to generate an object hash
  # containing the values for the given object for every model field uid listed in the
  # field_list argument.
  def to_entity_hash(obj, field_list, user: current_user)
    jsonizer.entity_to_hash(user, obj, field_list.map {|f| f.to_s})
  end

  # render field for json
  def export_field model_field_uid, obj, user: current_user
    jsonizer.export_field user, obj, ModelField.find_by_uid(model_field_uid)
  end

  def include_association? association_name, http_params: params
    http_params[:include] && http_params[:include].match(/#{association_name}/)
  end

  def render_attachments?
    include_association?("attachments")
  end

  # add attachments array to root of hash
  def render_attachments obj, hash
    hash['attachments'] = Attachment.attachments_as_json(obj)[:attachments]
  end

end; end; end; end;