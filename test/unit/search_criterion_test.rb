require 'test_helper'

class SearchCriterionTest < ActiveSupport::TestCase

  def setup
    ActiveRecord::Base.connection.execute("set time_zone = '+0:00'") #ensure we're working in UTC to make sure local system offsets don't screw with date math
  end

  test "test?" do
    p = Product.create!(:unique_identifier=>"uid111")
    sc = SearchCriterion.new(:model_field_uid=>"prod_uid",:operator=>"eq",:value=>p.unique_identifier)
    assert sc.test?(p)
    p = Product.create!(:unique_identifier=>"somethingelse")
    assert !sc.test?(p)
  end
  test "empty custom value" do
    cd = CustomDefinition.create!(:module_type=>"Product",:label=>"CD1",:data_type=>"date")
    p = Product.create!(:unique_identifier=>"uid")
    sc = SearchCriterion.new(:model_field_uid=>"*cf_#{cd.id}",:operator=>"null")
    found = sc.apply(Product)
    assert found.include? p
    assert sc.passes? p.get_custom_value(cd).value
  end

  test "one of" do
    o = Order.create!(:order_number=>"ordoneof",:vendor_id=>companies(:vendor).id)
    o2 = Order.create!(:order_number=>"od1d",:vendor_id=>companies(:vendor).id)
    sc = SearchCriterion.create!(:model_field_uid=>:ord_ord_num,:operator=>"in",:value=>"#{o.order_number}\r\n#{o2.order_number}\nord3")
    found = sc.apply(Order)
    assert_equal 2, found.size
    assert found.include? o
    assert found.include? o2

    assert sc.passes?(o.order_number)
    assert sc.passes?(o2.order_number)
    assert !sc.passes?("ddd")

    cd = CustomDefinition.create!(:module_type=>"Order",:label=>"CDI",:data_type=>"integer")
    cv = o.get_custom_value cd
    cv.value = 10
    cv.save!
    cv = o2.get_custom_value cd
    cv.value = 5
    cv.save!

    sc.model_field_uid = "*cf_#{cd.id}"
    sc.value = "5\r\n10\r\n12"

    found = sc.apply(Order)
    assert_equal 2, found.size
    assert found.include? o
    assert found.include? o2

    assert sc.passes?(5)
    assert sc.passes?(10)
    assert !sc.passes?(6)
  end

  test "before days ago" do
    o = Order.create!(:order_number=>"ordbda",:order_date=>4.days.ago,:vendor_id=>companies(:vendor).id)
    sc = SearchCriterion.create!(:model_field_uid =>:ord_ord_date,:operator=>"bda",:value=>3)
    found = sc.apply(Order).collect {|ord| ord.id}
    assert found.include?(o.id)
    assert sc.passes?(o.order_date)
    
    [4,5].each do |i|
      sc.value = i
      r = sc.apply(Order)
      found = r.collect {|ord| ord.id}
      assert !found.include?(o.id), "Failed for #{i} days ago."
      assert !sc.passes?(o.order_date), "Failed for #{i} days ago."
    end
  end

  test "after days ago" do 
    o = Order.create!(:order_number=>"ordbda",:order_date=>4.days.ago,:vendor_id=>companies(:vendor).id)
    sc = SearchCriterion.create!(:model_field_uid =>:ord_ord_date,:operator=>"ada",:value=>3)
    [4,5].each do |i|
      sc.value = i
      found = sc.apply(Order).collect {|ord| ord.id}
      assert found.include?(o.id), "Failed for #{i} days."
      assert sc.passes?(o.order_date)
    end
    
    [3].each do |i|
      sc.value = i
      r = sc.apply(Order)
      found = r.collect {|ord| ord.id}
      assert !found.include?(o.id), "Failed for #{i} days ago."
      assert !sc.passes?(o.order_date), "Failed for #{i} days ago."
    end
  end

  test "after days from now" do
    o = Order.create!(:order_number=>"ordbda",:order_date=>4.days.from_now,:vendor_id=>companies(:vendor).id)
    sc = SearchCriterion.create!(:model_field_uid =>:ord_ord_date,:operator=>"adf",:value=>3)
    [3,4].each do |i|
      sc.value = i
      found = sc.apply(Order).collect {|ord| ord.id}
      assert found.include?(o.id)
      assert sc.passes?(o.order_date)
    end
    
    [5].each do |i|
      sc.value = i
      r = sc.apply(Order)
      found = r.collect {|ord| ord.id}
      assert !found.include?(o.id), "Failed for #{i} days ago."
      assert !sc.passes?(o.order_date), "Failed for #{i} days ago."
    end
  end

  test "before days from now" do 
    o = Order.create!(:order_number=>"ordbda",:order_date=>4.days.from_now,:vendor_id=>companies(:vendor).id)
    sc = SearchCriterion.create!(:model_field_uid =>:ord_ord_date,:operator=>"bdf",:value=>3)
    [5].each do |i|
      sc.value = i
      found = sc.apply(Order).collect {|ord| ord.id}
      assert found.include?(o.id)
      assert sc.passes?(o.order_date)
    end
    
    [3,4].each do |i|
      sc.value = i
      r = sc.apply(Order)
      found = r.collect {|ord| ord.id}
      assert !found.include?(o.id), "Failed for #{i} days ago."
      assert !sc.passes?(o.order_date), "Failed for #{i} days ago."
    end
  end

  
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

  def result_includes_id(result,id)
    found = result.collect {|f| f.id}
    found.include? id
  end

  test "database not equal - string" do
    p = Product.create!(:unique_identifier=>"DNE")
    sc = SearchCriterion.create!(:model_field_uid=>"prod_uid",:operator=>"nq",:value=>"DNEF")
    assert result_includes_id(sc.apply(Product), p.id)
    sc.value=p.unique_identifier
    sc.save!
    assert !result_includes_id(sc.apply(Product), p.id)
  end

  test "database not equal - integer / date" do
    cd_i = CustomDefinition.create!(:module_type=>"Product",:label=>"CDI",:data_type=>"integer")
    cd_d = CustomDefinition.create!(:module_type=>"Product",:label=>"CDD",:data_type=>"date")
    p = Product.create!(:unique_identifier=>"DBEID")
    cv_i = p.get_custom_value(cd_i)
    cv_i.value=10
    cv_i.save!
    cv_d = p.get_custom_value(cd_d)
    cv_d.value=1.day.ago
    cv_d.save!

    sc_i = SearchCriterion.create!(:model_field_uid=>"*cf_#{cd_i.id}",:operator=>"nq",:value=>cv_i.value+1)
    assert result_includes_id(sc_i.apply(Product), p.id)
    sc_i.value=cv_i.value
    sc_i.save!
    assert !result_includes_id(sc_i.apply(Product), p.id)
    cv_i.value=nil
    cv_i.save!
    assert result_includes_id(sc_i.apply(Product), p.id)

    sc_d = SearchCriterion.create!(:model_field_uid=>"*cf_#{cd_d.id}",:operator=>"nq",:value=>3.days.ago)
    assert result_includes_id(sc_d.apply(Product), p.id)
    sc_d.value=1.day.ago
    sc_d.save!
    r = sc_d.apply(Product)
    assert !result_includes_id(r,p.id), "Should not have include result: Custom Value: #{cv_d.value}, Search Criterion Value: #{sc_d.value}, SQL: #{r.to_sql}"
    cv_d.value=nil
    cv_d.save!
    assert result_includes_id(sc_d.apply(Product), p.id)
  end

  test "database does not contain" do
    sc = SearchCriterion.create!(:model_field_uid=>"ord_ord_num",:operator=>"nc",:value=>"ord")
    find_me = Order.create!(:order_number=>"XXX",:vendor_id=>companies(:vendor).id)
    dont_find_me = Order.create!(:order_number=>"123ord123",:vendor_id=>companies(:vendor).id)

    r = sc.apply(Order)
    assert result_includes_id(r,find_me.id)
    assert !result_includes_id(r,dont_find_me.id)
  end

  test "passes? :string all operator permutations" do
    sc = SearchCriterion.create!(:model_field_uid=>ModelField.find_by_uid("prod_uid").uid, :operator => "co", 
      :value=>"cde")

    #reload to make sure we have the data types that will really come out of the database
    sc = SearchCriterion.find(sc.id)

    assert sc.passes?("abcdef")
    assert !sc.passes?("cp")
    
    sc.operator="nc" #does not contain
    assert sc.passes?("cp")
    assert !sc.passes?("cdef")

    sc.operator="sw"
    assert sc.passes?("cdef")
    assert !sc.passes?("de")
    
    sc.operator="ew"
    assert sc.passes?("abcde")
    assert !sc.passes?("cd")
    
    sc.operator="eq"
    assert sc.passes?("cde")
    assert !sc.passes?("edc")

    sc.operator="nq"
    assert sc.passes?(nil)
    assert sc.passes?("cdef")
    assert !sc.passes?("cde")
  end
  
  test "passes? :text all operator permutations" do
    cd =CustomDefinition.create!(:module_type=>"Product", :data_type=>"text", :label=>"blah")
    sc = SearchCriterion.create!(:model_field_uid=>"*cf_#{cd.id}", :operator => "co", 
      :value=>"cde")

    #reload to make sure we have the data types that will really come out of the database
    sc = SearchCriterion.find(sc.id)
    
    assert sc.passes?("abcdef")
    assert !sc.passes?("cp")

    sc.operator="nc" #does not contain
    assert sc.passes?("cp")
    assert !sc.passes?("cdef")

    sc.operator="sw"
    assert sc.passes?("cdef")
    assert !sc.passes?("de")

    sc.operator="ew"
    assert sc.passes?("abcde")
    assert !sc.passes?("cd")

    sc.operator="eq"
    assert sc.passes?("cde")
    assert !sc.passes?("edc")

    sc.operator="nq"
    assert sc.passes?(nil)
    assert sc.passes?("cdef")
    assert !sc.passes?("cde")
  end

  test "passes? :boolean all operator permutations" do
    cd = CustomDefinition.create!(:module_type=>"Product", :data_type=>"boolean", :label=>"boolean sc test")
    sc = SearchCriterion.create!(:model_field_uid=>"*cf_#{cd.id}",:operator=>"eq",:value=>"t")

    #reload to make sure we have the data types that will really come out of the database
    sc = SearchCriterion.find(sc.id)

    assert sc.passes?(true)
    assert !sc.passes?(false)
  end
  
  test "passes? :decimal all operator permutations" do
    sc = SearchCriterion.create!(:model_field_uid=>ModelField.find_by_uid("ordln_ordered_qty").uid, 
      :operator => "eq", :value=>6.9)

    #reload to make sure we have the data types that will really come out of the database
    sc = SearchCriterion.find(sc.id)

    assert sc.passes?(6.9)
    assert !sc.passes?(9.6)
    
    sc.operator="gt"
    assert sc.passes?(9.0)
    assert !sc.passes?(3.2)
    
    sc.operator="lt"
    assert sc.passes?(5.0)
    assert !sc.passes?(8.0)
    
    sc.operator="sw"
    assert sc.passes?(6.903)
    assert !sc.passes?(9)
    
    sc.operator="ew"
    assert sc.passes?(16.9)
    assert !sc.passes?(6)
    
    sc.operator="nq"
    assert sc.passes?(nil)
    assert sc.passes?(6.91)
    assert !sc.passes?(6.9)

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

    #reload to make sure we have the data types that will really come out of the database
    sc = SearchCriterion.find(sc.id)
    
    assert sc.passes?(15)
    assert !sc.passes?(6)

    sc.operator="gt"
    assert sc.passes?(17)
    assert !sc.passes?(9)

    sc.operator="lt"
    assert sc.passes?(10)
    assert !sc.passes?(20)

    sc.operator="sw"
    assert sc.passes?(150)
    assert !sc.passes?(5)

    sc.operator="ew"
    assert sc.passes?(515)
    assert !sc.passes?(1)

    sc.operator="nq"
    assert sc.passes?(nil)
    assert sc.passes?(14)
    assert !sc.passes?(15)

    sc.operator="null"
    assert sc.passes?(sc.value=nil)
    assert !sc.passes?(sc.value=15)

    sc.operator="notnull"
    assert sc.passes?(sc.value=15)
    assert !sc.passes?(sc.value=nil)
  end
  
  test "passes? :date all operator permutations" do
    d = 1.day.ago 
    sc = SearchCriterion.create!(:model_field_uid=>ModelField.find_by_uid("sale_order_date").uid, 
      :operator => "eq", :value=>d)
    
    #reload to make sure we have the data types that will really come out of the database
    sc = SearchCriterion.find(sc.id)

    assert sc.passes?(d)
    assert !sc.passes?(d + 6.days)
    
    sc.operator = "gt"
    assert sc.passes?(d + 10.days)
    assert !sc.passes?(d - 6.days)
    
    sc.operator = "lt"
    assert sc.passes?(d - 10.days)
    assert !sc.passes?(d + 6.days)

    sc.operator = "nq"
    assert sc.passes?(nil)
    assert sc.passes?(d-1.day)
    assert !sc.passes?(d), "Passed, shouldn't have: sc.value=#{sc.value}, test value #{d}"
  
  end
end
