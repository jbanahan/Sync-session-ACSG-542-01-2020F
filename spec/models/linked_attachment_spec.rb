require 'spec_helper'

describe LinkedAttachment do
  context 'validations' do
    it 'should require an attachable' do
      a = LinkedAttachment.create(:linkable_attachment=>Factory(:linkable_attachment))
      a.errors.full_messages.should have(1).message
    end
    it 'should require a linkable attachment' do
      a = LinkedAttachment.create(:attachable=>Factory(:product))
      a.errors.full_messages.should have(1).message
    end
    it 'should save with an attachable and linkable attachment' do
      a = LinkedAttachment.create(:attachable=>Factory(:product),:linkable_attachment=>Factory(:linkable_attachment))
      a.errors.should be_empty
    end
  end

  describe 'static creators' do
    before(:each) do
      non_matching_linkable = Factory(:linkable_attachment)
      non_matching_attachable = Factory(:product)
    end

    describe 'create_from_attachable' do
      before(:each) do 
        @product = Factory(:product,:unit_of_measure=>'uom')
      end
      it 'should do nothing with no matching linkable attachments' do
        r = LinkedAttachment.create_from_attachable(Factory(:product))
        r.should have(0).items
        LinkedAttachment.all.should have(0).items
      end
      it 'should create 1 with 1 matching linkable attachment' do
        linkable = Factory(:linkable_attachment,:model_field_uid=>'prod_uid',:value=>@product.unique_identifier)
        r = LinkedAttachment.create_from_attachable(@product)
        r.should have(1).items
        linked = r.first
        linked.linkable_attachment.should == linkable
        linked.attachable.should == @product
      end
      it 'should create 2 with 2 matching linkable attachments on different model fields' do
        linkables = []
        {'prod_uid'=>@product.unique_identifier,'prod_uom'=>@product.unit_of_measure}.each {|k,v| linkables << Factory(:linkable_attachment,:model_field_uid=>k,:value=>v)}
        r = LinkedAttachment.create_from_attachable(@product)
        r.should have(2).items
        r.each do |linked|
          linkables.should include(linked.linkable_attachment)
          linked.attachable.should == @product
        end
      end
      it 'should do nothing if already linked to all potential matches' do
        2.times {|i| Factory(:linkable_attachment,:model_field_uid=>'prod_uid',:value=>@product.unique_identifier)}
        LinkedAttachment.create_from_attachable(@product) #first time does matching
        LinkedAttachment.create_from_attachable(@product).should be_empty  #second time does nothing
        LinkedAttachment.all.should have(2).items
      end
      it 'should only query for matching mf_uids in linkable_attachments table' do
        #this is a pretty bad test for internal functionality, but if it goes red, you should make sure you haven't made the method to inefficient
        LinkableAttachment.should_receive(:model_field_uids).and_return([])
        LinkedAttachment.create_from_attachable @product
      end
    end
    describe 'create_from_linkable_attachment' do
      before(:each) do 
        @product = Factory(:product)
        @linkable = Factory(:linkable_attachment,:model_field_uid=>'prod_uid',:value=>@product.unique_identifier)
      end
      it 'should create 1 with 1 matching attachable' do
        found = LinkedAttachment.create_from_linkable_attachment @linkable
        found.should have(1).item
        found.first.attachable.should == @product
        found.first.linkable_attachment == @linkable
      end
      it 'should create 2 with 2 matching attachables'
      it 'should do nothing with no matching attachable'
      it 'should do nothing if already linked to all potential matches'
    end
  end
end
