require 'spec_helper'

describe Order do

  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      o = Factory(:order,:order_number=>'ordn')
      linkable = Factory(:linkable_attachment,:model_field_uid=>'ord_ord_num',:value=>'ordn')
      linked = LinkedAttachment.create(:linkable_attachment_id=>linkable.id,:attachable=>o)
      o.reload
      o.linkable_attachments.first.should == linkable
    end
  end

end
