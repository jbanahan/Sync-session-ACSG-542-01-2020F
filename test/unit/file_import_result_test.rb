require 'test_helper'

class FileImportResultTest < ActiveSupport::TestCase
  test "changed objects" do
    fir = FileImportResult.create!
    3.times do |i| #add 3 products twice for 6 total change records
      p = Product.create!(:unique_identifier=>"#{i}pid")
      2.times { |z| fir.change_records.create!(:recordable=>p) }
    end
    co = fir.changed_objects
    assert_equal 3, co.size
    3.times do |i|
      assert co.include?(Product.where(:unique_identifier=>"#{i}pid").first)
    end
  end

  test "changed objects with filter" do 
    i_file = ImportedFile.create!(:module_type=>"Product",:update_mode=>'any')
    fir = i_file.file_import_results.create!
    3.times do |i| #add 3 products twice for 6 total change records
      p = Product.create!(:unique_identifier=>"#{i}pid")
      2.times { |z| fir.change_records.create!(:recordable=>p) }
    end
    co = fir.changed_objects [SearchCriterion.new(:model_field_uid=>"prod_uid",:operator=>"eq",:value=>"1pid")]
    assert_equal 1, co.size
    assert_equal Product.where(:unique_identifier=>"1pid").first, co.first
  end
end
