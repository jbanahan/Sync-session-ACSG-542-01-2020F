require 'test_helper'

class MilestonePlanTest < ActiveSupport::TestCase

  test "name uniqueness" do
    name = "unique name"
    MilestonePlan.create!(:name => name, :test_rank => 1000, :inbound => true)
    assert !MilestonePlan.new(:name => name, :test_rank => 2000, :inbound => true).save, "Should not be able to save 2 plans with same name."
    assert MilestonePlan.new(:name => name, :test_rank => 2000, :inbound => false).save, "Should be able to save 2 plans with same name and different inbound values."
  end
  
  test "test_rank uniquness" do
    rank = 1000
    MilestonePlan.create!(:name => "unique name", :test_rank => rank, :inbound=>true)
    assert !MilestonePlan.new(:name => "uniquerer name", :test_rank => rank, :inbound=>true).save, "Should not be able to save 2 plans with same rank."
    assert MilestonePlan.new(:name => "uniquerer name", :test_rank => rank, :inbound => false).save, "Should be able to save because unique test is scoped on inbound."
  end

  test "ranked" do
    [1001,1014,1007].each { |r|
      MilestonePlan.create!(:name=>"ranked name #{r}", :test_rank => r)
    }
    last_num = -1
    MilestonePlan.ranked.each { |p|
      assert p.test_rank > last_num, "MilestonePlans returned out of order. Last was #{last_num}, current is #{p.test_rank}"
      last_num = p.test_rank
    }
  end
  
  test "find matching piece sets - simple" do
    ord_num = "matching simple order number"
    o = Order.create!(:order_number => ord_num, :vendor => Company.where(:vendor=>true).first)
    line = o.order_lines.create!(:product => Product.first, :ordered_qty => 100)
    line.make_unshipped_remainder_piece_set.save!
    mp = MilestonePlan.create!(:name=>"find-matching-simple-mp",:test_rank=>1000,:inbound=>true)
    mp.search_criterions.create!(:model_field_uid => ModelField.find_by_uid("ord_ord_num").uid,:condition=>"eq",:value=>ord_num)
    matching = mp.find_matching_piece_sets
    assert matching.length == 1, "Should have found 1 piece set, found #{matching.length}"
    assert matching.first.order_line.order.id == o.id, "Should have found order #{o.id}, found #{matching.first.id}"
  end
  
  test "find matching piece sets - custom value" do 
    test_val = "my test value"
    cd = CustomDefinition.create!(:label=>"mps_cv",:data_type=>"string",:rank=>1,:module_type=>"OrderLine")
    o = Order.create!(:order_number => "mps_cv_o", :vendor => Company.where(:vendor=>true).first)
    line = o.order_lines.create(:product => Product.where(:vendor_id=>o.vendor).first, :ordered_qty => 100)
    cv = line.get_custom_value(cd)
    cv.value = test_val
    cv.save!
    ps = line.make_unshipped_remainder_piece_set.save!
    mp = MilestonePlan.create!(:name=>"find-mps-cv", :test_rank=>1000,:inbound=>true)
    mp.search_criterions.create(:model_field_uid => SearchCriterion.make_field_name(cd),:condition=>"eq",:value=>test_val)
    matching = mp.find_matching_piece_sets
    assert matching.length == 1, "Should have found 1 piece set, found #{matching.length}"
    assert matching.first.order_line.order.id = o.id, "Should have found order #{o.id}, found #{matching.first.id}"
  end
  
  test "matches?" do
    ord_num = "matching simple order number"
    o = Order.create!(:order_number => ord_num, :vendor => Company.where(:vendor=>true).first)
    line = o.order_lines.create!(:product => Product.first, :ordered_qty => 100)
    ps = line.make_unshipped_remainder_piece_set
    ps.save!
    mp = MilestonePlan.create!(:name=>"find-matching-simple-mp",:test_rank=>1000,:inbound=>true)
    mp.search_criterions.create!(:model_field_uid => ModelField.find_by_uid("ord_ord_num").uid,:condition=>"eq",:value=>ord_num)
    assert mp.matches?(ps), "Should have matched the piece set created in this test"
    assert !mp.matches?(PieceSet.find(1)), "Should not have matched another piece set"
  end
end
