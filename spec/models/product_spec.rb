require 'spec_helper'

describe Product do
  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      product = Factory(:product)
      linkable = Factory(:linkable_attachment,:model_field_uid=>'prod',:value=>'ordn')
      linked = LinkedAttachment.create(:linkable_attachment_id=>linkable.id,:attachable=>product)
      product.reload
      product.linkable_attachments.first.should == linkable
    end
  end
end
