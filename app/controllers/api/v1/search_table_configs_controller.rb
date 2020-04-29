module Api; module V1; class SearchTableConfigsController < Api::V1::ApiController
  def for_page
    h = {search_table_configs:[]}
    SearchTableConfig.for_user(current_user, params[:page_uid]).each do |stc|
      h[:search_table_configs] << {
        id:stc.id,
        name:stc.name,
        user_id:stc.user_id,
        company_id:stc.company_id,
        config:stc.config_hash
      }
    end
    render json: h
  end
end; end; end
