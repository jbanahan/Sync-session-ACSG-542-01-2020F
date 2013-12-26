require 'open_chain/activity_summary'
class ActivitySummariesController < ApplicationController
  def entry
    @imp = Company.find_by_alliance_customer_number(params[:cust])
    unless Entry.can_view_importer?(@imp,current_user)
      render text: 'You do not have permission to view this page.', status: 401 
    end
    @last_entry = Entry.where(Entry.search_where_by_company_id(@imp.id)).order('updated_at DESC').first
    render text: 'This importer does not have any entries.' unless @last_entry
  end
end
