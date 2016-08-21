require 'spec_helper'

describe SearchColumn do
  describe 'key_column?' do
    it 'should be a key column' do
      expect(SearchColumn.new(:model_field_uid=>'prod_uid')).to be_key_column
    end
    it 'should not be a key column' do
      expect(SearchColumn.new(:model_field_uid=>'ord_ord_date')).not_to be_key_column
    end
  end
end
