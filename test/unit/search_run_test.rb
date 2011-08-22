require 'test_helper'

class SearchRunTest < ActiveSupport::TestCase
  
  test "all / total objects" do
    p1 = Product.create!(:unique_identifier=>"to_pid10123")
    p2 = Product.create!(:unique_identifier=>"to_pid10333")
    p3 = Product.create!(:unique_identifier=>"to_pid19191")
    ss = SearchSetup.create!(:name=>"test total objects",:user_id=>1,:module_type=>"Product")
    ss.search_criterions.create!(:model_field_uid=>"prod_uid",:operator=>"sw",:value=>"to_pid1")
    ss.touch
    sr = ss.search_run
    assert sr.total_objects == 3, "Expected 3 got: #{sr.total_objects}"
    to_find = [p1,p2,p3]
    sr.all_objects.each {|o| to_find.delete o}
    assert to_find.size==0

    f = ImportedFile.create!(:module_type=>"Product",:update_mode=>'any')
    fir = f.file_import_results.create!(:finished_at=>Time.now)
    [p1,p2].each do |p|
      fir.change_records.create!(:recordable=>p)
    end
    sr = f.search_runs.create!(:user_id=>1)
    assert sr.total_objects == 2, "Expected 2 got: #{sr.total_objects}"
    to_find = [p1,p2]
    sr.all_objects.each {|o| to_find.delete o}
    assert to_find.size==0
  end

  test "last_run" do
    ss = SearchSetup.create!(:name=>"bslr",:module_type=>"Product",:user_id=>1)
    ssr = ss.create_search_run(:last_accessed=>3.days.ago,:user_id=>1)
    bad_ss = SearchSetup.create!(:name=>"bad",:module_type=>"Order",:user_id=>1)
    bssr = bad_ss.create_search_run(:last_accessed=>1.day.ago,:user_id=>1)
    assert !bssr.id.nil?, "Setup check"
    bad_ss2 = SearchSetup.create!(:name=>"also bad",:module_type=>"Product",:user_id=>2)
    bssr2 = bad_ss2.create_search_run(:last_accessed=>1.day.ago,:user_id=>2)
    assert !bssr2.id.nil?, "Setup check 2"
    f = ImportedFile.create!(:module_type=>"Product",:update_mode=>'any')
    fsr = f.search_runs.create!(:last_accessed=>2.days.ago,:user_id=>1)
    busr_fsr = f.search_runs.create!(:last_accessed=>1.day.ago,:user_id=>2)
    bad_f = ImportedFile.create!(:module_type=>"Order",:update_mode=>'any')
    bad_fsr = bad_f.search_runs.create!(:last_accessed=>1.day.ago,:user_id=>1)
    assert !bad_fsr.id.nil?, "Setup check 3"

    found = SearchRun.find_last_run(User.find(1),CoreModule::PRODUCT)
    assert found == fsr, "Should have found #{fsr.to_s}, found #{found.to_s}"

    ssr.update_attributes(:last_accessed=>1.day.ago)
    found = SearchRun.find_last_run(User.find(1),CoreModule::PRODUCT)
    assert found == ssr, "Should have found #{ssr.to_s}, found #{found.to_s}"

    assert !found.readonly?
  end

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
