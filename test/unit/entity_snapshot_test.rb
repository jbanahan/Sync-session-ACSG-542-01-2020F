require 'test_helper'

class EntitySnapshotTest < ActiveSupport::TestCase

  def setup
    ModelField.reload
  end

  test "diff" do
    jp = Country.create!(:iso_code=>'JP',:name=>"JAPAN")

    p = Product.create!(:unique_identifier=>"pdiff1",:name=>"name1",:division_id=>1)
    c_us = p.classifications.create!(:country_id=>countries(:us).id)
    c_italy = p.classifications.create!(:country_id=>countries(:italy).id)
    snap1 = p.create_snapshot User.first
    p.update_attributes!(:unique_identifier=>"pdiff2",:name=>"name2")
    c_china = p.classifications.create!(:country_id=>countries(:china).id)
    c_italy.destroy
    p = Product.find(p.id)
    snap2 = p.create_snapshot User.first

    diff = snap2.diff(snap1)

    assert_equal p.id, diff.record_id
    assert_equal 'Product', diff.core_module
    mfc = diff.model_fields_changed
    assert_equal 2, mfc.size
    assert_equal ["pdiff1","pdiff2"], mfc['prod_uid']
    assert_equal ["name1","name2"], mfc['prod_name']

    assert_equal 1, diff.children_in_both.size
    us_diff = diff.children_in_both.first
    assert us_diff.model_fields_changed.blank?
    assert_equal c_us.id, us_diff.record_id

    assert_equal 1, diff.children_added.size
    cn_diff = diff.children_added.first
    assert_equal [nil,'CN'], cn_diff.model_fields_changed['class_cntry_iso']
    
    assert_equal 1, diff.children_deleted.size
    it_diff = diff.children_deleted.first
    assert_equal ['IT',nil], it_diff.model_fields_changed['class_cntry_iso']
  end

  test "previous" do 
    p = Product.create!(:unique_identifier=>"prev1")
    snap1 = p.create_snapshot User.first
    p2 = Product.create!(:unique_identifier=>"prev2")
    snap2 = p2.create_snapshot User.first
    snap3 = p.create_snapshot User.first

    assert_nil snap1.previous
    assert_equal snap1, snap3.previous
    assert_nil snap2.previous
  end
  test "make product snapshot" do
    u = User.first
    User.current = u
    pcd = CustomDefinition.create!(:label=>"productcustomfield",:data_type=>"string",:module_type=>"Product")
    p = Product.create!(:unique_identifier=>"mps")
    cv = p.get_custom_value(pcd)
    cv.value="abdef"
    cv.save!
    [:us,:china].each do |country|
      c = p.classifications.create!(:country_id=>countries(country).id)
      ["1234567890","0987654321"].each do |hts|
        t = c.tariff_records.create!(:hts_1=>hts)
      end
    end

    es = EntitySnapshot.create_from_entity p
    es = EntitySnapshot.find es.id #reload from db to make sure everything is persisted properly 
    assert_equal u, es.user
    sj = es.snapshot_json['entity']
    assert_equal 'Product', sj['core_module']
    assert_equal p.id, sj['record_id']
    product_fields = sj['model_fields']
    assert_equal p.unique_identifier, product_fields['prod_uid']
    assert_equal cv.value, product_fields["*cf_#{pcd.id}"]
    children = sj['children']
    expected_countries = ['US','CN']
    expected_classification_ids = p.classifications.collect {|x| x.id }
    assert_equal 2, children.size
    children.each do |classification_json|
      cje = classification_json['entity']
      assert_equal 'Classification', cje['core_module']
      expected_classification_ids.delete cje['record_id']
      expected_countries.delete cje['model_fields']['class_cntry_iso']
      class_children = cje['children']
      assert_equal 2, class_children.size
      expected_hts = ["1234567890","0987654321"]
      class_children.each do |tariff_record_json|
        tje = tariff_record_json['entity']
        assert_equal 'TariffRecord', tje['core_module']
        expected_hts.delete tje['model_fields']['hts_hts_1']
      end
      assert expected_hts.empty?
    end
    assert expected_classification_ids.empty?, "Expected no classifications got #{expected_classification_ids}"
    assert expected_countries.empty?
  end

end
