class ProductsController < ApplicationController
  include Worksheetable
  before_filter :secure_classifications

	def root_class 
		Product
	end

    def index
      @bulk_actions = {}
      @bulk_actions["Edit Selected"]=bulk_edit_products_path if current_user.edit_products?
      @bulk_actions["Update Selected"]=bulk_update_products_path if current_user.edit_classifications?
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
            format.json { render :json => @product }
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
                  format.html { 
                    redirect_update @product, (params[:c_classify] ? "classify" : "edit") 
                  }
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

    
    def classify
      p = Product.find(params[:id])
      action_secure(p.can_classify?(current_user),p,{:verb => "classify for",:module_name=>"product"}) {
        @product = p
        Country.import_locations.sort_classification_rank.each do |c|
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
        add_flash :notices, "Auto-classification complete, select tariffs below."
        render 'classify'
      }
    end

  def bulk_edit
    @pks = params[:pk]
  end

  def bulk_update
    action_secure(current_user.edit_products?,Product.new,{:verb => "edit",:module_name=>module_label.downcase.pluralize}) {
      @pks = params[:pk]
      good_count = @pks.size
      @pks.values.each do |key|
        p = Product.find key
        if p.can_edit?(current_user)
          [:unique_identifier,:id,:vendor_id].each {|f| params[:product].delete f} #delete fields from hash that shouldn't be bulk updated
          if p.update_attributes(params[:product])
            if update_custom_fields p
              update_status p 
            else
              good_count += -1
            end
            History.create_product_changed(p, current_user, product_url(p))
          else
            good_count += -1
          end
        else
          good_count += -1
          add_flash :errors, "You do not have permission to edit product #{p.unique_identifier}.  Other products have been updated."
        end
      end
      add_flash :notices, "#{help.pluralize good_count, module_label.downcase} updated successfully."
      redirect_to products_path
    }
  end

  def bulk_classify

  end

  def bulk_update_classifications

  end
    
    private
    def secure_classifications
      params[:product][:classifications_attributes] = nil unless params[:product].nil? || current_user.edit_classifications?
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

    def module_label
      CoreModule::PRODUCT.label
    end

end
