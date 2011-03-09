class SalesOrderLinesController < ApplicationController
  def create
    o = SalesOrder.find(params[:sales_order_id])
    action_secure(o.can_edit?(current_user),o,{:verb=>"create lines for",:module_name=>"sales order"}) {
      @sales_order = o
      @sales_order_line = @sales_order.sales_order_lines.build(params[:sales_order_line])
      @sales_order_line.set_line_number
      unless @sales_order_line.save
        @sales_order_line.make_unshipped_remainder_piece_set.save
        errors_to_flash @sales_order_line, :now => true
        render 'sales_orders/show'
      else
        redirect_to sales_order_path(@sales_order)
      end     
    }
  end
  
  def destroy
    o = SalesOrder.find(params[:sales_order_id])
    action_secure(o.can_edit?(current_user),o,{:verb=>"delete lines for",:module_name=>"sales order"}) {
      @sales_order = o      
      line = SalesOrderLine.find(params[:id])
      line.destroy
      errors_to_flash line
      redirect_to sales_order_path(@sales_order)
    }
  end
  
  def edit
    o = SalesOrder.find(params[:sales_order_id])
    action_secure(o.can_edit?(current_user),o,{:verb=>"edit lines for",:module_name=>"sales order"}) {
      @sales_order = o
      @sales_order_line = SalesOrderLine.find(params[:id])
      render 'sales_orders/show'
    }
  end
  
  def update
    o = SalesOrder.find(params[:sales_order_id])
    action_secure(o.can_edit?(current_user),o,{:verb=>"edit lines for",:module_name=>"sales order"}) {
      @sales_order = o
      @sales_order_line = SalesOrderLine.find(params[:id]) 
      respond_to do |format|
        if @sales_order_line.update_attributes(params[:sales_order_line])
          if @sales_order_line.line_number.nil? || @sales_order_line.line_number < 1
            @sales_order_line.set_line_number
            @sales_order_line.save
          end
          @sales_order_line.make_unshipped_remainder_piece_set.save
          add_flash :notices, "Line updated sucessfully."
          format.html { redirect_to(@sales_order) }
          format.xml  { head :ok }
        else
          errors_to_flash @order_line
          @products = Product.where(["vendor_id = ?",@order.vendor])
          format.html { redirect_to edit_sales_order_sales_order_line_path(@sales_order,@sales_order_line) }
          format.xml  { render :xml => @sales_order_line.errors, :status => :unprocessable_entity }
        end
      end
    }
  end
end
