require 'spec_helper'

describe FileImportResult do

  it 'should only find unique changed objects' do
    i_file = ImportedFile.create!(:module_type=>"Product",:update_mode=>'any')
    fir = i_file.file_import_results.create!
    3.times do |i| #add 3 products twice for 6 total change records
      p = Product.create!(:unique_identifier=>"#{i}pid")
      2.times { |z| fir.change_records.create!(:recordable=>p) }
    end
    co = fir.changed_objects
    co.should have(3).items
    3.times do |i|
      co.include?(Product.where(:unique_identifier=>"#{i}pid").first).should be_true
    end
  end
  it 'should allow pagination' do
    i_file = ImportedFile.create!(:module_type=>"Product",:update_mode=>'any')
    fir = i_file.file_import_results.create!
    3.times do |i| #add 3 products twice for 6 total change records
      p = Product.create!(:unique_identifier=>"#{i}pid")
      2.times { |z| fir.change_records.create!(:recordable=>p) }
    end
    co = fir.changed_objects
    co.respond_to?('paginate').should be_true
  end
  it 'should allow additional filters on changed_objects' do
    i_file = ImportedFile.create!(:module_type=>"Product",:update_mode=>'any')
    fir = i_file.file_import_results.create!
    3.times do |i| #add 3 products twice for 6 total change records
      p = Product.create!(:unique_identifier=>"#{i}pid")
      2.times { |z| fir.change_records.create!(:recordable=>p) }
    end
    co = fir.changed_objects [SearchCriterion.new(:model_field_uid=>"prod_uid",:operator=>"eq",:value=>"1pid")]
    co.should have(1).item
    co.first.should == Product.where(:unique_identifier=>"1pid").first
  end
  it 'should set changed_object_count on save' do
    file_import_result = Factory(:file_import_result)
    3.times do |i| 
      p = Factory(:product)
      file_import_result.change_records.create!(:recordable => p)
    end
    file_import_result.finished_at = Time.now
    file_import_result.save!
    file_import_result.reload
    file_import_result.changed_object_count.should == 3
  end

end
