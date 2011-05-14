require 'open_chain/field_logic'
class ProductsController < ApplicationController
  include Worksheetable
  before_filter :secure_classifications

	def root_class 
		Product
	end

    def index
      @bulk_actions = CoreModule::PRODUCT.bulk_actions current_user
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
        validate_and_save_module(@product,params[:product]) {
          save_classification_custom_fields(@product,params[:product])
          update_status @product
        }
        respond_to do |format|
          if @product.errors.empty?
            add_flash :notices, "Product created successfully."
            format.html { redirect_to @product }
          else
            errors_to_flash @product, :now=>true
            @divisions = Division.all
            @vendors = Company.where(:vendor=>true)
            format.html { render :action=>"new"}
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
          validate_and_save_module(@product,params[:product]) {
            save_classification_custom_fields @product,params[:product]
            update_status @product
          }
          respond_to do |format|
            if @product.errors.empty?
              format.html {redirect_update @product, (params[:c_classify] ? "classify" : "edit")}
            else
              errors_to_flash @product 
              format.html {error_redirect}
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
        base_country = Country.find_cached_by_id(params[:base_country_id])
        @product.auto_classify(base_country)
        add_flash :notices, "Auto-classification complete, select tariffs below."
        render 'classify'
      }
    end

  def bulk_auto_classify
    @pks = params[:pk]
    @search_run = params[:sr_id] ? SearchRun.find(params[:sr_id]) : nil
    @base_product = Product.new(params[:product])
    base_country = Country.find_cached_by_id(params[:base_country_id])
    @base_product.auto_classify base_country
    add_flash :notices, "Auto-classification complete, select tariffs below."
    render 'bulk_classify'
  end

  def bulk_edit
    @pks = params[:pk]
    @search_run = params[:sr_id] ? SearchRun.find(params[:sr_id]) : nil
  end

  def bulk_update
    action_secure(current_user.edit_products?,Product.new,{:verb => "edit",:module_name=>module_label.downcase.pluralize}) {
      [:unique_identifier,:id,:vendor_id].each {|f| params[:product].delete f} #delete fields from hash that shouldn't be bulk updated
      params[:product].each {|k,v| params[:product].delete k if v.blank?}
      good_count = nil 
      bulk_objects do |gc,p|
        good_count = gc if good_count.nil?
        if p.can_edit?(current_user)
          validate_and_save_module(p,params[:product]) {
            update_status p
          }
          if !p.errors.empty?
            good_count += -1
            p.errors.full_messages.each do |m|
              add_flash :errors, "Error updating product #{p.unique_identifier}: #{m}"
            end
          end
        else
          good_count += -1
          add_flash :errors, "You do not have permission to edit product #{p.unique_identifier}."
        end
      end
      add_flash :notices, "#{help.pluralize good_count, module_label.downcase} updated successfully."
      redirect_to products_path
    }
  end

  def bulk_classify
    @pks = params[:pk]
    @search_run = params[:sr_id] ? SearchRun.find(params[:sr_id]) : nil
    @base_product = Product.new
    Country.import_locations.sort_classification_rank.each do |c|
      @base_product.classifications.build(:country=>c)
    end
  end

  def bulk_update_classifications
    action_secure(current_user.edit_classifications?,Product.new,{:verb=>"classify",:module_name=>module_label.downcase.pluralize}) {
      good_count = nil
      bulk_objects do |gc, p|
        begin
          if p.can_classify?(current_user)
            Product.transaction do
              good_count = gc if good_count.nil?
              #reset classifications
              p.classifications.destroy_all
              validate_and_save_module(p,params[:product],true) {
                save_classification_custom_fields(p,params[:product])
                update_status p
              }
            end
          else
            add_flash :errors, "You do not have permission to classify product #{p.unique_identifier}."
            good_count += -1
          end
        rescue OpenChain::ValidationLogicError
          #ok to do nothing here
        end
        if !p.errors.empty?
          good_count += -1
          p.errors.full_messages.each do |m|
            add_flash :errors, "Error updating product #{p.unique_identifier}: #{m}"
          end
        end
      end
      add_flash :notices, "#{help.pluralize good_count, module_label.downcase} updated successfully."
      redirect_to products_path
    }
  end
    
    private

    def bulk_objects &block
      sr_id = params[:sr_id]
      if !sr_id.blank? && sr_id.match(/^[0-9]*$/)
        sr = SearchRun.find sr_id
        good_count = sr.total_objects
        sr.all_objects.each do |o|
          yield good_count, o
        end
      else
        pks = params[:pk]
        good_count = pks.size
        pks.values.each do |key|
          p = Product.find key
          yield good_count, p  
        end
      end
    end

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
