class OrdersController < ApplicationController
  include ValidationResultsHelper
	
	def root_class
		Order
	end

  def index
    flash.keep
    redirect_to advanced_search CoreModule::ORDER, params[:force_search]
  end

  # GET /orders/1
  # GET /orders/1.xml
  def show
      o = Order.find(params[:id])
      action_secure(o.can_view?(current_user),o,{:lock_check => false, :verb => "view", :module_name=>"order"}) {
        @order = o
        @products = Product.where(["vendor_id = ?",@order.vendor])
        respond_to do |format|
            format.html # show.html.erb
            format.xml  { render :xml => @order }
            format.json { render :json => @order.to_json(:only=>[:id,:order_number], :include=>{
              :order_lines => {:only=>[:line_number,:quantity,:id], :include=>{:product=>{:only=>[:id,:name]}}}  
            })}
        end
      }
  end

  # GET /orders/new
  # GET /orders/new.xml
  def new
    o = Order.new
    action_secure(current_user.company.master,o,{:lock_check=>false,:verb=>"create", :module_name=>"order"}) {
      @order = o
    }
  end

  # GET /orders/1/edit
  def edit
    o = Order.find(params[:id])
    action_secure(current_user.company.master,o,{:verb => "edit", :module_name=>"order"}) {
      @order = o
    }
  end

  # POST /orders
  # POST /orders.xml
  def create
    o = Order.new(params[:order])
    action_secure(current_user.company.master,o,{:verb => "edit", :module_name=>"order"}) {
      success = lambda {|o|
        add_flash :notices, "Order created successfully."
        redirect_to o
      }
      failure = lambda {|o,errors|
        errors_to_flash o, :now=>true
        @order = Order.new(params[:order])
        set_custom_fields(@order) {|cv| @order.inject_custom_value cv}
        @divisions = Division.all
        @vendors = Company.vendors.not_locked
        render :action=>"new"
      }
      validate_and_save_module(o,params[:order],success,failure)
    }
  end

  # PUT /orders/1
  # PUT /orders/1.xml
  def update
    o = Order.find(params[:id])
    action_secure(current_user.company.master,o,{:module_name=>"order"}) {
      succeed = lambda {|ord|
        add_flash :notices, "Order was updated successfully."
        redirect_to ord
      }
      failure = lambda {|ord,errors|
        errors_to_flash ord, :now=>true
        @order = ord
        @divisions = Division.all
        @vendors = Company.vendors.not_locked
        render :action=>"edit"
      }
      validate_and_save_module o, params[:order], succeed, failure
    }
  end

  # DELETE /orders/1
  # DELETE /orders/1.xml
  def destroy
    o = Order.find(params[:id])
    action_secure(current_user.company.master,o,{:verb => "delete", :module_name=>"order"}) {
      @order = o
      @order.destroy
      errors_to_flash @order
      respond_to do |format|
          format.html { redirect_to(orders_url) }
          format.xml  { head :ok }
      end
    }
  end

  def close
    o = Order.find params[:id]
    action_secure(o.can_close?(current_user),o,{:verb => "close", :module_name=>"order"}) {
      o.async_close! current_user
      add_flash :notices, "Order has been closed."
      redirect_to o
    }
  end

  def reopen
    o = Order.find params[:id]
    action_secure(o.can_close?(current_user),o,{:verb => "reopen", :module_name=>"order"}) {
      o.async_reopen! current_user
      add_flash :notices, "Order has been reopened."
      redirect_to o
    }
  end

  def validation_results
    o = Order.find params[:id]
    respond_to do |format|
    format.html {
      action_secure(o.can_view?(current_user) && current_user.view_business_validation_results?,o,{:lock_check=>false,:verb=>"view",:module_name=>"order"}) {
        @order = o
      }
    }
    format.json {
      
      r = {
        object_number:o.order_number,
        state:o.business_rules_state,
        object_updated_at:o.updated_at,
        single_object:"Order",
        bv_results:[]
      }
      o.business_validation_results.each do |bvr|
        return render_json_error "You do not have permission to view this object", 401 unless bvr.can_view?(current_user)
        h = {
          id:bvr.id,
          state:bvr.state,
          template:{name:bvr.business_validation_template.name},
          updated_at:bvr.updated_at,
          rule_results:[]
        }
        bvr.business_validation_rule_results.each do |rr|
          h[:rule_results] << business_validation_rule_result_json(rr)
        end
        r[:bv_results] << h
      end
      render json: {business_validation_result:r}
    }
    end
  end

end
