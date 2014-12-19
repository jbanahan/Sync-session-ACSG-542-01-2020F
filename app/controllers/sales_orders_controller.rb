class SalesOrdersController < ApplicationController
  def root_class
	  SalesOrder
	end
  
  def index
    flash.keep
    redirect_to advanced_search CoreModule::SALE, params[:force_search]
  end
  def all_open
    if current_user.view_sales_orders?
      respond_to do |format|
        format.json { render :json => SalesOrder.search_secure(current_user,SalesOrder).to_json(:only =>[:id,:order_number]) }
      end
    else
      error_redirect "You do not have permission to view sales."
    end
  end

  # GET /sales_orders/1
  # GET /sales_orders/1.xml
  def show
    o = SalesOrder.find(params[:id])
    action_secure(o.can_view?(current_user),o,{:lock_check => false, :verb => "view", :module_name=>"order"}) {
      @sales_order = o
      # This is obviously not going to work
      # for real usage, but we're not really using it
      # in real cases yet anyway, so I'm limiting to 1000
      # so we don't turn on and accidently load 300K products
      # into a select box (also in sales_order_lines_controller)
      @products = Product.limit(1000).all
      respond_to do |format|
        format.html # show.html.erb
        format.json { render :json => @sales_order.to_json(:only=>[:id,:order_number], :include=>{
          :sales_order_lines => {:only=>[:line_number,:quantity,:id], :include=>{:product=>{:only=>[:id,:name]}}}
        })}
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
    o = SalesOrder.new
    o.update_model_field_attributes params[:sales_order], no_validation: true

    action_secure(o.can_edit?(current_user),o,{:verb => "create", :module_name=>"order"}) {
      success = lambda {|so|
        add_flash :notices, "Sale created successfully."
        redirect_to so
      }
      failure = lambda {|so, errors|
        errors_to_flash so, :now=>true

        @sales_order = SalesOrder.new #transaction failure requires new object
        @sales_order.update_model_field_attributes params[:sales_order], no_validation: true
        render :action=>"new"
      }
      validate_and_save_module(o,params[:sales_order],success,failure)
    }
  end

  # PUT /sales_orders/1
  # PUT /sales_orders/1.xml
  def update
    o = SalesOrder.find(params[:id])
    action_secure(o.can_edit?(current_user),o,{:verb => "edit", :module_name=>"order"}) {
      success = lambda {|so|
        add_flash :notices, "Sale was updated successfully."
        redirect_to so
      }
      failure = lambda {|so,errors|
        errors_to_flash so, :now=>true
        @sales_order = so
        render :action=>"edit"
      }
      validate_and_save_module o, params[:sales_order], success, failure
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
      end
    }
  end
end
