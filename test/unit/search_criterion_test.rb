require 'test_helper'

class SearchCriterionTest < ActiveSupport::TestCase
  
  test "with join" do
    v = Company.create!(:name=>"VVVVVV", :vendor=>true)
    uid = "puid12345 with join"
    p = Product.create!(:unique_identifier => uid, :vendor => v, :division => Division.first)
    sc = SearchCriterion.create!(:model_field_uid => ModelField.find_by_uid("prod_ven_name").uid,
      :operator => "eq", :value => v.name)
    result = sc.apply(Product)
    assert result.length == 1, "Should have returned one record."
    assert result.first.id == p.id
  end

  test "tariff join" do
    p = Product.create!(:unique_identifier=>"tj",:vendor_id=>companies(:vendor).id, :division=>Division.first)
    c = p.classifications.create!(:country_id => Country.first)
    h = c.tariff_records.create!(:hts_1 => "9912345678")
    sc = SearchCriterion.create!(:model_field_uid => "hts_hts_1", :operator => "sw", :value=>"991")
    result = sc.apply(Product)
    assert result.length == 1, "Should have returned one record, returned #{result.length}"
    assert result.first == p, "Should have returned product created in this test."
  end

  test "passes? :string all operator permutations" do
    sc = SearchCriterion.create!(:model_field_uid=>ModelField.find_by_uid("prod_uid").uid, :operator => "co", 
      :value=>"johnpclaus")

    assert sc.passes?("pc")
    assert !sc.passes?("cp")
    
    sc.operator="sw"
    assert sc.passes?("john")
    assert !sc.passes?("claus")
    
    sc.operator="ew"
    assert sc.passes?("claus")
    assert !sc.passes?("john")
    
    sc.operator="eq"
    assert sc.passes?("johnpclaus")
    assert !sc.passes?("clausjohnp")
  end
  
  test "passes? :text all operator permutations" do
    cd =CustomDefinition.create!(:module_type=>"Product", :data_type=>"text", :label=>"blah")
    sc = SearchCriterion.create!(:model_field_uid=>"*cf_#{cd.id}", :operator => "co", 
      :value=>"johnpclaus")
    
    assert sc.passes?("pc")
    assert !sc.passes?("cp")
    
    sc.operator="sw"
    assert sc.passes?("john")
    assert !sc.passes?("claus")
    
    sc.operator="ew"
    assert sc.passes?("claus")
    assert !sc.passes?("john")
    
    sc.operator="eq"
    assert sc.passes?("johnpclaus")
    assert !sc.passes?("clausjohnp")
  end

  test "passes? :boolean all operator permutations" do
    cd = CustomDefinition.create!(:module_type=>"Product", :data_type=>"boolean", :label=>"boolean sc test")
    sc = SearchCriterion.create!(:model_field_uid=>"*cf_#{cd.id}",:operator=>"eq",:value=>"t")

    assert sc.passes?(true)
    assert !sc.passes?(false)
  end
  
  test "passes? :decimal all operator permutations" do
    sc = SearchCriterion.create!(:model_field_uid=>ModelField.find_by_uid("ordln_ordered_qty").uid, 
      :operator => "eq", :value=>6.9)

    assert sc.passes?(6.9)
    assert !sc.passes?(9.6)
    
    sc.operator="gt"
    assert sc.passes?(3.2)
    assert !sc.passes?(9.0)
    
    sc.operator="lt"
    assert sc.passes?(9.0)
    assert !sc.passes?(3.2)
    
    sc.operator="sw"
    assert sc.passes?(6)
    assert !sc.passes?(9)
    
    sc.operator="ew"
    assert sc.passes?(9)
    assert !sc.passes?(6)
    
    sc.operator="null"
    assert sc.passes?(sc.value=nil)
    assert !sc.passes?(sc.value=6.9)
    
    sc.operator="notnull"
    assert sc.passes?(sc.value=6.9)
    assert !sc.passes?(sc.value=nil)
  end
  
  test "passes? :integer all operator permutations" do
    sc = SearchCriterion.create!(:model_field_uid=>ModelField.find_by_uid("ordln_line_number").uid, 
      :operator => "eq", :value=>15)
    
      assert sc.passes?(15)
      assert !sc.passes?(6)

      sc.operator="gt"
      assert sc.passes?(7)
      assert !sc.passes?(100)

      sc.operator="lt"
      assert sc.passes?(30)
      assert !sc.passes?(6)

      sc.operator="sw"
      assert sc.passes?(1)
      assert !sc.passes?(5)

      sc.operator="ew"
      assert sc.passes?(5)
      assert !sc.passes?(1)

      sc.operator="null"
      assert sc.passes?(sc.value=nil)
      assert !sc.passes?(sc.value=15)

      sc.operator="notnull"
      assert sc.passes?(sc.value=15)
      assert !sc.passes?(sc.value=nil)
  end
  
  test "passes? :date all operator permutations" do
    d = Date.new
    sc = SearchCriterion.create!(:model_field_uid=>ModelField.find_by_uid("sale_order_date").uid, 
      :operator => "eq", :value=>d)
    
      assert sc.passes?(d)
      assert !sc.passes?(d + 6)
      
      sc.operator = "gt"
      assert sc.passes?(d - 10)
      assert !sc.passes?(d + 6)
      
      sc.operator = "lt"
      assert sc.passes?(d + 10)
      assert !sc.passes?(d - 6)
  end
end
