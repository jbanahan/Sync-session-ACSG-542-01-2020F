require 'open_chain/api/api_entity_jsonizer'

module Api; module V1; class EntityApiController < ApiController
  attr_reader :jsonizer

  def initialize jsonizer = OpenChain::Api::ApiEntityJsonizer.new
    @jsonizer = jsonizer
  end

  def show_module mod
    render_obj mod.find params[:id]
  end

  def render_obj obj
    raise ActiveRecord::RecordNotFound unless obj

    if obj.can_view? User.current
      render json: jsonizer.entity_to_json(User.current, obj, parse_model_field_param_list)
    else
      render_error "Not Found.", :not_found
    end
  end

  def render_model_field_list core_module
    if core_module.view? User.current
      render json: jsonizer.model_field_list_to_json(User.current, core_module)
    else
      render_error "Not Found.", :not_found
    end
  end

  private
    def parse_model_field_param_list
      uids = params[:mf_uids]

      # Depending on how params are sent, the uids could be an array or a string
      # query string like "mf_uid[]=uid&mf_uid[]=uid2" will result in an array (rails takes care of this for us
      # so do most other web application frameworks and lots of tools autogenerate parameters like this so we'll support it)
      # query string like "mf_uid=uid,uid2,uid2" results in a string
      unless uids.is_a?(Enumerable) || uids.blank?
        uids = uids.split(/[,~]/).collect {|v| v.strip}
      end

      uids = [] if uids.blank?

      uids 
    end
end; end; end