require 'test_helper'

class LinesSupportTest < ActiveSupport::TestCase

  test "worst milestone state" do
    oline = OrderLine.new
    assert_nil oline.worst_milestone_state

    ps_nil = oline.piece_sets.build
    ps_nil.stubs(:milestone_state).returns(nil)
    assert_nil oline.worst_milestone_state
    
    MilestoneForecast::ORDERED_STATES.each do |s|
      oline.piece_sets.build.stubs(:milestone_state).returns(s)
      assert_equal s, oline.worst_milestone_state
    end
  end

  test "linked piece sets" do
    original_qty = 50
    sline = Shipment.first.shipment_lines.create!(:line_number=>1000,:quantity=>original_qty,:product_id=>Shipment.first.vendor.vendor_products.first)
    #create initial piece sets
    oline = Order.first.order_lines.create!(:product_id=>sline.product_id)
    oline.piece_sets.create!(:quantity=>original_qty+10) #piece set should get split into two
    soline = SalesOrder.first.sales_order_lines.create!(:product_id=>sline.product_id)
    dline = Delivery.first.delivery_lines.create!(:product_id=>sline.product_id)
    sline.linked_order_line_id = oline.id
    sline.linked_sales_order_line_id = soline.id
    sline.linked_delivery_line_id = dline.id
    sline.save!
    sline.reload
    psets = sline.piece_sets
    assert psets.size==3, "Should have created 3 associated piece sets."
    assert psets.where(:order_line_id=>oline.id,:quantity=>original_qty).size==1, "Should have found one piece set for order & qty."
    assert psets.where(:sales_order_line_id=>soline.id,:quantity=>original_qty).size==1, "Should have found one piece set for sales order & qty."
    assert psets.where(:delivery_line_id=>dline.id,:quantity=>original_qty).size==1, "Should have found one piece set for delivery & qty."

    oline_psets = PieceSet.where(:order_line_id=>oline.id)
    assert_equal 2, oline_psets.size
    assert PieceSet.where(:order_line_id=>oline.id,:shipment_line_id=>sline.id,:quantity=>original_qty).first
    assert PieceSet.where(:order_line_id=>oline.id,:shipment_line_id=>nil,:quantity=>10).first

    qty2 = original_qty + 10
    sline2 = ShipmentLine.find(sline.id) #fresh object without attributes set
    sline2.quantity = qty2
    sline2.save!
    #should not have changed piece set quantity because we didn't set the attributes
    assert sline2.quantity = qty2, "Should have set qty"
    psets = sline2.piece_sets
    assert psets.size==3, "Should have created 3 associated piece sets."
    assert psets.where(:order_line_id=>oline.id,:quantity=>original_qty).size==1, "Should have found one piece set for order & qty."
    assert psets.where(:sales_order_line_id=>soline.id,:quantity=>original_qty).size==1, "Should have found one piece set for sales order & qty."
    assert psets.where(:delivery_line_id=>dline.id,:quantity=>original_qty).size==1, "Should have found one piece set for delivery & qty."
    
    #setting attributes and resaving
    sline2.linked_order_line_id = oline.id
    sline2.linked_sales_order_line_id = soline.id
    sline2.linked_delivery_line_id = dline.id
    sline2.save!
    sline2.reload
    psets = sline2.piece_sets
    #since we set the attributes, this save should have updated the existing objects' quantities
    assert psets.size==3, "Should have created 3 associated piece sets."
    assert psets.where(:order_line_id=>oline.id,:quantity=>qty2).size==1, "Should have found one piece set for order & qty."
    assert psets.where(:sales_order_line_id=>soline.id,:quantity=>qty2).size==1, "Should have found one piece set for sales order & qty."
    assert psets.where(:delivery_line_id=>dline.id,:quantity=>qty2).size==1, "Should have found one piece set for delivery & qty."

    #setting attribute to a different order line which should create a new object on save
    qty3 = 999
    sline3 = ShipmentLine.find(sline.id) #fresh object
    oline2 = Order.first.order_lines.create!(:line_number=>10050,:quantity=>1,:product_id=>sline3.product_id)
    sline3.linked_order_line_id = oline2.id
    sline3.quantity = qty3
    sline3.save!
    sline3.reload
    psets = sline3.piece_sets
    assert psets.size==4, "Should have 4 piece sets (2 order lines)"
    assert psets.where(:order_line_id=>oline.id,:quantity=>qty2).size==1, "Should have found one piece set for order & qty."
    assert psets.where(:sales_order_line_id=>soline.id,:quantity=>qty2).size==1, "Should have found one piece set for sales order & qty."
    assert psets.where(:delivery_line_id=>dline.id,:quantity=>qty2).size==1, "Should have found one piece set for delivery & qty."
    assert psets.where(:order_line_id=>oline2.id,:quantity=>qty3).size==1, "Should have found one piece set for newly linked order & qty."
  end
end
