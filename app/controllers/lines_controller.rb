class LinesController < ApplicationController

  #if you want to use this don't forget to add "post :create_multiple, :on => :collection" to the appropriate resource route
  def create_multiple
    o = find_parent
    action_secure(o.can_edit?(current_user),o,{:verb=>"create lines for",:module_name=>module_name}) {
      line = nil
      begin
        Lock.with_lock_retry(o) do 
          params[:lines].each do |p|
            line = child_objects(o).build
            valid = line.assign_model_field_attributes p[1]
            raise OpenChain::ValidationLogicError unless valid
            line.save if before_save(line, p[1])
            OpenChain::FieldLogicValidator.validate! line

            line.piece_sets.create(:quantity=>line.quantity,:milestone_plan_id=>p[1][:milestone_plan_id]) if p[1][:milestone_plan_id]
            line.piece_sets.each {|p| p.create_forecasts}
          end
        end

        o.create_async_snapshot if o.respond_to?('create_snapshot')
      rescue OpenChain::ValidationLogicError
        errors_to_flash line unless line.nil?
      end
      redirect_to o
    }
  end

	def create
		o = find_parent
		action_secure(o.can_edit?(current_user),o,{:verb=>"create lines for",:module_name=>module_name}) {
      begin
        line = child_objects(o).build
        valid = line.assign_model_field_attributes params[update_symbol], exclude_blank_values: true
        raise OpenChain::ValidationLogicError unless valid
        Lock.with_lock_retry(o) do 
          if before_save(line, params[update_symbol])
            line.save!
            OpenChain::FieldLogicValidator.validate! line
            line.piece_sets.create(:quantity=>line.quantity,:milestone_plan_id=>params[:milestone_plan_id]) if params[:milestone_plan_id]
            line.piece_sets.each {|p| p.create_forecasts}
          end
        end

        o.update_attributes(:last_updated_by_id=>current_user.id) if o.respond_to?(:last_updated_by_id)
        o.create_async_snapshot if o.respond_to?('create_snapshot')
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
      o.create_async_snapshot if o.respond_to?('create_snapshot')
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
      good = false
      line = find_line
      begin
        Lock.with_lock_retry(line) do
          valid = line.assign_model_field_attributes params[update_symbol]
          raise OpenChain::ValidationLogicError unless valid
          if before_save(line, params[update_symbol]) 
            line.save!
            after_update line
            OpenChain::FieldLogicValidator.validate! line
            line.piece_sets.each {|p| p.create_forecasts}
            
            add_flash :notices, "Line updated sucessfully."
            good = true
          end
        end
        o.create_async_snapshot if o.respond_to?('create_snapshot')
      rescue OpenChain::ValidationLogicError 
        errors_to_flash line
      end

      good ? redirect_to(o) : redirect_to(edit_line_path(o,line))
		}
	end

#callbacks
  def after_update line
    #empty - holder for callbacks in subclasses
  end

  def before_save line, line_params
    true
  end
end
