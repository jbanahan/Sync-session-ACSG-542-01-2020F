class PublicShipmentsController < ApplicationController
    skip_before_filter :require_user
    skip_before_filter :set_user_time_zone
    skip_before_filter :log_request

  def index
    @no_buttons = true
    @result = []
    if params[:f] && params[:v]
      field_to_search = ModelField.find_by_uid params[:f]
      if field_to_search.blank? || !field_to_search.public_searchable?
        error_redirect "The specified field is not searchable."
      else
        ss = SearchSetup.new(:module_type=>field_to_search.core_module.class_name)
        ss.search_criterions.build(:model_field_uid=>field_to_search.uid,:operator=>"co",:value=>params[:v])
        @value = params[:v]
        @field = field_to_search.uid
        @result = ss.public_search.limit(6)
      end
    end
  end


end
