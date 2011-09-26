require 'spec_helper'

describe Delivery do
  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      s = Factory(:delivery,:reference=>'ordn')
      linkable = Factory(:linkable_attachment,:model_field_uid=>'del_reference',:value=>'ordn')
      linked = LinkedAttachment.create(:linkable_attachment_id=>linkable.id,:attachable=>s)
      s.reload
      s.linkable_attachments.first.should == linkable
    end
  end
end
