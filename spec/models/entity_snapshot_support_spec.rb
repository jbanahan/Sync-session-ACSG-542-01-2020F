require 'spec_helper'

describe 'entity snapshot support' do
  before :each do 
    ModelField.reload
  end
  describe :create_snapshot do
    it 'should update last_updated_by when create_snapshot is called' do
      u = Factory(:user)
      p = Factory(:product)
      p.last_updated_by.should be_nil
      p.create_snapshot u
      Product.find(p.id).last_updated_by.should == u
    end
    it 'should not update last_updated_by if it does not exist for the parent object' do
      u = Factory(:user)
      s = Factory(:shipment)
      s.create_snapshot u #shouldn't blow up
    end
  end
end
