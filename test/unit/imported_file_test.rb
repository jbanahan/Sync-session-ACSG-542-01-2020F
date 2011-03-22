require 'test_helper'

class ImportedFileTest < ActiveSupport::TestCase
  test "process" do
    base_order = Order.find(1)
    new_order_date = "2001-01-03"
    attachment = "Order Number,Order Date\n#{base_order.order_number},#{new_order_date}"
    ImportedFile.find(1).process({:attachment_data => attachment})
    assert Order.find(1).order_date==Date.new(2001,1,3), "Order Date was not updated."
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
    new_order_date = "2001-01-03"
    attachment = "Order Number,Order Date\n#{base_order.order_number},#{new_order_date}"
    r = ImportedFile.find(1).preview({:attachment_data => attachment})
    assert r.length == 2, "Should have returned two results, returned #{r.length}"
    assert r.include?("#{ModelField.find_by_uid(:ord_ord_num).label} set to #{base_order.order_number}"), "Messages didn't include order number.  All messages #{r.to_s}"
    assert r.include? "#{ModelField.find_by_uid(:ord_ord_date).label} set to #{new_order_date}"
  end

  test "cannot change vendor via upload" do
    base_order = Order.find(1)
    new_vendor = base_order.vendor_id + 1
    attachment = "Order Number,Vendor\n#{base_order.order_number},#{new_vendor}"
    ic = SearchSetup.new(:module_type => "Order", :name => "test", :user_id => users(:masteruser))
    ic.save!
    ic.search_columns.create(:model_field_uid => "ord_ord_num", :rank => 0)
    ic.search_columns.create(:model_field_uid => "ord_ven_id", :rank => 1)
    f = ImportedFile.new(:filename => 'fname', :size => 1, :content_type => 'text/csv', :search_setup_id => ic.id, :ignore_first_row => true)
    f.save!
    assert !f.process({:attachment_data => attachment}), "Process passed and should have failed."
    assert f.errors[:base].include?("Row 2: An order's vendor cannot be changed via a file upload."), "Did not find vendor error message."
  end
  
  test "record with empty details only creates header" do
    ic = SearchSetup.new(:module_type => "Order", :name => "test", :user_id => users(:masteruser))
    ic.save!
    ic.search_columns.create(:model_field_uid => "ord_ord_num", :rank => 0)
    ic.search_columns.create(:model_field_uid => "ord_ven_id", :rank => 1)
    ic.search_columns.create(:model_field_uid => "ordln_puid", :rank => 2)
    ic.search_columns.create(:model_field_uid => "ordln_ordered_qty", :rank => 3)
    f = ImportedFile.new(:filename => 'fname', :size => 1, :content_type => 'text/csv', :search_setup_id => ic.id, :ignore_first_row => false)
    f.save!
    order_number = "r_e_d_o_c_h"
    attachment = "#{order_number},2,\"\",\"\""
    assert f.process({:attachment_data => attachment}), "Imported File did not process successfully: #{f.errors.to_s}"
    found = Order.where(:order_number => order_number).first
    assert found.id > 0, "Should have found order that was saved."
    assert found.order_lines.size == 0, "Should not have saved a detail."
  end
  
  test "all order fields" do
    vh = {:order_number => "ord_all_ord_fields",
      :order_date => Time.utc(2008,5,5),
      :vendor_id => 2,
      :puid => "prod_1",
      :ordered_qty => 55,
      :price_per_unit => 27.2,
      }
    ic = SearchSetup.new(:module_type => "Order", :name => "test", :user_id => users(:masteruser))
    ic.save!
    attachment_vals = [vh[:order_number],vh[:order_date],vh[:vendor_id],vh[:puid],vh[:ordered_qty],vh[:price_per_unit]]
    [:ord_ord_num,:ord_ord_date,:ord_ven_id,:ordln_puid,:ordln_ordered_qty,:ordln_ppu].each_with_index do |u,i|
      mf = ModelField.find_by_uid u
      ic.search_columns.create!(:model_field_uid => mf.uid, :rank => i)
    end
    attachment = attachment_vals.to_csv
    f = ImportedFile.new(:filename => 'fname', :size => 1, :content_type => 'text/csv', :search_setup_id => ic.id, :ignore_first_row=>false)
    assert f.process(:attachment_data => attachment), "Imported File did not process successfully: #{f.errors.to_s}"
    found = Order.where(:order_number => vh[:order_number]).first
    assert found.order_date.yday == vh[:order_date].yday, "Order date failed"
    assert found.vendor_id == vh[:vendor_id], "vendor id failed"
    fd = found.order_lines.first
    assert fd.product.unique_identifier == vh[:puid], "product uid failed"
    assert fd.quantity == vh[:ordered_qty], "ordered qty failed"
    assert fd.price_per_unit == vh[:price_per_unit], "Price per unit failed.  Was #{fd.price_per_unit}, should be #{vh[:price_per_unit]}"
  end
  
  test "all product fields (including a blank)" do
    vh = {
      :unique_identifier => Time.new.to_s,
      :name => "nm",
      :vendor_id => Company.where(:vendor=>true).first.id,
      :div_id => Division.first.id,
      :vendor_name => Company.where(:vendor=>true).first.name
    }
    ss = SearchSetup.new(:module_type => "Product", :name => "test", :user_id => users(:masteruser))
    ss.save!
    attachment_vals = [vh[:unique_identifier],vh[:div_id],vh[:name],vh[:vendor_id],vh[:vendor_name]]
    [:prod_uid,:prod_div_id,:prod_name,:prod_ven_id,:prod_ven_name].each_with_index do |u,i|
      mf = ModelField.find_by_uid u
      ss.search_columns.create!(:model_field_uid => mf.uid, :rank => i)
    end
    ss.search_columns.create!(:model_field_uid => "_blank", :rank=>1000) #testing a blank column
    attachment = attachment_vals.to_csv
    f = ImportedFile.new(:filename => 'fname', :size => 1, :content_type => 'text/csv', :search_setup_id => ss.id, :ignore_first_row=>false)
    assert f.process(:attachment_data => attachment), "Imported File did not process successfully: #{f.errors.to_s}"
    found = Product.where(:unique_identifier => vh[:unique_identifier]).first
    assert found.name == vh[:name], "name failed"
    assert found.vendor_id == vh[:vendor_id], "vendor id failed"
    assert found.division_id == vh[:div_id], "division id failed"
  end

  test "product with classification and tariffs" do
    vh = {
      :prod_uid=>"pwc_test",
      :prod_ven_id=>companies(:vendor).id,
      :class_cntry_iso => "US",
      :hts_line_number => "",
      :hts_hts_1 => "9900778811"
    }
    ss = SearchSetup.create!(:module_type=>"Product",:name=>"test", :user_id=> users(:masteruser).id)
    attach_array = []
    [:prod_uid,:prod_ven_id,:class_cntry_iso,:hts_line_number,:hts_hts_1].each_with_index do |uid,i|
      attach_array << vh[uid]
      ss.search_columns.create!(:model_field_uid => uid,:rank=>i)
    end
    f = ss.imported_files.new(:filename=>'fname',:size=>1,:content_type => 'text/csv',:ignore_first_row=>false)
    assert f.process(:attachment_data => attach_array.to_csv), "Imported File did not process successfully: #{f.errors.to_s}"
    found = Product.where(:unique_identifier => vh[:prod_uid]).first
    assert found.vendor_id == vh[:prod_ven_id], "vendor id failed"
    classifications = found.classifications
    assert classifications.size==1, "Should have found 1 classification, found #{found.classifications.size}"
    assert classifications.first.country.iso_code=="US", "Classification should be for US, was #{found.classifications.first.country.iso_code}"

    tariffs = classifications.first.tariff_records
    assert tariffs.size==1, "Should have found 1 tariff, found #{tariffs.size}"
    assert tariffs.first.line_number==1, "Should have auto-set line number to 1, was #{tariffs.first.line_number}"
    assert tariffs.first.hts_1==vh[:hts_hts_1], "Should have set hts-1 to #{vh[:hts_hts_1]}, was #{tariffs.first.hts_1}"

    #change HTS number and reprocess
    vh[:hts_hts_1] = "1234567890"
    vh[:hts_line_number] = tariffs.first.line_number
    attach_array.pop 2
    attach_array << vh[:hts_line_number]
    attach_array << vh[:hts_hts_1]
    assert f.process(:attachment_data => attach_array.to_csv), "Imported File did not process successfully: #{f.errors.to_s}"
    p2 = Product.where(:unique_identifier => vh[:prod_uid]).first
    assert p2 == found, "Should have found same object in database."
    assert p2.classifications.size==1, "Should still have 1 element."
    assert p2.classifications.first==classifications.first, "Should have found same classification"
    c2 = p2.classifications.first
    assert c2.tariff_records.size==1, "Should still have 1 element."
    t2 = c2.tariff_records.first
    assert t2 == tariffs.first, "Should have found same tariff record"
    assert t2.hts_1 == vh[:hts_hts_1], "HTS should have been #{vh[:hts_hts_1]}, was #{t2.hts_1}"
  end
end
