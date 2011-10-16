require 'spec_helper'

describe ImportedFile do

  describe 'make_updated_file' do
    context 'header only' do
      before :each do 
        @xlc = mock "XLClient"
        @attached = mock "Attachment"
        @attached.should_receive(:path).and_return("some/location.xls")
        OpenChain::XLClient.should_receive(:new).and_return(@xlc)
        @imported_file = ImportedFile.new(:module_type=>"Product",:starting_row=>1,:starting_column=>1)
        @imported_file.should_recieve(:attached).and_return(@attached)
      end
      it 'should update header level products' do
        ["prod_name","prod_uid"].each_with_index {|v,i| @imported_file.search_columns.build(:model_field_uid=>v,:rank=>i)}
        @xlc.should_receive(:last_row_number).with(0).and_return(3)
      end
      it 'should clear row when product missing'
      it 'should update custom values'
    end
    it 'should update classification level items'
    it 'should update tariff level items'
  end

end
