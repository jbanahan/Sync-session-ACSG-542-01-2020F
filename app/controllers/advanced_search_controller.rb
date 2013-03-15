class AdvancedSearchController < ApplicationController
  def result
    search_setup = SearchSetup.find params[:id]
    search_query = SearchQuery.new search_setup, current_user
    has_bulk_actions = !search_setup.core_module.bulk_actions(current_user).empty?
    render :partial=>'rows', :locals=>{:search_query=>search_query,:has_bulk_actions=>has_bulk_actions}
  end

  def count
    search_setup = SearchSetup.find params[:id]
    search_query = SearchQuery.new search_setup, current_user
    render :text => search_query.count
  end
end
