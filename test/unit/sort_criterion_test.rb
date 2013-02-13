require 'test_helper'

class SortCriterionTest < ActiveSupport::TestCase
  
  test "apply" do
    zv = Company.create!(:name => "Z vendor", :vendor => true)
    zp = Product.create!(:unique_identifier => "search_crit_test_1", :name=>"sctest", :vendor => zv, :division => Division.first)
    av = Company.create!(:name => "A vendor", :vendor => true)
    ap = Product.create!(:unique_identifier => "search_crit_test_2", :name=>"sctest", :vendor => av, :division => Division.first)
    mf = ModelField.find_by_uid("prod_ven_name")
    sc = SortCriterion.create(:model_field_uid => mf.uid, :descending => true);
    results = sc.apply(Product.where(:name=>"sctest"))
    assert results.first==zp, "Expected id #{zv.id}, got #{results.first.id}"
    assert results.last==ap
    sc.descending = false
    sc.save!
    results = sc.apply(Product.where(:name=>"sctest"))
    assert results.first==ap
    assert results.last==zp
  end

  test "apply multi-level" do
    zp = Product.create!(:unique_identifier=>"hts_sort_1",:name=>"hct",:vendor=>companies(:vendor))
    zh = zp.classifications.create!(:country_id=>Country.first.id).tariff_records.create!(:hts_1=>"999")
    ap = Product.create!(:unique_identifier=>"hts_sort_2",:name=>"hct",:vendor=>companies(:vendor))
    ah = ap.classifications.create!(:country_id=>Country.first.id).tariff_records.create!(:hts_1=>"111")
    sc = SortCriterion.create(:model_field_uid=>"hts_hts_1",:descending=>true);
    results = sc.apply(Product.where(:name=>"hct"))
    assert results.first==zp
    assert results.last==ap
    sc.descending = false
    sc.save!
    results = sc.apply(Product.where(:name=>"hct"))
    assert results.first==ap
    assert results.last==zp
  end

  test "apply multi-level custom" do
    cd = CustomDefinition.create!(:module_type=>"Classification",:label=>"MC",:data_type=>"integer")
    ModelField.reload
    zp = Product.create!(:unique_identifier=>"hts_sort_1",:name=>"hct",:vendor=>companies(:vendor))
    zc = zp.classifications.create!(:country_id=>Country.first.id)
    zcv = zc.get_custom_value(cd)
    zcv.value = 2
    zcv.save!
    ap = Product.create!(:unique_identifier=>"hts_sort_2",:name=>"hct",:vendor=>companies(:vendor))
    ac = ap.classifications.create!(:country_id=>Country.first.id)
    acv = ac.get_custom_value(cd)
    acv.value = 1
    acv.save!

    sc = SortCriterion.new(:model_field_uid => "*cf_#{cd.id}",:descending=>true)

    results = sc.apply(Product.where(:name=>"hct"))
    assert results.first==zp
    assert results.last == ap
    sc.descending = false
    sc.save!
    results = sc.apply(Product.where(:name=>"hct"))
    assert results.first==ap
    assert results.last==zp
  end
end
