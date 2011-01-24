class PieceSetsController < ApplicationController

	def create
		ps = PieceSet.new(params[:piece_set])
		ps.save
		update_unshipped(ps)
    errors_to_flash ps
		redirect_to do_route(ps)
	end

  def destroy
    ps = PieceSet.find(params[:id])
    o_lines = [ps.order_line, ps.sales_order_line]
    ps.destroy
    o_lines.each {|o| o.make_unshipped_remainder_piece_set.save unless o.nil?}
    errors_to_flash ps
    redirect_to do_route(ps)
  end
  
  def edit
    @ps_to_edit = PieceSet.find(params[:id])
    @shipment = @ps_to_edit.shipment
    @delivery = @ps_to_edit.delivery
    render do_route(@ps_to_edit, :render)
    #render 'shipments/show'
  end
  
  def update
    ps = PieceSet.find(params[:id])

    respond_to do |format|
      if ps.update_attributes(params[:piece_set])
        update_unshipped ps
        errors_to_flash ps
        format.html { redirect_to do_route(ps) }
        format.xml  { head :ok }
      else
        errors_to_flash ps
        format.html { redirect_to edit_piece_set_path(ps) }
        format.xml  { render :xml => ps.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  private
  FROM_ROUTES = {
    :s => {
      :redirect => lambda {|help,ps| help.shipment_path(ps.shipment)},
      :render => lambda {|help,ps|
        'shipments/show'
      }
    },
    :d => {
      :redirect => lambda {|help,ps| help.delivery_path(ps.delivery)},
      :render => lambda {|help,ps|
        'deliveries/show'
      }
    }
  }
  
  def do_route(ps,type=:redirect)
    from_loc = params[:from]
    from_loc = "s" if from_loc.nil?
    FROM_ROUTES[from_loc.intern][type].call(self,ps)
  end
  
  def update_unshipped(piece_set)
    piece_set.order_line.make_unshipped_remainder_piece_set.save unless piece_set.order_line.nil?
    piece_set.sales_order_line.make_unshipped_remainder_piece_set.save unless piece_set.sales_order_line.nil?
  end
end
