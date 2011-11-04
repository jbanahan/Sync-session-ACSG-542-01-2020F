require 'spec_helper'

describe SearchColumn do
  describe 'key_column?' do
    it 'should be a key column' do
      SearchColumn.new(:model_field_uid=>'prod_uid').should be_key_column
    end
    it 'should not be a key column' do
      SearchColumn.new(:model_field_uid=>'ord_ord_date').should_not be_key_column
    end
  end
end
