class OrderLinesController < ApplicationController

	def create
		o = Order.find(params[:order_id])
		action_secure(o.can_edit?(current_user),o,{:verb=>"create lines for",:module_name=>"order"}) {
  		order_line = o.order_lines.build(params[:order_line])
      order_line.set_line_number
  		if order_line.save 
  		  update_custom_fields order_line, params[:orderline_cf]
  		end
		  errors_to_flash order_line
		  redirect_to order_path(o)
		}
	end
	
	def destroy
		o = Order.find(params[:order_id])
		action_secure(o.can_edit?(current_user),o,{:verb=>"delete lines for",:module_name=>"order"}) {
      @order = o		  
  		@line = OrderLine.find(params[:id])
  		@line.destroy
  		errors_to_flash @line
  		redirect_to order_path(@order)
		}
	end
	
	def edit
		o = Order.find(params[:order_id])
	  action_secure(o.can_edit?(current_user),o,{:verb=>"edit lines for",:module_name=>"order"}) {
	    @order = o
      @order_line = OrderLine.find(params[:id])
  		@products = Product.where(["vendor_id = ?",@order.vendor])
  		render 'orders/show'
    }
	end
	
	def update
		o = Order.find(params[:order_id])
		action_secure(o.can_edit?(current_user),o,{:verb=>"edit lines for",:module_name=>"order"}) {
		  @order = o
      @order_line = OrderLine.find(params[:id]) 
      respond_to do |format|
        if @order_line.update_attributes(params[:order_line])
          if @order_line.line_number.nil? || @order_line.line_number < 1
            @order_line.set_line_number
            @order_line.save
          end
          update_custom_fields @order_line, params[:orderline_cf]
          add_flash :notices, "Line updated sucessfully."
          format.html { redirect_to(@order) }
          format.xml  { head :ok }
        else
          errors_to_flash @order_line
  				@products = Product.where(["vendor_id = ?",@order.vendor])
          format.html { redirect_to edit_order_order_line_path(@order,@order_line) }
          format.xml  { render :xml => @order_line.errors, :status => :unprocessable_entity }
        end
      end
		}
	end
end
