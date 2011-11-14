require 'spec_helper'

describe Company do
  context 'security' do
    before :each do
      @c = Factory(:company)
      MasterSetup.get.update_attributes(:entry_enabled=>true)
    end
    it 'should allow master to view entries' do
      @c.master = true
      @c.save!
      @c.view_entries?.should be_true
    end
    it 'should not allow non-master to view entries' do
      @c.master = false
      @c.save!
      @c.view_entries?.should be_false
    end
  end
end
