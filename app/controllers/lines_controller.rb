class LinesController < ApplicationController

	def create
		o = find_parent
		action_secure(o.can_edit?(current_user),o,{:verb=>"create lines for",:module_name=>module_name}) {
  		order_line = child_objects(o).build(params[update_symbol])
  		if order_line.save 
  		  update_custom_fields order_line, params[update_custom_field_symbol]
  		end
		  errors_to_flash order_line
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
      @line = find_line 
      respond_to do |format|
        if @line.update_attributes(params[update_symbol])
          update_custom_fields @line, params[update_custom_field_symbol]
          add_flash :notices, "Line updated sucessfully."
          format.html { redirect_to(o) }
          format.xml  { head :ok }
        else
          errors_to_flash @line
          set_products_variable o
          format.html { redirect_to edit_line_path(o,@line) }
          format.xml  { render :xml => @line.errors, :status => :unprocessable_entity }
        end
      end
		}
	end
end
