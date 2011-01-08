class DeliveriesController < ApplicationController
  
	def root_class
		Delivery
	end
	
  def add_sets
    delivery = Delivery.find(params[:id])
    action_secure(delivery.can_edit?(current_user),delivery,{:verb => "add items to",:module_name=>"delivery"}) {
      x = params[:delivery][:piece_set_attributes]
      q = x.keys
      q.each do |k|
        ps_params = x[k]
        unless (Float(ps_params[:quantity]).nil? rescue true) || ps_params[:quantity].to_f == 0
          p = PieceSet.new(ps_params)
          p.delivery_id = delivery.id
          same = p.find_same
          if !same.nil?
            same.quantity += ps_params[:quantity].to_f
            same.save
            errors_to_flash same 
          else
            delivery.piece_sets.build(ps_params)
          end
        end 
      end
      delivery.save
      errors_to_flash delivery
      redirect_to delivery_path(delivery)
    }
  end
  
  def unpacked_order_lines
    delivery = Delivery.find(params[:id])
    if delivery.can_edit? current_user
      ord = SalesOrder.find(params[:sales_order_id])
      if ord.can_view? current_user
        piece_sets = ord.make_unpacked_piece_sets
        piece_sets.each do |p|
          sps = delivery.piece_sets.build
          p.attributes.each do |attrib, val|
            sps[attrib] = p[attrib] unless attrib==:id || attrib==:delivery_id
          end
        end
        render :partial => 'unpacked_order_lines', :locals => { :delivery => delivery }
      else
        render :text => "<span class='errors_message'>You do not have permission to work with sales order #{order.order_number}.</span>"
      end
    else
      render :text => "<span class='errors_message'>You do not have permission to edit delivery #{delivery.reference}.</span>"
    end
  end

  # GET /deliveries
  # GET /deliveries.xml
  SEARCH_PARAMS = {
    'ref' => {:field => 'reference', :label => 'Reference'},
    'bol' => {:field => 'bill_of_lading', :label => 'BOL'},
    'mode' => {:field => 'mode', :label => 'Mode'},
    'cust' => {:field => 'customer_name', :label => 'Customer'}
  }
  def index
    @deliveries = build_search(SEARCH_PARAMS,'ref','ref').all.paginate(:page => params[:page])

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @deliveries }
    end
  end

  # GET /deliveries/1
  # GET /deliveries/1.xml
  def show
    d = Delivery.find(params[:id])
    action_secure(d.can_view?(current_user),d,{:lock_check=>false,:verb => "view",:module_name=>"delivery"}) {
      @delivery = d
      respond_to do |format|
        format.html # show.html.erb
        format.xml  { render :xml => @delivery }
      end
    }
  end

  # GET /deliveries/new
  # GET /deliveries/new.xml
  def new
    d = Delivery.new
    action_secure(d.can_edit?(current_user),d,{:lock_check=>false,:verb => "create",:module_name=>"delivery"}) {
      @delivery = d
      respond_to do |format|
        format.html # new.html.erb
        format.xml  { render :xml => @delivery }
      end
    }
  end

  # GET /deliveries/1/edit
  def edit
    d = Delivery.find(params[:id])
    action_secure(d.can_edit?(current_user),d,{:verb => "edit",:module=>"delivery"}) {
      @delivery = d
    }
  end

  # POST /deliveries
  # POST /deliveries.xml
  def create
    d = Delivery.new(params[:delivery])
    action_secure(d.can_edit?(current_user),d,{:verb => "create",:module_name=>"delivery"}) {
      @delivery = d

      respond_to do |format|
        if @delivery.save
					if update_custom_fields @delivery
						add_flash :notices, "Delivery was created successfully."
					end
          History.create_delivery_changed(@delivery, current_user, delivery_url(@delivery))
          format.html { redirect_to(@delivery) }
          format.xml  { render :xml => @delivery, :status => :created, :location => @delivery }
        else
          errors_to_flash @delivery
          format.html { render :action => "new" }
          format.xml  { render :xml => @delivery.errors, :status => :unprocessable_entity }
        end
      end
    }
  end

  # PUT /deliveries/1
  # PUT /deliveries/1.xml
  def update
    d = Delivery.find(params[:id])
    action_secure(d.can_edit?(current_user),d,{:verb => "edit",:module_name=>"delivery"}) {
      @delivery = d
      respond_to do |format|
        if @delivery.update_attributes(params[:delivery])
					if update_custom_fields @delivery
						add_flash :notices, "Delivery was updated successfully."
					end
          History.create_delivery_changed(@delivery, current_user, delivery_url(@delivery))
          format.html { redirect_to(@delivery) }
          format.xml  { head :ok }
        else
          errors_to_flash @delivery, :now => true
          format.html { render :action => "edit" }
          format.xml  { render :xml => @delivery.errors, :status => :unprocessable_entity }
        end
      end
    }
  end

  # DELETE /deliveries/1
  # DELETE /deliveries/1.xml
  def destroy
    d = Delivery.find(params[:id])
    action_secure(d.can_edit?(current_user),d,{:verb => "delete",:module_name=>"delivery"}) {
      @delivery = d
      @delivery.destroy
      errors_to_flash @delivery
      respond_to do |format|
        format.html { redirect_to(deliveries_url) }
        format.xml  { head :ok }
      end
    }
  end
  
    private    
    def secure
        r = Delivery.where("1=0")
        if current_user.company.master
          r = Delivery
        elsif current_user.company.carrier
          r = current_user.company.carrier_deliveries
        elsif current_user.company.customer
          r = current_user.company.customer_deliveries
        else
          add_flash :errors, "You do not have permission to search for orders."
          return Order.where("1=0")
        end
        r.select("DISTINCT 'deliveries'.*")
    end
end
