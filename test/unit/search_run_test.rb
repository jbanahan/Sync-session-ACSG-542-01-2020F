require 'test_helper'

class SearchRunTest < ActiveSupport::TestCase

  test "basic stepping" do
    prods = []
    30.times do |c| 
      prods << Product.create!(:unique_identifier=>"bs_#{c<10 ? "0#{c}" : c}")
    end
    ss = SearchSetup.create!(:name=>"basic stepping search",:module_type=>"Product",:user_id=>1)
    ss.search_criterions.create!(:model_field_uid=>"prod_uid",:operator=>"sw",:value=>"bs_")
    ss.sort_criterions.create!(:model_field_uid=>"prod_uid",:descending=>false)

    initial_search_result = ss.search

    s_run = ss.search_run

    assert !s_run.nil?, "Should have found a search run."

    #walk the search_run results
    30.times { |c| 
      assert_objects prods, c, 0, s_run.current_id, s_run.current_object
      if c>0
        assert_objects prods, c, -1, s_run.previous_id, s_run.previous_object
      else
        assert s_run.previous_id.nil?
        assert s_run.previous_object.nil?
      end
      if c<29
        assert_objects prods, c, 1, s_run.next_id, s_run.next_object
      else
        assert s_run.next_id.nil?
        assert s_run.next_object.nil?
      end
      s_run.move_forward
    }
  end

  test "reset_cursor" do 
    s = SearchRun.new(:position=>99,:result_cache=>"1,2,3,4,5")
    s.reset_cursor
    assert s.cursor == 0
    assert s.result_cache.nil?
  end

  def assert_objects(product_array,cursor,offset,result_id,result_object)
    assert product_array[cursor+offset]==result_object, "Cursor #{cursor}, Offset #{offset}, Expected: #{product_array[cursor+offset].to_s} (#{product_array[cursor+offset].id}), Found: #{result_object} (#{result_object.id})"
    assert product_array[cursor+offset].id==result_id, "Cursor #{cursor}, Offset #{offset}, Expected: #{product_array[cursor+offset].id}, Found: #{result_id}"
  end
end
