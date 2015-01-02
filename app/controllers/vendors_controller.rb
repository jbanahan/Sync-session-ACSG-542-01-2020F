class VendorsController < ApplicationController
  def show
    secure_company_view
  end

  def locations
    secure_company_view do |c|
      render layout: false
    end
  end

  def orders
    render_infinite('orders','order_rows',:orders) do |c|
      @orders = Order.search_secure(current_user,c.vendor_orders.order('orders.order_date desc')).paginate(:per_page => 20, :page => params[:page])
      @orders
    end
  end

  def survey_responses
    render_infinite('surveys','survey_response_rows',:survey_responses) do |c|
      @survey_responses = SurveyResponse.search_secure(current_user,c.survey_responses).paginate(:per_page=>20, :page=>params[:page])
      @survey_responses
    end
  end

  private
  def render_infinite noun, partial, partial_local_name
    secure_company_view do |c|
      collection = yield(c)
      if !render_infinite_empty(collection,noun)
        render_layout_or_partial partial, {partial_local_name:collection}
      end
    end
  end
  def render_layout_or_partial partial, partial_locals
    if params[:page] && !(params[:page].to_s=='1')
      render partial: partial, locals:partial_locals
    else
      render layout: false
    end
  end
  def render_infinite_empty collection, noun
    if collection.empty?
      if params[:page].blank? || params[:page].to_s=='1'
        render text: "<div class='alert alert-success'>There aren't any #{noun} for this vendor.</div>"
      else 
        render text: "<tr class='last-row'><td colspan='50'><div class='alert alert-info text-center' style='margin-top:10px'>There aren't any more #{noun} for this vendor.</div></td></tr>"
      end
      return true
    else
      return false
    end
  end
  def secure_company_view param=:id
    @company = Company.find params[param]
    action_secure(@company.can_view?(current_user), @company, {:verb => "view", :lock_check => true, :module_name=>"vendor"}) {
      enable_workflow @company
      yield @company if block_given?
    }
  end
end