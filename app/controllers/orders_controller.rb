require 'open_chain/business_rule_validation_results_support'
require 'open_chain/bulk_action/bulk_action_runner'
require 'open_chain/bulk_action/bulk_action_support'
require 'open_chain/bulk_action/bulk_order_update'
require 'open_chain/custom_handler/lumber_liquidators/lumber_bulk_send_to_sap'

class OrdersController < ApplicationController
  include OpenChain::BusinessRuleValidationResultsSupport
  include OpenChain::BulkAction::BulkActionSupport
  include BulkSendToTestSupport

  def set_page_title
    @page_title ||= 'Order'
  end

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
        @state_button_path = 'orders'
        @state_button_object_id = @order.id
        @products = @order.vendor ? @order.vendor.products_as_vendor : []
        respond_to do |format|
            format.html {
              freeze_custom_values @order
              custom_template = CustomViewTemplate.for_object('order_view',@order)
              if custom_template.blank?
                render
              else
                render template: custom_template
              end
            }
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
    action_secure(o.can_edit?(current_user),o,{:verb => "edit", :module_name=>"order"}) {
      @order = o
    }
  end

  # POST /orders
  # POST /orders.xml
  def create
    # Create a dummy order for security validations
    ord = Order.new
    ord.assign_model_field_attributes params[:order], no_validation: true
    action_secure(current_user.company.master,ord,{:verb => "edit", :module_name=>"order"}) {
      success = lambda {|o|
        add_flash :notices, "Order created successfully."
        redirect_to o
      }
      failure = lambda {|o,errors|
        errors_to_flash o, :now=>true
        @order = Order.new
        @order.assign_model_field_attributes params[:order], no_validation: true
        @divisions = Division.all
        @vendors = Company.vendors.not_locked
        render :action=>"new"
      }
      validate_and_save_module(Order.new,params[:order],success,failure)
    }
  end

  # PUT /orders/1
  # PUT /orders/1.xml
  def update
    o = Order.find(params[:id])
    action_secure(o.can_edit?(current_user),o,{:module_name=>"order"}) {
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

  def accept
    o = Order.find params[:id]
    action_secure(o.can_be_accepted? && o.can_accept?(current_user),o,{:verb => "accept", :module_name=>"order"}) {
      o.async_accept! current_user
      add_flash :notices, "Order has been accepted."
      redirect_to o
    }
  end

  def unaccept
    o = Order.find params[:id]
    action_secure(o.can_accept?(current_user),o,{:verb => "unaccept", :module_name=>"order"}) {
      o.async_unaccept! current_user
      add_flash :notices, "Order acceptance has been removed."
      redirect_to o
    }
  end

  def validation_results
    generic_validation_results(Order.find params[:id])
  end

  def bulk_update
    opts = {}
    opts = params['mf_hsh']
    OpenChain::BulkAction::BulkActionRunner.process_from_parameters current_user, params, OpenChain::BulkAction::BulkOrderUpdate, opts
    render json: {'ok'=>'ok'}
  end

  def bulk_update_fields
    mf_hsh = {}
    mfs = CoreModule::ORDER.model_fields(current_user) {|mf| mf.can_mass_edit?(current_user)}
    html = render_to_string(partial: 'bulk_update_modal', locals: { mfs: mfs })
    mfs.each_pair { |field_name, mf| mf_hsh[field_name] = mf.label }
    c = get_bulk_count(params[:pk], params[:sr_id])
    render json: {count: c, mf_hsh: mf_hsh, html: html}
  end

  def bulk_send_to_sap
    begin
      OpenChain::BulkAction::BulkActionRunner.process_from_parameters current_user, params, OpenChain::CustomHandler::LumberLiquidators::BulkSendToSap, {max_results: 100}
      add_flash :notices, "Documents have been requested for transmission to SAP.  Please allow a few minutes for them to be sent."
    rescue OpenChain::BulkAction::TooManyBulkObjectsError => e
      add_flash :errors, "You may not send more than 100 orders to SAP at one time."
    end
    redirect_to request.referrer || "/"
  end

  def send_to_sap
    OpenChain::CustomHandler::LumberLiquidators::BulkSendToSap.delay.act(current_user, params[:id], {}, nil, nil)
    add_flash :notices, "Document has been requested for transmission to SAP.  Please allow a few minutes for it to be sent."
    redirect_to request.referrer || "/"
  end

  private
    def freeze_custom_values o
      o.freeze_custom_values
      o.order_lines.each do |ol|
        ol.freeze_custom_values
        ol.product.try(:freeze_custom_values)
      end
    end

end
