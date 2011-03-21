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
      @shipment = s
      respond_to do |format|
        if @shipment.save
					if update_custom_fields @shipment
						add_flash :notices, "Shipment was created successfully."
					end
          History.create_shipment_changed(@shipment, current_user, shipment_url(@shipment))
          format.html { redirect_to(@shipment) }
          format.xml  { render :xml => @shipment, :status => :created, :location => @shipment }
        else
          errors_to_flash @shipment
  				format.html { render :action => "new" }
          format.xml  { render :xml => @shipment.errors, :status => :unprocessable_entity }
        end
      end
    }
  end

  # PUT /shipments/1
  # PUT /shipments/1.xml
  def update
    s = Shipment.find(params[:id])
    action_secure(s.can_edit?(current_user),s,{:verb => "edit",:module_name=>"shipment"}) {
      respond_to do |format|
        @shipment = s
        if @shipment.update_attributes(params[:shipment])
					if update_custom_fields @shipment
						add_flash :notices, "Shipment was updated successfully."
					end
					History.create_shipment_changed(@shipment, current_user, shipment_url(@shipment))
          format.html { redirect_to(@shipment) }
          format.xml  { head :ok }
        else
          errors_to_flash @shipment, :now => true
  				format.html { render :action => "edit" }
          format.xml  { render :xml => @shipment.errors, :status => :unprocessable_entity }
        end
      end
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
