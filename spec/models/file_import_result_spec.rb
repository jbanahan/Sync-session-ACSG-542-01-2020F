require 'spec_helper'

describe FileImportResult do

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
