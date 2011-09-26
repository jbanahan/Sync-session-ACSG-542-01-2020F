require 'spec_helper'

describe SalesOrder do

  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      s = Factory(:sales_order,:order_number=>'ordn')
      linkable = Factory(:linkable_attachment,:model_field_uid=>'sale_order_number',:value=>'ordn')
      linked = LinkedAttachment.create(:linkable_attachment_id=>linkable.id,:attachable=>s)
      s.reload
      s.linkable_attachments.first.should == linkable
    end
  end

end
