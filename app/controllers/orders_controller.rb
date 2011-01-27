class OrdersController < ApplicationController
		
		def root_class
			Order
		end

    def index
      advanced_search CoreModule::ORDER
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
                format.html { redirect_to(@order) }
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

    private    
    def secure(base)
      if current_user.company.master
        return base
      elsif current_user.company.vendor
        return base.where(:vendor_id => current_user.company)
      else
        add_flash :errors, "You do not have permission to search for orders."
        return base.where("1=0")
      end
    end
end
