require 'test_helper'

class EntitySnapshotTest < ActiveSupport::TestCase

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
