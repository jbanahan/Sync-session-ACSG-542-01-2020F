class SalesOrdersController < ApplicationController
  def root_class
	  SalesOrder
	end
  # GET /sales_orders
  # GET /sales_orders.xml
  SEARCH_PARAMS = {
        'o_num' => {:field => 'order_number', :label=> 'Sales Order Number'},
        'p_name' => {:field => 'sales_order_lines_product_name', :label => 'Product Name'},
        'c_name' => {:field => 'customer_name', :label => 'Customer Name'},
        'o_date' => {:field => 'order_date', :label => 'Order Date'},
        'p_id'   => {:field => 'sales_order_lines_product_unique_identifier',:label => 'Product ID'}
    }
  def index
    s = build_search(SEARCH_PARAMS,'o_num','o_date','d')
    respond_to do |format|
      format.html {
          @sales_orders = s.paginate(:per_page => 20, :page => params[:page])
          render :layout => 'one_col'
      }
    end
  end

  # GET /sales_orders/1
  # GET /sales_orders/1.xml
  def show
    o = SalesOrder.find(params[:id])
    action_secure(o.can_view?(current_user),o,{:lock_check => false, :verb => "view", :module_name=>"order"}) {
      @sales_order = o
      respond_to do |format|
        format.html # show.html.erb
        format.xml  { render :xml => @sales_order }
      end
    }
  end

  # GET /sales_orders/new
  # GET /sales_orders/new.xml
  def new
    o = SalesOrder.new
    action_secure(o.can_view?(current_user),o,{:lock_check => false, :verb => "view", :module_name=>"order"}) {
      @sales_order = o
      respond_to do |format|
        format.html # new.html.erb
        format.xml  { render :xml => @sales_order }
      end
    }
  end

  # GET /sales_orders/1/edit
  def edit
    o = SalesOrder.find(params[:id])
    action_secure(o.can_edit?(current_user),o,{:verb => "edit", :module_name=>"order"}) {
      @sales_order = o
    }
  end

  # POST /sales_orders
  # POST /sales_orders.xml
  def create
    o = SalesOrder.new(params[:sales_order])
    action_secure(o.can_edit?(current_user),o,{:verb => "create", :module_name=>"order"}) {
      @sales_order = o
      respond_to do |format|
        if @sales_order.save
					if update_custom_fields @sales_order
						add_flash :notices, "Sale successfully saved."
					end
          format.html { redirect_to(@sales_order) }
          format.xml  { render :xml => @sales_order, :status => :created, :location => @sales_order }
        else
          errors_to_flash @sales_order
          format.html { render :action => "new" }
          format.xml  { render :xml => @sales_order.errors, :status => :unprocessable_entity }
        end
      end
    }
  end

  # PUT /sales_orders/1
  # PUT /sales_orders/1.xml
  def update
    
    o = SalesOrder.find(params[:id])
    action_secure(o.can_edit?(current_user),o,{:verb => "edit", :module_name=>"order"}) {
      @sales_order = o
      respond_to do |format|
        if @sales_order.update_attributes(params[:sales_order])
          add_flash :notices, "Sale successfully updated."
          format.html { redirect_to(@sales_order) }
          format.xml  { head :ok }
        else
          errors_to_flash @sales_order
          format.html { render :action => "edit" }
          format.xml  { render :xml => @sales_order.errors, :status => :unprocessable_entity }
        end
      end
    }
  end

  # DELETE /sales_orders/1
  # DELETE /sales_orders/1.xml
  def destroy
    o = SalesOrder.find(params[:id])
    action_secure(current_user.company.master,o,{:verb => "delete", :module_name=>"order"}) {
      @sales_order = o
      @sales_order.destroy
      errors_to_flash @sales_order
      respond_to do |format|
        format.html { redirect_to(sales_orders_url) }
        format.xml  { head :ok }
      end
    }
  end
  
  private    
    def secure
        r = SalesOrder.where("1=0")
        if current_user.company.master
          r = SalesOrder
        elsif current_user.company.customer?
            r = current_user.company.customer_sales_orders
        else
            add_flash :errors, "You do not have permission to search for sales."
            return SalesOrder.where("1=0")
        end
        r.select("DISTINCT 'sales_orders'.*").includes(:customer)
    end
end
