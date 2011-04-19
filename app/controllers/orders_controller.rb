class OrdersController < ApplicationController
		
		def root_class
			Order
		end

    def index
      advanced_search CoreModule::ORDER
    end

    def all_open
      if current_user.view_orders?
        respond_to do |format|
          format.json { render :json => Order.search_secure(current_user,Order).to_json(:only =>[:id,:order_number]) }
        end
      else
        error_redirect "You do not have permission to view orders."
      end
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
        @divisions = Division.all
        @vendors = Company.find_vendors.not_locked
        respond_to do |format|
            format.html # new.html.erb
            format.xml  { render :xml => @order }
        end
      }
    end

    # GET /orders/1/edit
    def edit
      o = Order.find(params[:id])
      action_secure(current_user.company.master,o,{:verb => "edit", :module_name=>"order"}) {
        @order = o
        @divisions = Division.all
        @vendors = Company.find_vendors.not_locked
      }
    end

    # POST /orders
    # POST /orders.xml
    def create
      o = Order.new(params[:order])
      action_secure(current_user.company.master,o,{:verb => "edit", :module_name=>"order"}) {
        @order = o
        respond_to do |format|
          if @order.save
              History.create_order_changed(@order,current_user,order_url(@order))
							if update_custom_fields @order
                  add_flash :notices, "Order was created successfully."
                end
              format.html { redirect_to(@order) }
              format.xml  { render :xml => @order, :status => :created, :location => @order }
          else
              errors_to_flash @order, :now => true
              @divisions = Division.all
              @vendors = Company.find_vendors.not_locked
              format.html { render :action => "new" }
              format.xml  { render :xml => @order.errors, :status => :unprocessable_entity }
          end
        end        
      }
    end

    # PUT /orders/1
    # PUT /orders/1.xml
    def update
      o = Order.find(params[:id])
      action_secure(current_user.company.master,o,{:module_name=>"order"}) {
        @order = o
        respond_to do |format|
            if @order.update_attributes(params[:order])
                History.create_order_changed(@order,current_user,order_url(@order))
                if update_custom_fields @order
                  add_flash :notices, "Order was updated successfully."
                end
                format.html {
                    redirect_update @order
                }
                format.xml  { head :ok }
            else
                errors_to_flash @order, :now => true
                format.html { render :action => "edit" }
                format.xml  { render :xml => @order.errors, :status => :unprocessable_entity }
            end
        end
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
end
