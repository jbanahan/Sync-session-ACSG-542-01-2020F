class ProductsController < ApplicationController
  before_filter :secure_classifications

	def root_class 
		Product
	end

    def index
      advanced_search CoreModule::PRODUCT
    end

    # GET /products/1
    # GET /products/1.xml
    def show
      p = Product.find(params[:id], :include => [:custom_values,{:classifications => [:custom_values, :tariff_records]}])
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
								  save_classification_custom_fields(@product,params[:product])
								  update_status @product
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
                    save_classification_custom_fields(@product,params[:product])
                    update_status @product
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
    
    def classify
      p = Product.find(params[:id])
      action_secure(p.can_edit?(current_user) && current_user.edit_classifications?,p,{:verb => "classify for",:module_name=>"product"}) {
        @product = p
        Country.import_locations.each do |c|
          p.classifications.build(:country => c) if p.classifications.where(:country_id=>c).empty?
        end
      }
    end
    
    def auto_classify
      p = Product.find(params[:id])
      action_secure(p.can_edit?(current_user) && current_user.edit_classifications?,p,{:verb => "classify for",:module_name=>"product"}) {
        @product = p
        @product.update_attributes(params[:product])
        save_classification_custom_fields(@product,params[:product])
        update_status @product
        base_country = Country.find(params[:base_country_id])
        @product.auto_classify(base_country)
        render 'classify'
      }
    end


    private
    def secure_classifications
      params[:product][:classifications_attributes] = nil unless params[:product].nil? || current_user.edit_classifications?
    end

    def secure(base_search)
      r = base_search.where("1=0")
      if current_user.company.master
        r = base_search
      elsif current_user.company.vendor
        r = base_search.where(:vendor_id => current_user.company)
      else
        add_flash :errors, "You do not have permission to search for orders."
        r = base_search.where("1=0")
      end
      r
    end
    
    def save_classification_custom_fields(product,product_params)
      unless product_params[:classifications_attributes].nil?
        product.classifications.each do |classification|
          product_params[:classifications_attributes].each do |k,v|
            if v[:country_id] == classification.country_id.to_s
              update_custom_fields classification, params[:classification_custom][k.to_sym][:classification_cf] unless params[:classification_custom].nil?
            end  
          end
        end    
      end  
    end

end
