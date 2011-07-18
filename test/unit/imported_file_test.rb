require 'test_helper'

class ImportedFileTest < ActiveSupport::TestCase

  def setup
    ModelField.reload
  end

  test "add with two details" do

    cn_ot = OfficialTariff.create!(:country_id=>countries(:china).id,:hts_code=>"1234567890",:full_description=>"fd")
    us_ot = OfficialTariff.create!(:country_id=>countries(:us).id,:hts_code=>"09876543210",:full_description=>"DF")

    u = users(:masteruser)
    ss = SearchSetup.create!(:update_mode=>"add",:module_type=>"Product",:name=>"addo",:user_id=>u.id)
    ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>0)
    ss.search_columns.create!(:model_field_uid=>:prod_name,:rank=>1)
    ss.search_columns.create!(:model_field_uid=>:class_cntry_iso,:rank=>2)
    ss.search_columns.create!(:model_field_uid=>:hts_line_number,:rank=>3)
    ss.search_columns.create!(:model_field_uid=>:hts_hts_1,:rank=>4)

    existing_product = Product.create!(:unique_identifier=>"addonlyprod",:name=>"base name")
    new_product_uid = "newproductuid"

    #first line should be rejected, 2nd & 3rd lines should create 1 product w/ two classifications
    data = "#{existing_product.unique_identifier},pname,US,1,6101200021\n#{new_product_uid},pname2,CN,1,#{cn_ot.hts_code}\n#{new_product_uid},pname2,US,1,#{us_ot.hts_code}"

    i = ss.imported_files.create!(:module_type=>"Product",:ignore_first_row=>false,:attached_file_name=>"fname.csv")
    i.process(u,:attachment_data=>data)

    assert_equal existing_product.name, Product.find(existing_product.id).name #first product should not have been updated
    found = Product.where(:unique_identifier=>new_product_uid).first #second product should have been added
    assert_equal 2, found.classifications.size

    assert_equal ["CN","US"], (found.classifications.collect {|c| c.country.iso_code}).sort
    
    change_records = i.file_import_results.first.change_records
    assert_equal 3, change_records.size
    found_pass = false
    found_fail = false
    change_records.each do |cr|
      if cr.failed?
        found_fail = true
      else
        found_pass = true
      end
    end
    assert found_pass
    assert found_fail
  end
  test "add or update" do
    u = users(:masteruser)
    ss = SearchSetup.create!(:update_mode=>"any",:module_type=>"Product",:name=>"updo",:user_id=>u.id)
    ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>0)
    ss.search_columns.create!(:model_field_uid=>:prod_name,:rank=>1)

    existing_product = Product.create!(:unique_identifier=>"addonlyprod",:name=>"base name")
    new_product_uid = "newproductuid"

    data = "#{existing_product.unique_identifier},pname\n#{new_product_uid},pname2"

    i = ss.imported_files.create!(:module_type=>"Product",:ignore_first_row=>false,:attached_file_name=>"fname.csv")
    i.process(u,:attachment_data=>data)

    assert_equal "pname", Product.find(existing_product.id).name #first product should have been updated
    assert Product.where(:unique_identifier=>new_product_uid).first #second product should have been added
    
    change_records = i.file_import_results.first.change_records
    assert_equal 2, change_records.size
    found_pass = false
    found_fail = false
    change_records.each do |cr|
      if cr.failed?
        found_fail = true
      else
        found_pass = true
      end
    end
    assert found_pass
    assert !found_fail
  end
  test "update only" do
    u = users(:masteruser)
    ss = SearchSetup.create!(:update_mode=>"update",:module_type=>"Product",:name=>"updo",:user_id=>u.id)
    ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>0)
    ss.search_columns.create!(:model_field_uid=>:prod_name,:rank=>1)

    existing_product = Product.create!(:unique_identifier=>"addonlyprod",:name=>"base name")
    new_product_uid = "newproductuid"

    data = "#{existing_product.unique_identifier},pname\n#{new_product_uid},pname2"

    i = ss.imported_files.create!(:module_type=>"Product",:ignore_first_row=>false,:attached_file_name=>"fname.csv")
    i.process(u,:attachment_data=>data)

    assert_equal "pname", Product.find(existing_product.id).name #first product should have been updated
    assert !Product.where(:unique_identifier=>new_product_uid).first #second product should not have been added
    
    change_records = i.file_import_results.first.change_records
    assert_equal 2, change_records.size
    found_pass = false
    found_fail = false
    change_records.each do |cr|
      if cr.failed?
        found_fail = true
      else
        found_pass = true
      end
    end
    assert found_pass
    assert found_fail
  end
  test "add only" do
    u = users(:masteruser)
    ss = SearchSetup.create!(:update_mode=>"add",:module_type=>"Product",:name=>"addo",:user_id=>u.id)
    ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>0)
    ss.search_columns.create!(:model_field_uid=>:prod_name,:rank=>1)

    existing_product = Product.create!(:unique_identifier=>"addonlyprod",:name=>"base name")
    new_product_uid = "newproductuid"

    data = "#{existing_product.unique_identifier},pname\n#{new_product_uid},pname2"

    i = ss.imported_files.create!(:module_type=>"Product",:ignore_first_row=>false,:attached_file_name=>"fname.csv")
    i.process(u,:attachment_data=>data)

    assert_equal existing_product.name, Product.find(existing_product.id).name #first product should not have been updated
    assert Product.where(:unique_identifier=>new_product_uid).first #second product should have been added
    
    change_records = i.file_import_results.first.change_records
    assert_equal 2, change_records.size
    found_pass = false
    found_fail = false
    change_records.each do |cr|
      if cr.failed?
        found_fail = true
      else
        found_pass = true
      end
    end
    assert found_pass
    assert found_fail
  end

  test "defer process" do
    ImportedFile.any_instance.expects(:delay).returns(nil)

    
    ss = SearchSetup.create!(:name=>'abc',:user_id=>User.first.id,:module_type=>"Product")
    i = ss.imported_files.create!(:module_type=>"Product")
    u = User.first

    i.process(u,{:defer=>true})

  end

  test "deletable?" do
    i = ImportedFile.new()
    assert i.deletable?
    i.file_import_results.build
    assert !i.deletable?
  end

  test "core_module" do
    i = ImportedFile.new(:module_type=>"Product")
    assert i.core_module==CoreModule::PRODUCT
  end

  test "find file_import" do
    f = ImportedFile.create!(:module_type=>"Product")
    r1 = f.file_import_results.create!(:finished_at=>2.days.ago,:created_at=>2.days.ago)
    r2 = f.file_import_results.create!

    found = f.last_file_import_finished
    assert r1==found
    found = f.last_file_import
    assert r2==found
  end

  test "File Import Result Created" do
    ss = SearchSetup.create!(:module_type=>"Product",:name=>"ss1",:user_id=>1)
    ss.search_columns.create!(:model_field_uid=>"prod_uid",:rank=>0)
    f = ImportedFile.create!(:module_type=>ss.module_type,:attached_file_name => 'fname', :search_setup_id => ss.id, :ignore_first_row => false)
    attachment_data = "puid001\npuid002"
    f.process(User.find(1),:attachment_data=>attachment_data)
    results = f.file_import_results
    assert results.size==1
    r = results.first
    assert r.started_at>10.seconds.ago
    assert r.finished_at > 10.seconds.ago
    assert r.run_by.id==1
    change_records = r.change_records
    assert change_records.size==2, "Should have had 2 change records, had #{change_records.size}"
    good_uids = ["puid001","puid002"]
    change_records.each do |cr|
      assert cr.recordable.is_a?(Product)
      good_uids.delete(cr.recordable.unique_identifier)
      msgs = cr.change_record_messages
      assert msgs.size==1
      msg = msgs.first
      good_msgs = ["Unique Identifier set to puid001","Unique Identifier set to puid002"]
      assert good_msgs.include?(msg.message), "Message not in good_msgs array: #{msg.message}"
    end
    assert good_uids.size==0
  end

  test "can_view?" do
    #you can view an imported file if it was imported by you or someone in your company.
    #admins & sys_admins can view all imported files
    
    mu = users(:masteruser)
    vu = users(:vendoruser)
    au = users(:adminuser)
    su = User.create!(:username=>"sauser",:password=>"abc123",:password_confirmation=>"abc123",:email=>"ababa@ba.com",:company_id=>companies(:master).id)
    su.sys_admin = true
    su.save!
    vu2 = User.create!(:username=>"vu2user",:password=>"123abc",:password_confirmation=>"123abc",:email=>"bababa@aa.com",:company_id=>companies(:vendor).id)

    file = ImportedFile.new(:user=>vu)
    assert !file.can_view?(mu)
    assert file.can_view?(vu)
    assert file.can_view?(vu2)
    assert file.can_view?(au)
    assert file.can_view?(su)
  end

  test "failed row" do
    #tests that a validation catches the line that doesn't have an "a" and writes a failed change record
    vendor_id = companies(:vendor).id
    attachment = "abc,#{vendor_id}\ndef,#{vendor_id}\nabd,#{vendor_id}"

    rule = FieldValidatorRule.create!(:model_field_uid=>"ord_ord_num",:regex=>"^a.*",:custom_message=>"cmsg")

    ic = SearchSetup.new(:module_type => "Order", :name => "test", :user_id => users(:masteruser))
    ic.save!
    ic.search_columns.create(:model_field_uid => "ord_ord_num", :rank => 0)
    ic.search_columns.create(:model_field_uid => "ord_ven_id", :rank => 1)
    f = ImportedFile.new(:module_type=>ic.module_type,:attached_file_name => 'fname', :search_setup_id => ic.id, :ignore_first_row =>false)
    f.save!
    f.process(users(:masteruser),{:attachment_data=>attachment})
    fr = f.file_import_results.first
    orders = []
    ["abc","abd"].each do |n|
      ord = Order.where(:order_number=>n).first
      assert !ord.nil?
      orders << ord
    end

    change_records = fr.change_records
    assert change_records.size==3 #one for each row
    
    found_failed = false
    change_records.each do |cr|
      changed = cr.recordable
      if changed.nil?
        assert cr.failed?
        found_failed = true
        msgs = cr.change_record_messages.collect {|m| m.message}
        assert msgs.include?("ERROR: #{rule.custom_message}"), "Expected to include ERROR: #{rule.custom_message}, array: #{msgs}" 

      else
        orders.delete changed
      end
    end
    assert found_failed
    assert orders.empty?
  end

  test "process" do
    base_order = Order.find(1)
    new_order_date = "2001-01-03"
    attachment = "Order Number,Order Date\n#{base_order.order_number},#{new_order_date}"
    f = ImportedFile.find(1)
    f.process(User.find(1),{:attachment_data => attachment})
    assert Order.find(1).order_date==Date.new(2001,1,3), "Order Date was not updated."
    #validate columns imported
    scs = ImportedFile.find(1).search_columns.order("rank ASC").all 
    assert scs.length==2
    assert scs[0].model_field_uid=="ord_ord_num"
    assert scs[0].rank == 0
    assert scs[1].model_field_uid=="ord_ord_date"
    assert scs[1].rank == 1
  end
  
  test "process order with product detail" do
    base_prod = Product.find(1)
    base_order = Order.find(2)
    attachment = "#{base_order.order_number},#{base_prod.unique_identifier}"
    ImportedFile.find(2).process(User.find(1),{:attachment_data => attachment})
    assert Order.find(2).order_lines.first.product_id == base_prod.id, "Product was not id #{base_prod.id}"
  end

  test "preview order" do
    base_order = Order.find(1)
    new_order_date = "2001-01-03"
    attachment = "Order Number,Order Date\n#{base_order.order_number},#{new_order_date}"
    r = ImportedFile.find(1).preview(User.find(1),{:attachment_data => attachment})
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
    f = ImportedFile.new(:module_type=>ic.module_type,:attached_file_name => 'fname', :search_setup_id => ic.id, :ignore_first_row => true)
    f.save!
    assert !f.process(ic.user,{:attachment_data => attachment}), "Process passed and should have failed."
    assert f.errors[:base].include?("Row 2: An order's vendor cannot be changed via a file upload."), "Did not find vendor error message."
  end
  
  test "record with empty details only creates header" do
    ic = SearchSetup.new(:module_type => "Order", :name => "test", :user_id => users(:masteruser))
    ic.save!
    ic.search_columns.create(:model_field_uid => "ord_ord_num", :rank => 0)
    ic.search_columns.create(:model_field_uid => "ord_ven_id", :rank => 1)
    ic.search_columns.create(:model_field_uid => "ordln_puid", :rank => 2)
    ic.search_columns.create(:model_field_uid => "ordln_ordered_qty", :rank => 3)
    f = ImportedFile.new(:module_type=>ic.module_type,:attached_file_name => 'fname', :search_setup_id => ic.id, :ignore_first_row => false)
    f.save!
    order_number = "r_e_d_o_c_h"
    attachment = "#{order_number},2,\"\",\"\""
    assert f.process(ic.user,{:attachment_data => attachment}), "Imported File did not process successfully: #{f.errors.to_s}"
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
    f = ImportedFile.new(:module_type=>ic.module_type,:attached_file_name => 'fname', :search_setup_id => ic.id, :ignore_first_row=>false)
    assert f.process(ic.user,:attachment_data => attachment), "Imported File did not process successfully: #{f.errors.to_s}"
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
    f = ImportedFile.new(:module_type=>ss.module_type,:attached_file_name => 'fname', :search_setup_id => ss.id, :ignore_first_row=>false)
    assert f.process(ss.user,:attachment_data => attachment), "Imported File did not process successfully: #{f.errors.to_s}"
    found = Product.where(:unique_identifier => vh[:unique_identifier]).first
    assert found.name == vh[:name], "name failed"
    assert found.vendor_id == vh[:vendor_id], "vendor id failed"
    assert found.division_id == vh[:div_id], "division id failed"
  end

  test "product with bad hts" do
    ss = SearchSetup.create!(:module_type=>"Product",:name=>"tbpb",:user_id=>users(:masteruser).id)
    f = ss.imported_files.new(:attached_file_name=>'fname',:ignore_first_row=>false)
    attach_array = ["pbhts","US","1","9999999999"]
    ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>0)
    ss.search_columns.create!(:model_field_uid=>:class_cntry_iso,:rank=>1)
    ss.search_columns.create!(:model_field_uid=>:hts_line_number,:rank=>2)
    ss.search_columns.create!(:model_field_uid=>:hts_hts_1,:rank=>3)
    assert !f.process(ss.user,:attachment_data=>attach_array.to_csv)
    assert !f.errors.full_messages.first.index("HTS Number 9999999999 is invalid for US.").nil?
  end

  test "product missing HTS line number" do 
    ot = OfficialTariff.create!(:hts_code=>"1555555555",:country_id=>countries(:us).id,:full_description=>"FD")
    ss = SearchSetup.create!(:module_type=>"Product",:name=>"tbpb",:user_id=>users(:masteruser).id)
    f = ss.imported_files.new(:attached_file_name=>'fname',:ignore_first_row=>false)
    attach_array = ["pbhts","US","",ot.hts_code]
    ss.search_columns.create!(:model_field_uid=>:prod_uid,:rank=>0)
    ss.search_columns.create!(:model_field_uid=>:class_cntry_iso,:rank=>1)
    ss.search_columns.create!(:model_field_uid=>:hts_line_number,:rank=>2)
    ss.search_columns.create!(:model_field_uid=>:hts_hts_1,:rank=>3)
    assert !f.process(ss.user,:attachment_data=>attach_array.to_csv)
    assert !f.errors.full_messages.first.index("Line cannot be processed with empty #{ModelField.find_by_uid(:hts_line_number).label}.").nil?
  end

  test "product with classification and tariffs" do
    vh = {
      :prod_uid=>"pwc_test",
      :prod_ven_id=>companies(:vendor).id,
      :class_cntry_iso => "US",
      :hts_line_number => "1",
      :hts_hts_1 => "9900778811"
    }
    OfficialTariff.create!(:hts_code=>vh[:hts_hts_1],:country_id=>countries(:us).id,:full_description=>"FD")
    ss = SearchSetup.create!(:module_type=>"Product",:name=>"test", :user_id=> users(:masteruser).id)
    attach_array = []
    [:prod_uid,:prod_ven_id,:class_cntry_iso,:hts_line_number,:hts_hts_1].each_with_index do |uid,i|
      attach_array << vh[uid]
      ss.search_columns.create!(:model_field_uid => uid,:rank=>i)
    end
    f = ss.imported_files.create!(:attached_file_name=>'fname',:ignore_first_row=>false,:module_type=>"Product")
    assert f.process(ss.user,:attachment_data => attach_array.to_csv), "Imported File did not process successfully: #{f.errors.to_s}"
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
    vh[:hts_line_number] = "1"
    OfficialTariff.create!(:hts_code=>vh[:hts_hts_1],:country_id=>countries(:us).id,:full_description=>"FD")
    attach_array.pop 2
    attach_array << vh[:hts_line_number]
    attach_array << vh[:hts_hts_1]
    assert f.process(ss.user,:attachment_data => attach_array.to_csv), "Imported File did not process successfully: #{f.errors.to_s}"
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

  test "change product status" do
    p = Product.create!(:unique_identifier=>"CPS",:vendor_id=>companies(:vendor))
    p.set_status
    p.save!
    assert p.status_rule==status_rules(:ProductFallback)

    ss = SearchSetup.create!(:module_type=>"Product",:name=>"cpstest",:user_id=>users(:masteruser))
    ["prod_uid","*cf_1"].each_with_index {|u,i| ss.search_columns.create!(:model_field_uid=>u,:rank=>i)}
    f = ss.imported_files.new(:attached_file_name=>'fn.csv',:ignore_first_row=>false)
    assert f.process(User.find(1),:attachment_data=>"#{p.unique_identifier},true")

    p = Product.find p.id
    assert p.status_rule==status_rules(:ProductIsApproved), "Status rule should have been #{status_rules(:ProductIsApproved).id}, was #{p.status_rule_id}"
  end

  test "boolean value" do 
    ss = SearchSetup.create!(:module_type=>"Product",:name=>"booltest",:user_id => 1)
    cd = CustomDefinition.create!(:label=>"boolt",:data_type=>"boolean",:module_type=>"Product")
    ["prod_uid","*cf_#{cd.id}"].each_with_index {|u,i| ss.search_columns.create!(:model_field_uid=>u,:rank=>i)}
    f = ss.imported_files.new(:attached_file_name=>"myf.csv",:ignore_first_row=>false)
    data = [{:uid=>"bool1",:bv=>"Yes",:should=>true},
      {:uid=>"bool2",:bv=>"True",:should=>true},
      {:uid=>"bool3",:bv=>"F",:should=>false},
      {:uid=>"bool4",:bv=>"No",:should=>false},
      {:uid=>"bool5",:bv=>"j",:should=>nil}
      ]
    attachment = ""
    data.each {|h| attachment << "#{h[:uid]},#{h[:bv]}\n"}
    assert f.process(User.find(1),:attachment_data=>attachment), "Process failed: #{f.errors}"

    data.each do |h|
      p = Product.where(:unique_identifier=>h[:uid]).first
      cv = p.get_custom_value cd
      assert cv.value==h[:should], "Product #{h[:uid]}, Should have found #{h[:should]}, found #{cv.value}"
    end
  end
end
