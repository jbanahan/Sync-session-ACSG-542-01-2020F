require 'test_helper'

class SearchCriterionTest < ActiveSupport::TestCase
  test "with join" do
    v = Company.create!(:name=>"VVVVVV", :vendor=>true)
    uid = "puid12345 with join"
    p = Product.create!(:unique_identifier => uid, :vendor => v, :division => Division.first)
    sc = SearchCriterion.create!(:model_field_uid => ModelField.find_by_uid("prod_ven_name").uid,
      :condition => "eq", :value => v.name)
    result = sc.apply(Product)
    assert result.length == 1, "Should have returned one record."
    assert result.first.id == p.id
  end
end
