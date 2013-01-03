require 'open_chain/field_logic'
require 'open_chain/bulk_update'
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
      p.load_custom_values #caches all custom values
      @json_product = json_product_for_classification @product
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
    action_secure(current_user.add_products?,p,{:verb => "create",:module_name=>"product",:lock_check=>false}) {
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
    action_secure(current_user.add_products?,p,{:verb => "create",:module_name=>"product"}) {
      succeed = lambda { |p|
        respond_to do |format|
          add_flash :notices, "Product created successfully."
          format.html { redirect_to p }
        end
      }
      failure = lambda { |p,e|
        respond_to do |format|
          @product = Product.new(params[:product]) #transaction failure requires new object
          set_custom_fields(@product) {|cv| @product.inject_custom_value cv}
          e.full_messages.each {|m| @product.errors[:base] << m}
          errors_to_flash @product, :now=>true
          format.html { render :action=>"new"}
        end
      }
      before_validate = lambda { |p|
        save_classification_custom_fields(p,params[:product])
        update_status p
        if current_user.company.importer? && !p.importer_id.nil? && p.importer!=current_user.company && !current_user.company.linked_companies.include?(p.importer)
          p.errors[:base] << "You do not have permission to set importer to company #{p.importer_id}"
          raise OpenChain::ValidationLogicError
        end
      }
      validate_and_save_module(p,params[:product],succeed, failure,:before_validate=>before_validate)
    }  
  end

  # PUT /products/1
  # PUT /products/1.xml
  def update
    p = Product.find(params[:id])
    action_secure(p.can_edit?(current_user),p,{:verb => "edit",:module_name=>"product"}) {
      succeed = lambda {|p|
        add_flash :notices, "Product was saved successfully."
        redirect_update p, (params[:c_classify] ? "classify" : "edit")
      }
      failure = lambda {|p,errors|
        errors_to_flash p
        error_redirect
      }
      before_validate = lambda {|p|
        save_classification_custom_fields p,params[:product]
        update_status p
        if current_user.company.importer? && !p.importer_id.nil? && p.importer!=current_user.company && !current_user.company.linked_companies.include?(p.importer)
          p.errors[:base] << "You do not have permission to set importer to company #{p.importer_id}"
          raise OpenChain::ValidationLogicError
        end
      }
      validate_and_save_module(p,params[:product],succeed, failure,:before_validate=>before_validate)
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
  

  def bulk_edit
    @pks = params[:pk]
    @search_run = params[:sr_id] ? SearchRun.find(params[:sr_id]) : nil
  end

  def bulk_update
    action_secure(current_user.edit_products?,Product.new,{:verb => "edit",:module_name=>module_label.downcase.pluralize}) {
      [:unique_identifier,:id,:vendor_id].each {|f| params[:product].delete f} #delete fields from hash that shouldn't be bulk updated
      params[:product].each {|k,v| params[:product].delete k if v.blank?}
      params[:product_cf].each {|k,v| params[:product_cf].delete k if v.blank?}
      params.delete :utf8
      Product.delay.batch_bulk_update(current_user, params)
      add_flash :notices, "These products will be updated in the background.  You will receive a system message when they're ready."
      redirect_to products_path
    }
  end

  def bulk_classify
    @pks = params[:pk]
    @search_run = params[:sr_id] ? SearchRun.find(params[:sr_id]) : nil
    @base_product = Product.new
    OpenChain::BulkUpdateClassification.build_common_classifications (@search_run ? @search_run : @pks), @base_product
    json = json_product_for_classification(@base_product) #do this outside of the render block because it also preps the empty classifications
    respond_to do |format|
        format.html { render }
        format.json  { render :json=>json }
    end
  end

  def bulk_update_classifications
    action_secure(current_user.edit_classifications?,Product.new,{:verb=>"classify",:module_name=>module_label.downcase.pluralize}) {
      OpenChain::BulkUpdateClassification.delay.go_serializable params.to_json, current_user.id 
      add_flash :notices, "These products will be updated in the background.  You will receive a system message when they're ready."
      redirect_to products_path
    }
  end

  #instant classify the given objects
  def bulk_instant_classify
    action_secure(current_user.edit_classifications?,Product.new,{:verb=>"instant classify",:module_name=>module_label.downcase.pluralize}) {
      OpenChain::BulkInstantClassify.delay.go_serializable params.to_json, current_user.id
      add_flash :notices, "These products will be instant classified in the background.  You will receive a system message when they're ready."
      redirect_to products_path
    }
  end

  #render html block for instant classification preview on a single product
  def show_bulk_instant_classify
    @pks = params[:pk]
    @search_run = params[:sr_id] ? SearchRun.find(params[:sr_id]) : nil 
    @preview_product = @pks.blank? ? @search_run.current_object : Product.find(@pks.values.first)
    @preview_instant_classification = InstantClassification.find_by_product @preview_product, current_user
  end
    
    private

    def secure_classifications
      params[:product].delete(:classifications_attributes) unless params[:product].nil? || current_user.edit_classifications?
    end
    
    def save_classification_custom_fields(product,product_params)
      OpenChain::CustomFieldProcessor.new(params).save_classification_custom_fields product, product_params
    end

    def module_label
      CoreModule::PRODUCT.label
    end

  def json_product_for_classification p
    pre_loaded_countries = p.classifications.collect {|c| c.country_id} #don't use pluck here because bulk action does everything in memory
    Country.import_locations.sort_classification_rank.each do |c|
      p.classifications.build(:country=>c).tariff_records.build unless pre_loaded_countries.include? c.id
    end
    p.to_json(:include=>{:classifications=>{:include=>[:country,:tariff_records]}})
  end
end
