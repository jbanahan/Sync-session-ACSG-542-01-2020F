class ShipmentsController < ApplicationController
  
	def root_class
	  Shipment
	end
	
  def undo_receive
    shipment = Shipment.find(params[:id])
    action_secure(current_user.company.master,shipment,{:verb => "edit",:module_name=>"shipment"}) {
      ps = PieceSet.find(params[:ps_id])
      ps.inventory_in = nil
      errors_to_flash ps unless ps.save
    }
    redirect_to shipment
  end
  
  def receive_inventory
    shipment = Shipment.find(params[:id])
    action_secure(current_user.company.master,shipment,{:verb => "receive inventory",:module_name=>"shipment"}) {
      inv_in = InventoryIn.new
      params[:shipment][:piece_set_attributes].each do |k, ps_params|
        unless (Float(ps_params[:quantity]).nil? rescue true) || ps_params[:quantity].to_f == 0
          qty = ps_params[:quantity].to_f #how much did the user tell us to receive
          ps = PieceSet.find(ps_params[:id])
          inv_in.save if inv_in.id.nil?
          ps.inventory_in = inv_in
          if qty != ps.quantity #under recieve
            over = qty > ps.quantity
            new_ps = PieceSet.new(ps.attributes)
            new_ps.quantity = (qty - ps.quantity).abs
            new_ps.adjustment_type = over ? 'over receipt adjustment' : 'short receipt remainder'
            unless over
              new_ps.inventory_in = nil
              ps.quantity = qty
            end 
            errors_to_flash new_ps unless new_ps.save
          end      
          errors_to_flash ps unless ps.save
        end
      end
      shipment.update_unshipped_quantities
      redirect_to shipment_path(shipment)
    }
  end
  
  def add_sets
    shipment = Shipment.find(params[:id])
    action_secure(shipment.can_edit?(current_user),shipment,{:verb => "add items to",:module_name=>"shipment"}) {
      x = params[:shipment][:piece_set_attributes]
      q = x.keys
      q.each do |k|
        ps_params = x[k]
        unless (Float(ps_params[:quantity]).nil? rescue true) || ps_params[:quantity].to_f == 0
          p = PieceSet.new(ps_params)
          p.shipment_id = shipment.id
          same = p.find_same
          if !same.nil?
            same.quantity += ps_params[:quantity].to_f
            same.save
            errors_to_flash same 
          else
            shipment.piece_sets.build(ps_params)
          end
        end 
      end
      shipment.save
      shipment.update_unshipped_quantities
      errors_to_flash shipment  
      redirect_to shipment_path(shipment)
    }
  end
  
  def unpacked_order_lines
    shipment = Shipment.find(params[:id])
    if shipment.can_edit? current_user
      ord = Order.find(params[:order_id])
      if ord.can_view? current_user
        piece_sets = ord.make_unpacked_piece_sets
        piece_sets.each do |p|
          sps = shipment.piece_sets.build
          p.attributes.each do |attrib, val|
            sps[attrib] = p[attrib] unless attrib==:id || attrib==:shipment_id
          end
        end
        render :partial => 'unpacked_order_lines', :locals => { :shipment => shipment }
      else
        render :text => "<span class='errors_message'>You do not have permission to work with order #{order.order_number}.</span>"
      end
    else
      render :text => "<span class='errors_message'>You do not have permission to edit shipment #{shipment.reference}.</span>"
    end  
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
  		@shipping_addresses = Address.find_shipping
  		@carriers = Company.find_carriers
      @vendors = Company.find_vendors
  		
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
  		@shipping_addresses = Address.find_shipping
  		@carriers = Company.find_carriers
      @vendors = Company.find_vendors     
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
					@shipment.update_unshipped_quantities
          History.create_shipment_changed(@shipment, current_user, shipment_url(@shipment))
          format.html { redirect_to(@shipment) }
          format.xml  { render :xml => @shipment, :status => :created, :location => @shipment }
        else
          errors_to_flash @shipment
  				@shipping_addresses = Address.find_shipping
          @carriers = Company.find_carriers
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
					@shipment.update_unshipped_quantities
					History.create_shipment_changed(@shipment, current_user, shipment_url(@shipment))
          format.html { redirect_to(@shipment) }
          format.xml  { head :ok }
        else
  				@shipping_addresses = Address.find_shipping
          @carriers = Company.find_carriers
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
      related_order_lines = {}
      @shipment.piece_sets.each do |p|
        unless p.order_line.nil?
          related_order_lines[p.order_line.id] = p.order_line
        end
      end
      @shipment.destroy
      related_order_lines.each {|o| o.make_unshipped_remainder_piece_set.save }
      errors_to_flash @shipment
      respond_to do |format|
        format.html { redirect_to(shipments_url) }
        format.xml  { head :ok }
       end
    }
  end
  
  private 
  def secure(base)
    
    if current_user.company.master
      return base
    elsif current_user.company.vendor 
      return base.where(:vendor_id => current_user.company)
    elsif current_user.company.carrier
      return base.where(:carrier_id => current_user.company)
    else
      add_flash :errors, "You do not have permission to search for shipments."
      return base.where("1=0")
    end
  end
  
end
