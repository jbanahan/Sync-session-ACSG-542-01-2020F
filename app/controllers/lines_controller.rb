class LinesController < ApplicationController

  #if you want to use this don't forget to add "post :create_multiple, :on => :collection" to the appropriate resource route
  def create_multiple
    o = find_parent
    action_secure(o.can_edit?(current_user),o,{:verb=>"create lines for",:module_name=>module_name}) {
      line = nil
      begin
        o.transaction do
          params[:lines].each do |p|
            line = child_objects(o).build(p[1])
            line.save if before_save(line)
            OpenChain::FieldLogicValidator.validate! line
          end
          o.create_snapshot if o.respond_to?('create_snapshot')
        end
      rescue OpenChain::ValidationLogicError
        errors_to_flash line unless line.nil?
      end
      redirect_to o
    }
  end

	def create
		o = find_parent
		action_secure(o.can_edit?(current_user),o,{:verb=>"create lines for",:module_name=>module_name}) {
  		line = child_objects(o).build(params[update_symbol])
      begin
        line.transaction do 
          if before_save(line)
            line.save! 
            update_custom_fields line, params[update_custom_field_symbol]
            OpenChain::FieldLogicValidator.validate! line
          end
          o.create_snapshot if o.respond_to?('create_snapshot')
        end
      rescue OpenChain::ValidationLogicError
        errors_to_flash line
      end
		  redirect_to o
		}
	end
	
	def destroy
		o = find_parent
		action_secure(o.can_edit?(current_user),o,{:verb=>"delete lines for",:module_name=>module_name}) {
      set_parent_variable o		  
  		@line = find_line
  		@line.destroy
  		errors_to_flash @line
      o.create_snapshot if o.respond_to?('create_snapshot')
  		redirect_to o 
		}
	end
	
	def edit
		o = find_parent
	  action_secure(o.can_edit?(current_user),o,{:verb=>"edit lines for",:module_name=>module_name}) {
	    set_parent_variable o
      @line = find_line
  		@products = set_products_variable o
  		render render_parent_path
    }
	end
	
	def update
		o = find_parent
		action_secure(o.can_edit?(current_user),o,{:verb=>"edit lines for",:module_name=>module_name}) {
		  set_parent_variable o
      line = find_line 
      line.attributes = params[update_symbol]
      respond_to do |format|
        good = false
        begin
          line.transaction do
            if before_save(line) 
              line.save!
              update_custom_fields line, params[update_custom_field_symbol]
              after_update line
              OpenChain::FieldLogicValidator.validate! line
              o.create_snapshot if o.respond_to?('create_snapshot')
              add_flash :notices, "Line updated sucessfully."
              good = true
            end
          end
        rescue OpenChain::ValidationLogicError 

        end
        if good
          format.html { redirect_to(o) }
          format.xml  { head :ok }
        else
          errors_to_flash line
          set_products_variable o
          format.html { redirect_to edit_line_path(o,line) }
          format.xml  { render :xml => @line.errors, :status => :unprocessable_entity }
        end
      end
		}
	end

#callbacks
  def after_update line
    #empty - holder for callbacks in subclasses
  end

  def before_save line
    true
  end
end
