require 'spec_helper'

describe FileImportProcessor do
  it 'should initialize without search setup' do
    imp = Factory(:imported_file)
    imp.search_setup_id.should be_nil #factory shouldn't create this
    lambda { FileImportProcessor.new(imp,'a,b') }.should_not raise_error
  end
  it 'should initialize with bad search_setup_id' do
    imp = Factory(:imported_file,:search_setup_id=>9999)
    imp.search_setup.should be_nil #id should not match to anything
    lambda { FileImportProcessor.new(imp,'a,b') }.should_not raise_error
  end
end
