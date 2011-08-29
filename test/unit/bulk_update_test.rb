require 'test_helper'

class BulkUpdateTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "Bulk Instant Classify" do
    ic = InstantClassification.create!(:name=>'bulk test')
    ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'sw',:value=>'bulk')
    us_c = ic.classifications.create!(:country_id=>countries(:us).id)
    us_c.tariff_records.create!(:hts_1=>'123456789')
    china_c = ic.classifications.create!(:country_id=>countries(:china).id)
    china_c.tariff_records.create!(:hts_1=>'5555555')
    
    p_update_1 = Product.create!(:unique_identifier=>'bulk1')
    should_get_replaced = p_update_1.classifications.create!(:country_id=>countries(:us).id)
    should_get_replaced.tariff_records.create!(:hts_1=>'99999999')
    should_be_left_alone = p_update_1.classifications.create!(:country_id=>countries(:italy).id)
    should_be_left_alone.tariff_records.create!(:hts_2=>'88888888')
    p_update_2 = Product.create!(:unique_identifier=>'bulk2')
    p_checked_dont_update = Product.create!(:unique_identifier=>'nomatch') #this one doesn't match the criterions so should be left alone
    p_not_checked = Product.create!(:unique_identifier=>'bulk_not_checked') #this one isn't checked so should be left alone
    
    form_hash = {'pk'=>{}}
    [p_update_1,p_update_2,p_checked_dont_update].each {|p| form_hash["pk"][p.id.to_s]=p.id.to_s}

    OpenChain::BulkInstantClassify.go form_hash, users(:masteruser)

  #first check that the products were changed properly
    
    #these two shouldn't have been changed  
    assert Product.find(p_not_checked.id).classifications.empty?
    assert Product.find(p_checked_dont_update.id).classifications.empty?

    #this one should have the US value replaced, the italy value left alone, and the china value added
    p1 = Product.find(p_update_1.id)
    assert_equal 3, p1.classifications.size
    p1_us = p1.classifications.where(:country_id=>countries(:us).id).first
    assert_equal us_c.tariff_records.first.hts_1, p1_us.tariff_records.first.hts_1
    p1_china = p1.classifications.where(:country_id=>countries(:china).id).first
    assert_equal china_c.tariff_records.first.hts_1, p1_china.tariff_records.first.hts_1
    p1_italy = p1.classifications.where(:country_id=>countries(:italy).id).first
    assert_equal should_be_left_alone.tariff_records.first.hts_2, p1_italy.tariff_records.first.hts_2

    #this one should have china and US added
    p2 = Product.find(p_update_2.id)
    assert_equal 2, p2.classifications.size
    p2_us = p2.classifications.where(:country_id=>countries(:us).id).first
    assert_equal us_c.tariff_records.first.hts_1, p2_us.tariff_records.first.hts_1
    p2_china = p2.classifications.where(:country_id=>countries(:china).id).first
    assert_equal china_c.tariff_records.first.hts_1, p2_china.tariff_records.first.hts_1

  #then check that the result records were created
    ir = InstantClassificationResult.first
    assert_equal users(:masteruser), ir.run_by
    assert ir.run_at > 10.seconds.ago
    assert ir.finished_at > 10.seconds.ago

    recs = ir.instant_classification_result_records
    assert_equal 3, recs.size
    expected_products = [p_update_1,p_update_2,p_checked_dont_update]
    recs.each do |r|
      p = r.product
      expected_products.delete p
      case p
      when p_update_1
        assert_equal p, r.entity_snapshot.recordable
        assert r.changed_product?
      when p_update_2
        assert_equal p, r.entity_snapshot.recordable
        assert r.changed_product?
      when p_checked_dont_update
        assert_nil r.entity_snapshot
        assert !r.changed_product?
      else
        fail "Unexpeted object #{p.to_s}"
      end
    end
    assert expected_products.empty?
  end
end
