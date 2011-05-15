class ShipmentsController < ApplicationController
  
	def root_class
	  Shipment
	end
	
  def index
    advanced_search CoreModule::SHIPMENT
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
        redirect_update s
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
end
