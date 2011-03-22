class DeliveriesController < ApplicationController
  
	def root_class
		Delivery
	end
	

  
  def index
    advanced_search CoreModule::DELIVERY
  end

  # GET /deliveries/1
  # GET /deliveries/1.xml
  def show
    d = Delivery.find(params[:id])
    action_secure(d.can_view?(current_user),d,{:lock_check=>false,:verb => "view",:module_name=>"delivery"}) {
      @delivery = d
      @products = Product.all
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
end
