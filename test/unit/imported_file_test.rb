require 'test_helper'

class ImportedFileTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "process" do
    base_order = Order.find(1)
    new_buyer = base_order.buyer + "bx"
    attachment = "Order Number,Buyer\n#{base_order.order_number},#{new_buyer}"
    ImportedFile.find(1).process({:attachment_data => attachment})
    assert Order.find(1).buyer==new_buyer, "Buyer was not updated."
  end
  
  test "process order with product detail" do
    base_prod = Product.find(1)
    base_order = Order.find(2)
    attachment = "#{base_order.order_number},#{base_prod.unique_identifier}"
    ImportedFile.find(2).process({:attachment_data => attachment})
    assert Order.find(2).order_lines.first.product_id == base_prod.id, "Product was not id #{base_prod.id}"
  end

  test "preview order" do
    base_order = Order.find(1)
    new_buyer = base_order.buyer + "bx"
    attachment = "Order Number,Buyer\n#{base_order.order_number},#{new_buyer}"
    r = ImportedFile.find(1).preview({:attachment_data => attachment})
    assert r.length == 2, "Should have returned two results, returned #{r.length}"
    assert r.include? "#{ImportConfig.find_model_field(:order,:order_number).label} set to #{base_order.order_number}"
    assert r.include? "#{ImportConfig.find_model_field(:order,:buyer).label} set to #{new_buyer}"
  end

  test "cannot change vendor via upload" do
    base_order = Order.find(1)
    new_vendor = base_order.vendor_id + 1
    attachment = "Order Number,Vendor\n#{base_order.order_number},#{new_vendor}"
    ic = ImportConfig.new(:model_type => "order", :file_type => "csv", :ignore_first_row => true, :name => "test")
    ic.save!
    ic.import_config_mappings.create(:model_field_uid => ImportConfig.find_model_field(:order,:order_number).uid, :column => 1)
    ic.import_config_mappings.create(:model_field_uid => ImportConfig.find_model_field(:order,:vendor_id).uid, :column => 2)
    f = ImportedFile.new(:filename => 'fname', :size => 1, :content_type => 'text/csv', :import_config_id => ic.id)
    f.save!
    assert !f.process({:attachment_data => attachment}), "Process passed and should have failed."
    assert f.errors[:base].include?("Row 2: An order's vendor cannot be changed via a file upload."), "Did not find vendor error message."
  end
  
  test "record with empty details only creates header" do
    ic = ImportConfig.new(:model_type => "order", :file_type => "csv", :ignore_first_row => false, :name => "test")
    ic.save!
    ic.import_config_mappings.create(:model_field_uid => ImportConfig.find_model_field(:order,:order_number).uid, :column => 1)
    ic.import_config_mappings.create(:model_field_uid => ImportConfig.find_model_field(:order,:vendor_id).uid, :column => 2)
    ic.import_config_mappings.create(:model_field_uid => ImportConfig.find_model_field(:order,:product_unique_identifier).uid, :column => 3)
    ic.import_config_mappings.create(:model_field_uid => ImportConfig.find_model_field(:order,:ordered_qty).uid, :column => 4)
    f = ImportedFile.new(:filename => 'fname', :size => 1, :content_type => 'text/csv', :import_config_id => ic.id)
    f.save!
    order_number = "r_e_d_o_c_h"
    attachment = "#{order_number},2,\"\",\"\""
    assert f.process({:attachment_data => attachment}), "Should have processed."
    found = Order.where(:order_number => order_number).first
    assert found.id > 0, "Should have found order that was saved."
    assert found.order_lines.size == 0, "Should not have saved a detail."
  end
  
  test "all order fields" do
    vh = {:order_number => "ord_all_ord_fields",
      :order_date => Time.utc(2008,5,5),
      :buyer => "buyer",
      :season => "season1",
      :vendor_id => 2,
      :product_unique_identifier => "prod_1",
      :ordered_qty => 55,
      :unit_of_measure => "UOM",
      :price_per_unit => 27.2,
      :expected_ship_date => Time.utc(2008,7,4),
      :expected_delivery_date => Time.utc(2008,9,14),
      :ship_no_later_date => Time.utc(2008,8,2)
      }
    ic = ImportConfig.new(:model_type => "order", :file_type => "csv", :ignore_first_row => false, :name => "test")
    ic.save!
    attachment_vals = []
    vh.each_with_index do |k,i|
      mf = ImportConfig.find_model_field(:order,k[0])
      ic.import_config_mappings.create(:model_field_uid => mf.uid, :column => i+1)
      attachment_vals << k[1]
    end
    attachment = attachment_vals.to_csv
    f = ImportedFile.new(:filename => 'fname', :size => 1, :content_type => 'text/csv', :import_config_id => ic.id)
    assert f.process(:attachment_data => attachment), "Imported File did not process successfully: #{f.errors.to_s}"
    found = Order.where(:order_number => vh[:order_number]).first
    assert found.buyer == vh[:buyer], "Buyer failed"
    assert found.season == vh[:season], "season failed"
    assert found.order_date.yday == vh[:order_date].yday, "Order date failed"
    assert found.vendor_id == vh[:vendor_id], "vendor id failed"
    fd = found.order_lines.first
    assert fd.product.unique_identifier == vh[:product_unique_identifier], "product uid failed"
    assert fd.ordered_qty == vh[:ordered_qty], "ordered qty failed"
    assert fd.unit_of_measure == vh[:unit_of_measure], "uom failed"
    assert fd.price_per_unit == vh[:price_per_unit], "ppu failed"
    assert fd.expected_ship_date.yday == vh[:expected_ship_date].yday, "exp ship date failed"
    assert fd.expected_delivery_date.yday == vh[:expected_delivery_date].yday, "exp delivery date failed"
    assert fd.ship_no_later_date.yday == vh[:ship_no_later_date].yday, "ship no later failed"
  end
  
  test "all product fields" do
    vh = {
      :unique_identifier => Time.new.to_s,
      :part_number => "pnum",
      :name => "nm",
      :description => "desc",
      :vendor_id => 2
    }
    ic = ImportConfig.new(:model_type => "product", :file_type => "csv", :ignore_first_row => false, :name => "test")
    ic.save!
    attachment_vals = []
    vh.each_with_index do |k,i|
      mf = ImportConfig.find_model_field(:product,k[0])
      ic.import_config_mappings.create(:model_field_uid => mf.uid, :column => i+1)
      attachment_vals << k[1]
    end
    attachment = attachment_vals.to_csv
    f = ImportedFile.new(:filename => 'fname', :size => 1, :content_type => 'text/csv', :import_config_id => ic.id)
    assert f.process(:attachment_data => attachment), "Imported File did not process successfully: #{f.errors.to_s}"
    found = Product.where(:unique_identifier => vh[:unique_identifier]).first
    assert found.part_number == vh[:part_number], "part number failed"
    assert found.name == vh[:name], "name failed"
    assert found.description == vh[:description], "description failed"
    assert found.vendor_id == vh[:vendor_id], "vendor id failed"
  end
end
