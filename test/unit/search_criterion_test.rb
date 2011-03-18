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
end
