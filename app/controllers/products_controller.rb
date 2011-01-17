class ProductsController < ApplicationController
	def root_class 
		Product
	end
    # GET /products
    # GET /products.xml
    SEARCH_PARAMS = {
        'uid' => {:field => 'unique_identifier', :label => 'Unique ID'},
        'p_name' => {:field => 'name', :label => 'Name'},
        'desc' => {:field => 'description', :label => 'Description'},
        'v_name' => {:field => 'vendor_name', :label => 'Vendor'},
        'div' => {:field => 'division_name', :label => 'Division'}
    }

    def index
        s = build_search(SEARCH_PARAMS,'p_name','p_name')

        respond_to do |format|
            format.html {
                @products = s.paginate(:per_page => 20, :page => params[:page])
                render :layout => 'one_col'
            }
            format.xml  { render :xml => (@products=s.all) }
            format.csv {
              import_config_id = params[:ic]
              i_config = nil
              unless import_config_id.nil? || (i_config = ImportConfig.find(import_config_id)).nil?
                  @ic = i_config
                  @products = s.all
                  @detail_lambda = lambda {|h| nil}
                  render_csv('products.csv')
              else
                  error_redirect "The file format you specified could not be found."
              end
            }
        end
    end

    # GET /products/1
    # GET /products/1.xml
    def show
      p = Product.find(params[:id])
      action_secure(p.can_view?(current_user),p,{:verb => "view",:module_name=>"product",:lock_check=>false}) {
        @product = p
        respond_to do |format|
            format.html # show.html.erb
            format.xml  { render :xml => @product }
        end          
      }
    end

    # GET /products/new
    # GET /products/new.xml
    def new
      p = Product.new
      action_secure(current_user.company.master,p,{:verb => "create",:module_name=>"product",:lock_check=>false}) {
        @product = p

        respond_to do |format|
            format.html # new.html.erb
            format.xml  { render :xml => @product }
        end
      }
    end

    # GET /products/1/edit
    def edit
      p = Product.find(params[:id])
      action_secure(p.can_edit?(current_user),p,{:verb => "edit",:module_name=>"product"}) {
        @product = p
      }
    end

    # POST /products
    # POST /products.xml
    def create
      p = Product.new(params[:product])
      action_secure(current_user.company.master,p,{:verb => "create",:module_name=>"product"}) {
        @product = p
        respond_to do |format|
            if @product.save
								if update_custom_fields @product
									add_flash :notices, "Product created successfully."
								end
                History.create_product_changed(@product, current_user, product_url(@product))
                format.html { redirect_to(@product)}
                format.xml  { render :xml => @product, :status => :created, :location => @product }
            else
                errors_to_flash @product, :now => true
                @divisions = Division.all
                @vendors = Company.where(["vendor = ?",true])
                format.html { render :action => "new" }
                format.xml  { render :xml => @product.errors, :status => :unprocessable_entity }
            end
        end
      }  
    end

    # PUT /products/1
    # PUT /products/1.xml
    def update
        p = Product.find(params[:id])
        action_secure(p.can_edit?(current_user),p,{:verb => "edit",:module_name=>"product"}) {
          @product = p
            respond_to do |format|
                if @product.update_attributes(params[:product])
										if update_custom_fields @product
											add_flash :notices, "Product updated successfully."
										end
                    History.create_product_changed(@product, current_user, product_url(@product))
                    format.html { redirect_to(@product) }
                    format.xml  { head :ok }
                else
                    errors_to_flash @product
                    format.html { render :action => "edit" }
                    format.xml  { render :xml => @product.errors, :status => :unprocessable_entity }
                end
            end
        }
    end

    # DELETE /products/1
    # DELETE /products/1.xml
    def destroy
      p = Product.find(params[:id])
      action_secure(current_user.company.master,p,{:verb => "delete",:module_name=>"product"}) {
        @product = p
        @product.destroy
        errors_to_flash @product

        respond_to do |format|
            format.html { redirect_to(products_url) }
            format.xml  { head :ok }
        end
      }
    end

    def adjust_inventory
      passed = true
      p = Product.find(params[:product_id])
      action_secure(p.can_edit?(current_user),p,{:verb => "adjust inventory for",:module_name=>"product"}) {
        unless (Float(params[:quantity]).nil? rescue true)
          current_inventory = p.current_inventory_qty
          new_inventory = params[:quantity].to_f
          diff = new_inventory - current_inventory
          ps = nil
          if diff>0
            i_in = InventoryIn.create()
            if i_in.errors.empty?
              ps = PieceSet.create(:product => p, :quantity => diff, :inventory_in => i_in)
            else
              errors_to_flash i_in
              passed = false
            end
          elsif diff<0
            i_out = InventoryOut.create()
            if i_out.errors.empty?
              ps = PieceSet.create(:product => p, :quantity => diff.abs, :inventory_out => i_out)
            else
              errors_to_flash i_out
              passed = false
            end
          end
          if ps.errors.empty?
            add_flash :notices, "Inventory adjusted successfully."
          else
            errors_to_flash ps
          end
        else
          add_flash :errors, "New inventory quantity supplied was not a valid number (#{params[:quantity]})"
        end
          redirect_to product_path(p)
      }
    end

    private

    def secure
        r = Product.where("1=0")
        if current_user.company.master
        r = Product
        elsif current_user.company.vendor
            r = current_user.company.vendor_products
        else
            add_flash :errors, "You do not have permission to search for orders."
            return Order.where("1=0")
        end
        r.select("DISTINCT 'orders'.*").includes(:vendor).includes(:order_lines => [:product, :piece_sets])
    end
end
