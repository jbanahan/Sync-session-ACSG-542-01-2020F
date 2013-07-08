class ShipmentsController < ApplicationController
  
	def root_class
	  Shipment
	end
	
  def index
    redirect_to advanced_search CoreModule::SHIPMENT, params[:force_search]
  end

  # GET /shipments/1
  # GET /shipments/1.xml
  def show
    s = Shipment.find(params[:id])
    action_secure(s.can_view?(current_user),s,{:lock_check=>false,:verb => "view",:module_name=>"shipment"}) {
      @shipment = s
      @products = Product.where(:vendor_id=>s.vendor)
      respond_to do |format|
        format.html # show.html.erb
        format.xml  { render :xml => @shipment }
      end
    }
  end

  # GET /shipments/new
  # GET /shipments/new.xml
  def new
    s = Shipment.new
    action_secure(s.can_edit?(current_user),s,{:verb => "create",:module_name=>"shipment"}) {
      @shipment = s
      respond_to do |format|
        format.html # new.html.erb
        format.xml  { render :xml => @shipment }
      end
    }
  end

  # GET /shipments/1/edit
  def edit
    s = Shipment.find(params[:id])
    action_secure(s.can_edit?(current_user),s,{:verb => "edit",:module_name=>"shipment"}) {
      @shipment = s
    }
  end

  # POST /shipments
  # POST /shipments.xml
  def create
    s = Shipment.new(params[:shipment])
    action_secure(s.can_edit?(current_user),s,{:verb => "create",:module_name=>"shipment"}) {
      succeed = lambda {|sh|
			  add_flash :notices, "Shipment was created successfully."
        redirect_to sh
      }
      failure = lambda {|sh,errors|
        @shipment = Shipment.new(params[:shipment]) #transaction failure requires new object
        set_custom_fields(@shipment) {|cv| @shipment.inject_custom_value cv}
        errors.full_messages.each {|m| @shipment.errors[:base]<<m}
        errors_to_flash @shipment
        render :action=>"new"
      }
      validate_and_save_module(s,params[:shipment],succeed,failure)
    }
  end

  # PUT /shipments/1
  # PUT /shipments/1.xml
  def update
    s = Shipment.find(params[:id])
    action_secure(s.can_edit?(current_user),s,{:verb => "edit",:module_name=>"shipment"}) {
      succeed = lambda {|shp|
        add_flash :notices, "Shipment was updated successfully."
        redirect_to shp
      }
      failure = lambda {|shp,errors|
        errors_to_flash shp, :now=>true
        @shipment = shp
        render :action=>"edit"
      }
      validate_and_save_module s, params[:shipment], succeed, failure
    }
  end

  # DELETE /shipments/1
  # DELETE /shipments/1.xml
  def destroy
    s = Shipment.find(params[:id])
    action_secure(s.can_edit?(current_user),s,{:verb => "delete",:module_name=>"shipment"}) {
      @shipment = s
      @shipment.destroy
      errors_to_flash @shipment
      respond_to do |format|
        format.html { redirect_to(shipments_url) }
        format.xml  { head :ok }
       end
    }
  end
  
  # show the screen to generate a new commercial invoice
  def make_invoice
    s = Shipment.find(params[:id])
    action_secure(s.can_edit?(current_user),s,{:verb => "edit",:module_name=>"shipment"}) {
      @shipment = s
      @available_lines = []
      @used_lines = []
      @shipment.shipment_lines.each do |sl|
        if sl.commercial_invoice_lines.empty?
          @available_lines << sl
        else
          @used_lines << sl
        end
      end
    }
  end
  # generate a commercial invoice based on the given shipment lines and additional parameters
  def generate_invoice
    s = Shipment.find params[:id]
    action_secure(s.can_edit?(current_user),s,{:verb => "edit",:module_name=>"shipment"}) {
      field_hash = params[:extra_fields]
      field_hash ||= {}
      ship_lines = s.shipment_lines.where("shipment_lines.id IN (?)",params[:shpln].values.to_a).all
      ship_lines.delete_if {|sl| !sl.commercial_invoice_lines.empty?}
      begin
        CommercialInvoiceMap.generate_invoice! current_user, ship_lines, field_hash
        add_flash :notices, "Commercial Invoice created successfully."
        redirect_to s
      rescue
        $!.log_me ["User: #{current_user.username}","Referrer: #{request.referrer}", "Params: #{params}"]
        add_flash :errors, "Invoice generation failed: #{$!.message}"
        redirect_to request.referrer
      end
    }
  end
end
