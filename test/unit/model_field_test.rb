require 'test_helper'

class ModelFieldTest < ActiveSupport::TestCase

  test "product - last changed by" do
    u = User.create!(:username=>"abc123",:password=>"pwd19999",:password_confirmation=>"pwd19999",:company_id=>companies(:master),:email=>'test@chain.io')
    u2 = User.create!(:username=>"123bdd",:password=>"998877",:password_confirmation=>"998877",:company_id=>u.company_id,:email=>'test2@chain.io')

    product = Product.create!(:unique_identifier=>"PID")

    mf = ModelField.find_by_uid(:prod_last_changed_by)
    assert_equal '',  mf.process_export(product)

    product.create_snapshot u

    assert_equal u.username, mf.process_export(product)
    
    product.create_snapshot u2

    assert_equal u2.username, mf.process_export(product)

    sc = SearchCriterion.new(:model_field_uid=>:prod_last_changed_by,:operator=>'eq',:value=>u2.username)
    r = sc.apply Product
    assert_equal 1, r.size
    sc.value = u.username
    r = sc.apply Product
    assert r.blank?
  end

  #test date formats
  test "date formats" do
    o = Order.create!(:order_number=>"on123",:vendor_id=>companies(:vendor).id)

    mf = ModelField.find_by_uid :ord_ord_date

    #real date
    r_date = Date.new(2006,02,19)
    mf.process_import o, r_date
    o.save!
    o.reload
    assert_equal Date.new(2006,02,19), o.order_date

    #geek test
    g_date = "2011-04-20"
    mf.process_import o, g_date
    o.save!
    o.reload
    assert_equal Date.new(2011,4,20), o.order_date

    #american format test
    am_date = "12/25/2009"
    mf.process_import o, am_date
    o.save!
    o.reload
    assert_equal Date.new(2009, 12, 25), o.order_date

    #rest of the world test
    eu_date = "25-8-2010"
    mf.process_import o, eu_date
    o.save!
    o.reload
    assert_equal Date.new(2010, 8, 25), o.order_date

    #nil test
    mf.process_import o, nil
    o.save!
    o.reload
    assert_nil o.order_date
  end

  
  #goal of this test is to make sure that the milestone state shows the worst available value for the line
  test "order milestone state" do
    cd = CustomDefinition.create!(:module_type=>"Shipment",:data_type=>:date,:label=>"Arrival Date")
    mp = MilestonePlan.create!(:name=>"worst state")
    md_1 = mp.milestone_definitions.create!(:model_field_uid=>:ord_ord_date)
    mp.milestone_definitions.create!(:model_field_uid=>"*cf_#{cd.id}",:previous_milestone_definition_id=>md_1.id,:days_after_previous=>5)
    

    o = Order.create!(:order_number=>"olms",:vendor_id=>companies(:vendor).id,:order_date=>30.days.ago)
    o_line = o.order_lines.create!(:line_number=>1,:product_id=>Product.where(:vendor_id=>o.vendor_id).first,:quantity=>100)
    
    s_1 = Shipment.create!(:reference=>"ref1",:vendor_id=>o.vendor_id)
    s_line_1 = s_1.shipment_lines.create!(:line_number=>1,:product_id=>o_line.product_id,:quantity=>90)
    ps_1 = o_line.piece_sets.create!(:quantity=>90,:shipment_line_id=>s_line_1.id,:milestone_plan_id=>mp.id)
    
    cv = s_1.get_custom_value(cd)
    cv.value = 29.days.ago #passes milestone test, so should have milestone state "Achieved"
    cv.save!

    s_2 = Shipment.create!(:reference=>"ref2",:vendor_id=>o.vendor_id)
    s_line_2 = s_2.shipment_lines.create!(:line_number=>1,:product_id=>o_line.product_id,:quantity=>10)
    ps_2 = o_line.piece_sets.create!(:quantity=>10,:shipment_line_id=>s_line_2.id,:milestone_plan_id=>mp.id)
    #s_2 does not have arrival date set so should have milestone state "Overdue"

    #build milestone forecast sets
    [ps_1,ps_2].each {|p| p.create_forecasts}

    assert_equal "Achieved", ps_1.milestone_forecast_set.state
    assert_equal "Overdue", ps_2.milestone_forecast_set.state

    #test the line
    mf = ModelField.find_by_uid(:ordln_ms_state)
    assert_equal "Overdue", mf.process_export(o_line)

    sc = SearchCriterion.new(:model_field_uid=>mf.uid,:operator=>"eq",:value=>"Overdue")
    r = sc.apply(OrderLine.where("1=1")) 
    assert_equal o_line, r.first

    sc.value="Achieved"
    assert_nil sc.apply(OrderLine.where(:id=>o_line.id)).first

    #test the order header
    mf_order = ModelField.find_by_uid(:ord_ms_state)
    assert_equal "Overdue", mf_order.process_export(o)

    sc = SearchCriterion.new(:model_field_uid=>mf_order.uid,:operator=>'eq',:value=>"Overdue")
    r = sc.apply(Order.where("1=1"))
    assert_equal o, r.first

    sc.value="Achieved"
    r = sc.apply(Order.where("1=1"))
    assert_nil r.first
  end

  test "export from piece set" do 
    o = Order.create!(:order_number=>"expfromps",:vendor_id=>companies(:vendor).id)
    o_line = o.order_lines.create!(:line_number=>1,:product_id=>Product.where(:vendor_id=>o.vendor_id).first,:quantity=>1)
    ps = o_line.piece_sets.create!(:quantity=>1)

    mf = ModelField.find_by_uid :ord_ord_num
    assert_equal o.order_number, mf.export_from_piece_set(ps)
    assert_nil ModelField.find_by_uid(:shp_ref).export_from_piece_set(ps)
  end

  test "classification - component count" do
    p = Product.create!(:unique_identifier=>"pidcc")
    c_us = p.classifications.create!(:country_id => countries(:us).id)
    c_cn = p.classifications.create!(:country_id => countries(:china).id)
    c_cn.tariff_records.create!(:hts_1=>"1234567890")
    
    mf = ModelField.find_by_uid :class_comp_cnt
    assert_equal 0, mf.process_export(c_us)
    assert_equal 1, mf.process_export(c_cn)

    sc = SearchCriterion.new(:model_field_uid=>mf.uid,:operator=>"eq",:value=>"1")
    r = Classification.where(:product_id=>p.id)
    r = sc.apply(r)

    assert_equal 1, r.size
    assert_equal c_cn, r.first

  end

  test "field label prefix" do
    #order shouldn't have prefix
    assert !CoreModule::ORDER.show_field_prefix, "Setup issue"
    #classification should
    assert CoreModule::CLASSIFICATION.show_field_prefix, "Setup issue"
    
    mf = ModelField.find_by_uid :ord_ord_num
    assert mf.label=="Order Number"
    assert mf.label(true) == "#{CoreModule::ORDER.label} - Order Number"
    assert mf.label(false) == "Order Number"

    mf = ModelField.find_by_uid :class_cntry_name
    assert mf.label=="#{CoreModule::CLASSIFICATION.label} - Country Name"
    assert mf.label(true)=="#{CoreModule::CLASSIFICATION.label} - Country Name"
    assert mf.label(false)=="Country Name"

  end

  test "entity type" do 
    p = Product.new
    mf = ModelField.find_by_uid :prod_ent_type
    et = EntityType.create!(:name=>"test entity type")
    mf.process_import p, et.name
    assert p.entity_type == et
    et_name = mf.process_export p
    assert et_name == et.name
  end

  test "system code" do 
    m = MasterSetup.get
    m.system_code = "ABC"
    m.save!
    expected = m.system_code
    mf_ids = [:prod_system_code,:ord_system_code,:shp_system_code,:sale_system_code,:del_system_code]
    mf_ids.each do |id|
      mf = ModelField.find_by_uid id
      val = mf.process_export "dummyobject"
      assert val==expected
    end
  end

  test "import / export regulations" do
    #only show import regulations if company has tariffs with them
    ot = OfficialTariff.create!(:hts_code=>"9999999",:import_regulations=>"xyz",:export_regulations=>"abc",:country_id=>Country.first.id,:full_description=>"FD")
    ModelField.reload
    
    t = Product.create!(:unique_identifier=>"IER").classifications.create!(:country_id=>Country.first.id).tariff_records.create!(:line_number=>1,:hts_1=>ot.hts_code,:hts_2=>ot.hts_code,:hts_3=>ot.hts_code)
    mf_ids = [:hts_hts_1_impregs,:hts_hts_2_impregs,:hts_hts_3_impregs,:hts_hts_1_expregs,:hts_hts_2_expregs,:hts_hts_3_expregs]
    mf_ids.each do |id|
      mf = ModelField.find_by_uid id
      val = mf.process_export t
      expected = (id.to_s.end_with?("expregs") ? ot.export_regulations : ot.import_regulations)
      assert val==expected, "MFID: #{id}, Expected #{expected}, got #{val}"
    end
    OfficialTariff.destroy_all
    ModelField.reload
    mf_ids.each {|id| assert ModelField.find_by_uid(id).nil?}
  end

  test "gpt" do
  #only show GPT field if company has canadian tariff setup
    ca = Country.new
    ca.iso_code = "CA"
    ca.save!
    mf = ModelField.find_by_uid :hts_hts_1_gpt
    assert mf.nil?
    ca.import_location = true
    ca.save!
    ModelField.reload
    mf = ModelField.find_by_uid :hts_hts_1_gpt
    assert !mf.nil?
    expected = "Tariff - 1 - GPT Rate"
    assert mf.label==expected, "Expected #{expected}, Found #{mf.label}"
    ot = OfficialTariff.create!(:hts_code=>"999999",:general_preferential_tariff_rate=>"123",:country_id=>ca.id,:full_description=>"fake")
    p = Product.first
    c = p.classifications.create!(:country_id=>ca.id)
    t = c.tariff_records.create!(:hts_1=>ot.hts_code,:line_number=>1)
    r = mf.process_export t
    assert r == ot.general_preferential_tariff_rate, "Expected #{ot.general_preferential_tariff_rate}, got #{r}"

  end

  test "public" do 
    mf = ModelField.find_by_uid "shp_ref"
    assert !mf.public?
    assert !mf.public_searchable?
    pf = PublicField.create!(:model_field_uid=>"shp_ref",:searchable=>false)
    mf = ModelField.find_by_uid "shp_ref"
    assert mf.public?
    assert !mf.public_searchable?
    pf.searchable = true
    pf.save!
    mf = ModelField.find_by_uid "shp_ref"
    assert mf.public?
    assert mf.public_searchable?
  end

  test "test find by uid" do
    uid = "prod_name"
    mf = ModelField.find_by_uid uid
    assert mf.field_name == :name, "Should have found model field with name \"name\""
    assert mf.label == "Name", "Label should have been Name, was \"#{mf.label}\"."
    assert mf.model == CoreModule::PRODUCT.class_name.to_sym, "Should have had model #{CoreModule::PRODUCT.class_name} had #{mf.model}"
  end
  
  test "find by module type" do 
    mfs = ModelField.find_by_module_type CoreModule::PRODUCT.class_name.to_sym
    assert mfs.length > 0, "Should have returned multiple product fields."
    mfs.each {|m| assert m.model==CoreModule::PRODUCT.class_name.to_sym, "Should have had model #{CoreModule::PRODUCT.class_name} had #{m.model}"}
  end
  
  test "find_by_module_type_and_uid" do
    mf = ModelField.find_by_module_type_and_uid CoreModule::ORDER.class_name.to_sym, :ord_ord_num
    assert mf.model==CoreModule::ORDER.class_name.to_sym, "Model was #{mf.model} should have been #{CoreModule::ORDER.class_name}"
    assert mf.field_name==:order_number, "Name was #{mf.field_name} should have been :order_number"
  end
  
  test "data types" do
    mf = ModelField.find_by_module_type_and_uid CoreModule::ORDER.class_name.to_sym, :ord_ord_num
    assert mf.data_type==:string, "Should find string for non-custom column, found #{mf.data_type}"
    mf = ModelField.find_by_module_type_and_custom_id CoreModule::PRODUCT.class_name.to_sym, 1
    assert mf.data_type==:boolean, "Should find boolean for custom column, found #{mf.data_type}"
    mf = ModelField.find_by_module_type_and_uid CoreModule::PRODUCT.class_name.to_sym, :prod_class_count
    assert mf.data_type==:integer, "Should find integer for column with data_type set in hash, found #{mf.data_type}"
  end
  
  test "order line product_uid import/export lambdas" do
    oline = Order.new(:order_number=>"olpuim",:vendor=>companies(:vendor)).order_lines.build(:line_number=>1)
    mf = ModelField.find_by_uid :ordln_puid
    p = companies(:vendor).vendor_products.first
    mf.process_import oline, p.unique_identifier
    oline.save!
    assert oline.errors.empty?, "Order line should not have had any errors. Errors: #{oline.errors.full_messages}"
    exp = mf.process_export(oline)
    assert exp==p.unique_identifier, "Export failed. Expected #{p.unique_identifier}, found: #{exp}"
  end

  test "carrier imports" do
    cname = "carnamedoesnt exist"
    ccode = "carcodedoesnt exist"

    s = Shipment.new
    mf = ModelField.find_by_uid "shp_car_name"
    msg = mf.process_import s, cname
    assert msg=="Carrier auto-created with name \"#{cname}\""
    assert s.carrier.id > 0, "Carrier should have been set and saved."
    assert s.carrier.name==cname, "Carrier should have had name #{cname}, was #{s.carrier.name}"
    assert s.carrier.carrier?, "Carrier should have had carrier set."

    s = Shipment.new
    mf = ModelField.find_by_uid "shp_car_syscode"
    msg = mf.process_import s, ccode
    assert msg=="Carrier not found with code \"#{ccode}\""
    assert s.carrier_id.nil?

    c = Company.create!(:name=>"some company name",:system_code=>"carcode_test_new",:carrier=>true)
    s = Shipment.new
    mf = ModelField.find_by_uid "shp_car_syscode"
    msg = mf.process_import s, c.system_code
    assert msg=="Carrier set to #{c.name}"
    assert s.carrier==c
  end
  test "vendor imports" do
    cname = "vennamedoesnt exist"
    ccode = "vencodedoesnt exist"

    s = Shipment.new
    mf = ModelField.find_by_uid "shp_ven_name"
    msg = mf.process_import s, cname
    assert msg=="Vendor auto-created with name \"#{cname}\""
    assert s.vendor.id > 0, "Vendor should have been set and saved."
    assert s.vendor.name==cname, "Vendor should have had name #{cname}, was #{s.vendor.name}"
    assert s.vendor.vendor?, "Vendor should have had vendor set."

    s = Shipment.new
    mf = ModelField.find_by_uid "shp_ven_syscode"
    msg = mf.process_import s, ccode
    assert msg=="Vendor not found with code \"#{ccode}\""
    assert s.vendor_id.nil?

    c = Company.create!(:name=>"some company name",:system_code=>"vencode_test_new",:vendor=>true)
    s = Shipment.new
    mf = ModelField.find_by_uid "shp_ven_syscode"
    msg = mf.process_import s, c.system_code
    assert msg=="Vendor set to #{c.name}"
    assert s.vendor==c
  end

  test "customer imports" do
    cname = "cusnamedoesnt exist"
    ccode = "cuscodedoesnt exist"

    s = Delivery.new
    mf = ModelField.find_by_uid "del_cust_name"
    msg = mf.process_import s, cname
    assert msg=="Customer auto-created with name \"#{cname}\""
    assert s.customer.id > 0, "Customer should have been set and saved."
    assert s.customer.name==cname, "Customer should have had name #{cname}, was #{s.customer.name}"
    assert s.customer.customer?, "Customer should have had customer set."

    s = Delivery.new
    mf = ModelField.find_by_uid "del_cust_syscode"
    msg = mf.process_import s, ccode
    assert msg=="Customer not found with code \"#{ccode}\""
    assert s.customer_id.nil?

    c = Company.create!(:name=>"some company name",:system_code=>"custcode_test_new",:customer=>true)
    s = Delivery.new
    mf = ModelField.find_by_uid "del_cust_syscode"
    msg = mf.process_import s, c.system_code
    assert msg=="Customer set to #{c.name}"
    assert s.customer==c
  end

  test "blank field label" do
    assert ModelField.find_by_uid("_blank").label=="[blank]"
  end

end
