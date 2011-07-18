require 'test_helper'

class CoreModuleTest < ActiveSupport::TestCase

  test "object from piece set" do
    o = Order.create!(:order_number=>"1234",:vendor_id=>companies(:vendor).id)
    o_line = o.order_lines.create!(:product_id=>Product.where(:vendor_id=>o.vendor_id).first,:quantity=>40)
    s = Shipment.create!(:reference=>"sr",:vendor_id=>o.vendor_id)
    s_line = s.shipment_lines.create!(:product_id=>o_line.product_id,:quantity=>40)
    so = SalesOrder.create!(:order_number=>"1515",:customer_id=>companies(:customer6).id)
    so_line = so.sales_order_lines.create!(:product_id=>o_line.product_id,:quantity=>40)
    d = Delivery.create!(:reference=>"dl",:customer_id=>so.customer_id)
    d_line = d.delivery_lines.create!(:line_number=>1,:product_id=>o_line.product_id,:quantity=>40)

    ps = PieceSet.create!(:order_line_id=>o_line.id,:shipment_line_id=>s_line.id,:sales_order_line_id=>so_line.id,:delivery_line_id=>d_line.id,:quantity=>40)

    assert_equal o, CoreModule::ORDER.object_from_piece_set(ps)
    assert_equal o_line, CoreModule::ORDER_LINE.object_from_piece_set(ps)
    assert_equal s, CoreModule::SHIPMENT.object_from_piece_set(ps)
    assert_equal s_line, CoreModule::SHIPMENT_LINE.object_from_piece_set(ps)
    assert_equal so, CoreModule::SALE.object_from_piece_set(ps)
    assert_equal so_line, CoreModule::SALE_LINE.object_from_piece_set(ps)
    assert_equal d, CoreModule::DELIVERY.object_from_piece_set(ps)
    assert_equal d_line, CoreModule::DELIVERY_LINE.object_from_piece_set(ps)
  end

  test "touch parent updated - CUSTOM VALUE" do
    cd = CustomDefinition.create!(:module_type=>"Product",:label=>"tpucv",:data_type=>:integer)
    p = Product.create!(:unique_identifier=>"tpucv")
    ActiveRecord::Base.connection.execute("UPDATE products set changed_at = null WHERE id = #{p.id}") #reset in DB without hitting other callbacks
    p.reload
    assert p.changed_at.nil?
    cv = p.get_custom_value cd
    cv.value = 123
    cv.save!
    p.reload
    assert p.changed_at > 1.second.ago
  end

  test "touch parent update - PRODUCT" do 
    p = Product.create!(:unique_identifier=>"tpup")
    p.reload
    assert p.changed_at > 1.second.ago
    ActiveRecord::Base.connection.execute("UPDATE products set changed_at = null WHERE id = #{p.id}") #reset in DB without hitting other callbacks
    p.reload
    assert p.changed_at.nil?
    p.name= "123"
    p.save!
    assert p.changed_at > 1.second.ago
  end

  test "touch parent update - CLASSIFICATION" do
    p = Product.create!(:unique_identifier=>"tpu")
    ActiveRecord::Base.connection.execute("UPDATE products set changed_at = null WHERE id = #{p.id}") #reset in DB without hitting other callbacks
    p = p.reload 
    assert p.changed_at.nil?
    c = p.classifications.create!(:country_id=>Country.first.id)
    p = p.reload #reload from db to make sure changed_at was saved
    time = p.changed_at
    assert time > 1.second.ago
  end

  test "touch parent updated - TARIFF_RECORD" do
    p = Product.create!(:unique_identifier=>"tpu")
    c = p.classifications.create!(:country_id=>Country.first.id)
    ActiveRecord::Base.connection.execute("UPDATE products set changed_at = null WHERE id = #{p.id}") #reset in DB without hitting other callbacks
    p = Product.find p.id
    assert p.changed_at.nil?
    t = c.tariff_records.create!
    p = Product.find p.id #reload from db to make sure changed_at was saved
    time = p.changed_at
    assert time > 2.seconds.ago
    t.save!
    new_time = p.changed_at
    assert time==new_time, "Updating within 1 minute shouldn't change time, old time: #{time}, new time: #{new_time}"
  end

  test "find" do 
    p = Product.create!(:unique_identifier=>"cm_find")
    found = CoreModule::PRODUCT.find p.id
    assert found==p

    o = Order.create!(:order_number=>"cm_find", :vendor_id=>companies(:vendor).id)
    found = CoreModule::ORDER.find o.id
    assert found == o
  end

  test "find statusable" do
    expected_count = 1
    cms = CoreModule.find_statusable
    assert cms.length == expected_count, "Should have returned #{expected_count} core modules, returned #{cms.length}"
    assert cms.include?(CoreModule::PRODUCT)
  end
  
  test "find file_formatable" do
    expected_count = 2
    cms = CoreModule.find_file_formatable
    assert cms.length == expected_count, "Should have return #{expected_count} core modules, returned #{cms.length}"
    assert cms.include?(CoreModule::PRODUCT)
    assert cms.include?(CoreModule::ORDER) 
  end
  
  test "to_a_label_class with block" do
    expected_count = 2
    cms = CoreModule.to_a_label_class {|c| c.class_name[0,5]=="Order"}
    assert cms.length == expected_count, "Should have return #{expected_count} core modules, returned #{cms.length}"
    assert cms.include?([CoreModule::ORDER_LINE.label,CoreModule::ORDER_LINE.class_name])
    assert cms.include?([CoreModule::ORDER.label,CoreModule::ORDER.class_name])
  end
  
  test "to_a_label_class without block" do
    expected_count = CoreModule::CORE_MODULES.length
    cms = CoreModule.to_a_label_class
    assert cms.length == expected_count, "Should have returned #{expected_count}, returned #{cms.length}"
    assert cms.include?([CoreModule::ORDER.label,CoreModule::ORDER.class_name])
  end
  
  test "new object" do
    CoreModule::CORE_MODULES.each do |cm|
      o = cm.new_object
      assert o.class.to_s == cm.class_name.to_s, "Created #{o.class.to_s}, expected #{cm.class_name.to_s}"
    end
  end

  test "module_level" do
    product = CoreModule::PRODUCT
    assert product.module_level(CoreModule::PRODUCT)==0, "Same level should equal 0, was #{product.module_level(CoreModule::PRODUCT)}"
    assert product.module_level(CoreModule::CLASSIFICATION)==1, "Classification should be 1, was #{product.module_level(CoreModule::CLASSIFICATION)}"
    assert product.module_level(CoreModule::TARIFF)==2, "Tariff should be 2, was #{product.module_level(CoreModule::TARIFF)}"
    assert product.module_level(CoreModule::ORDER).nil?, "Order should be nil because it's not in the child tree."
  end
end
