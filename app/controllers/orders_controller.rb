class OrdersController < ApplicationController
		
		def root_class
			Order
		end

    # GET /orders
    # GET /orders.xml
    SEARCH_PARAMS = {
        'o_num' => {:field => 'order_number', :label=> 'Order Number'},
        'p_name' => {:field => 'order_lines_product_name', :label => 'Product Name'},
        'v_name' => {:field => 'vendor_name', :label => 'Vendor Name'},
        'o_date' => {:field => 'order_date', :label => 'Order Date'},
        'p_id'   => {:field => 'order_lines_product_unique_identifier',:label => 'Product ID'}
    }

    def index
        s = build_search(SEARCH_PARAMS,'o_num','o_date','d')

        respond_to do |format|
            format.html {
                @orders = s.all.paginate(:per_page => 20, :page => params[:page])
                render :layout => 'one_col'
            }
            format.xml  { render :xml => (@orders=s.all) }
            format.csv {
              import_config_id = params[:ic]
              i_config = nil
              unless import_config_id.nil? || (i_config = ImportConfig.find(import_config_id)).nil?
                  @ic = i_config
                  @orders = s.all
                  @detail_lambda = lambda {|h| h.order_lines}
                  render_csv('orders.csv')
              else
                  error_redirect "The file format you specified could not be found."
              end
            }
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
    def secure
        r = Order.where("1=0")
        if current_user.company.master
        r = Order
        elsif current_user.company.vendor
            r = current_user.company.vendor_orders
        else
            add_flash :errors, "You do not have permission to search for orders."
            return Order.where("1=0")
        end
        r.select("DISTINCT 'orders'.*").includes(:vendor).includes(:order_lines => [:product, :piece_sets])
    end
end
