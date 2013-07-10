require 'test_helper'

class ProductTest < ActiveSupport::TestCase

  test "replace classifications" do
    cd = CustomDefinition.create!(:label=>'cddd',:module_type=>'Classification',:data_type=>'string')

    p = Product.create!(:unique_identifier=>"12349")
    p.classifications.create!(:country_id=>countries(:us).id)
    cc = p.classifications.create!(:country_id=>countries(:china).id)
    cc.tariff_records.create!(:hts_1=>'33333333')

    ic = InstantClassification.create!(:name=>'ic')
    to_load_1 = ic.classifications.create!(:country_id=>countries(:china).id)
    tr_1 = to_load_1.tariff_records.create!(:hts_1=>'123456789')
    to_load_2 = ic.classifications.create!(:country_id=>countries(:italy).id)
    tr_2 = to_load_2.tariff_records.create!(:hts_1=>'985823191')

    p.replace_classifications [to_load_1,to_load_2]

    found = Product.find(p.id)

    assert_equal 3, p.classifications.size
    #china should have been updated
    fc_1 = p.classifications.where(:country_id=>countries(:china).id).first
    assert_nil fc_1.instant_classification_id
    assert_equal tr_1.hts_1, fc_1.tariff_records.first.hts_1
    #italy should have been added
    fc_2 = p.classifications.where(:country_id=>countries(:italy).id).first
    assert_nil fc_2.instant_classification_id
    assert_equal tr_2.hts_1, fc_2.tariff_records.first.hts_1
    #us should have been left alone
    fc_3 = p.classifications.where(:country_id=>countries(:us).id).first
    assert_nil fc_3.instant_classification_id
    assert fc_3.tariff_records.empty?

  end

  test "numeric unique identifier" do
    p = Product.create!(:unique_identifier=>"123456X")
    p2 = Product.create!(:unique_identifier=>"123456")
    to_test = Product.new(:unique_identifier=>123456)
    assert_equal p2, to_test.find_same
  end

  test "load_custom_values" do
    cd = CustomDefinition.create!(:module_type=>"Product",:data_type=>"integer",:label=>"AGKL")
    p = Product.create!(:unique_identifier=>"PUIDN")
    base_cv = p.get_custom_value cd
    base_cv.value=10
    base_cv.save!
    p = Product.find p.id
    p.load_custom_values
    cv = p.get_custom_value cd
    assert_equal cv.custom_definition_id, cd.id
    assert_same cv, p.get_custom_value(cd)
    assert_not_same cv, base_cv
  end

  # Replace this with your real tests.
  test "can_view" do
    u = User.find(1)
    assert Product.find(1).can_view?(u), "Master user can't view product."
    u = User.find(4)
    assert !Product.find(1).can_view?(u), "Carrier can view product."
    assert !Product.find(2).can_view?(u), "Carrier can view product."
  end
  
  test "can_edit" do
    u = User.find(1)
    assert Product.find(1).can_edit?(u), "Master user can't edit product."
    u = User.find(4)
    assert !Product.find(1).can_edit?(u), "Carrier can edit product."
    assert !Product.find(2).can_edit?(u), "Carrier can edit product."
  end
  
  test "find_can_view" do
    u = User.find(1)
    assert Product.find_can_view(u) == Product.all, "Master didn't find all."
    u = User.find(2)
    found = Product.find_can_view(u)
    assert found.length>0 && found.include?(Product.find(1)), "Vendor didn't find product 1."
    u = User.find(4)
    found = Product.find_can_view(u)
    assert found.length==0
  end
  
  test "shallow merge into" do
    base_attribs = {
      :unique_identifier => "ui",
      :name => "bname",
      :vendor_id => 2,
      :division_id => 1
    }
    base = Product.new(base_attribs)
    newer_attribs = {
      :unique_identifier => "to be ignored",
      :name => "nname",
      :vendor_id => 3,
      :division_id => 2
    }
    newer = Product.new(newer_attribs)
    base.save!
    newer.save!
    newer.updated_at = DateTime.new(2012,3,9)
    newer.created_at = DateTime.new(2007,5,2)
    target_attribs = {'unique_identifier' => base.unique_identifier,
      'name' => newer.name,
      'division_id' => newer.division_id,
      'vendor_id' => base.vendor_id,
      'updated_at' => base.updated_at,
      'created_at' => base.created_at,
      'id' => base.id
    } 
    base.shallow_merge_into(newer)
    target_attribs.each_key { |k|
      assert target_attribs[k] == base.attributes[k], "Merged key (#{k}) not equal ('#{target_attribs[k]}' & '#{base.attributes[k]}')"
    }
  end
  
  test "has orders?" do
    p = Product.create!(:unique_identifier=>"phas",:vendor=>companies(:vendor))
    assert !p.has_orders?, "Should not find orders."
    Order.create!(:order_number=>"phas",:vendor=>p.vendor).order_lines.create!(:product=>p)
    p.reload
    assert p.has_orders?, "Should find orders."
  end
  
  test "has shipments" do
    p = Product.create!(:unique_identifier=>"phas",:vendor=>companies(:vendor))
    assert !p.has_shipments?, "Should not find shipments."
    Shipment.create!(:reference=>"phas",:vendor=>p.vendor).shipment_lines.create!(:product=>p)
    p.reload
    assert p.has_shipments?, "Should find shipments."
  end
  
  test "has deliveries" do 
    p = Product.create!(:unique_identifier=>"phas",:vendor=>companies(:vendor))
    assert !p.has_deliveries?, "Should not find deliveries."
    Delivery.create!(:reference=>"phas",:customer=>companies(:customer)).delivery_lines.create!(:product=>p)
    p.reload
    assert p.has_deliveries?, "Should find deliveries."
  end
  
  test "has sales orders" do
    p = Product.create!(:unique_identifier=>"phas",:vendor=>companies(:vendor))
    assert !p.has_sales_orders?, "Should not find sales orders"
    SalesOrder.create!(:order_number=>"phas",:customer=>companies(:customer)).sales_order_lines.create!(:product=>p)
    p.reload
    assert p.has_sales_orders?, "Should find sales orders"
  end
  
  test "set status" do
    sr = status_rules(:ProductIsApproved)
    a = products(:ApprovedStatusNotSet)
    a.status_rule_id = nil
    a.set_status
    assert a.status_rule_id == sr.id, "Status rule id should be #{sr.id}, was #{a.status_rule_id}"
    assert a.status_name == sr.name, "Status name should be #{sr.name}, was #{a.status_name}"
  end

  
end
