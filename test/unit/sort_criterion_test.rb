require 'test_helper'

class SortCriterionTest < ActiveSupport::TestCase
  
  test "apply" do
    zv = Company.create!(:name => "Z vendor", :vendor => true)
    zp = Product.create!(:unique_identifier => "search_crit_test_1", :vendor => zv, :division => Division.first)
    av = Company.create!(:name => "A vendor", :vendor => true)
    ap = Product.create!(:unique_identifier => "search_crit_test_2", :vendor => av, :division => Division.first)
    mf = ModelField.find_by_uid("prod_ven_name")
    sc = SortCriterion.create(:model_field_uid => mf.uid, :descending => true);
    results = sc.apply(Product.where("1=1"))
    assert results.to_sql.include? "#{mf.join_alias}.#{mf.field_name} DESC"
  end
end
