class VendorsController < ApplicationController
  def index
    action_secure(current_user.view_vendors?, nil, {:verb => "view", :lock_check => false, :module_name=>"vendors"}) {
      c = Company.where(vendor:true).order(:name)
      c = Company.search_secure(current_user,c)
      c = c.where('name like ?',"%#{params[:q]}%") if params[:q]
      @companies = c.paginate(:per_page=>20, page: params[:page])
      if !render_infinite_empty(@companies,'vendors')
        render_layout_or_partial 'index_rows', {companies:@companies}, false
      end
    }
  end

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
      @orders = Order.search_secure(current_user,c.vendor_orders.order('orders.order_date desc'))
      @orders = @orders.where('customer_order_number like ?',"%#{params[:q]}%") if params[:q]
      @orders = @orders.paginate(:per_page => 20, :page => params[:page])
      @orders
    end
  end

  def survey_responses
    render_infinite('surveys','survey_response_rows',:survey_responses) do |c|
      @survey_responses = SurveyResponse.search_secure(current_user,c.survey_responses)
      @survey_responses = @survey_responses.joins(:survey).where('surveys.name like ?',"%#{params[:q]}%") if params[:q]
      @survey_responses = @survey_responses.paginate(:per_page=>20, :page=>params[:page])
      @survey_responses
    end
  end

  def products
    render_infinite('products','product_rows',:products) do |c|
      @products = Product.search_secure(current_user,Product.where(vendor_id:c.id).order('unique_identifier'))
      @products = @products.where('unique_identifier like ?',"%#{params[:q]}%") if params[:q]
      @products = @products.paginate(:per_page=>20,:page => params[:page])
      @products
    end
  end

  private
  def render_infinite noun, partial, partial_local_name
    secure_company_view do |c|
      collection = yield(c)
      if !render_infinite_empty(collection,noun)
        render_layout_or_partial partial, {partial_local_name=>collection}, true
      end
    end
  end
  def render_layout_or_partial partial, partial_locals, is_embedded_pane
    if params[:page]
      render partial: partial, locals:partial_locals
    else
      render layout: !is_embedded_pane
    end
  end
  def render_infinite_empty collection, noun
    if collection.empty?
      if params[:page].blank?
        render text: "<div class='alert alert-success'>There aren't any #{noun}.</div>"
      else 
        render text: "<tr class='last-row'><td colspan='50'><div class='alert alert-info text-center' style='margin-top:10px'>There aren't any more #{noun}.</div></td></tr>"
      end
      return true
    else
      return false
    end
  end
  def secure_company_view param=:id
    @company = Company.find params[param]
    action_secure(@company.can_view_as_vendor?(current_user), @company, {:verb => "view", :lock_check => true, :module_name=>"vendor"}) {
      enable_workflow @company
      yield @company if block_given?
    }
  end
end