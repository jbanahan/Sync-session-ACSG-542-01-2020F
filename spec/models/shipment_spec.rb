require 'spec_helper'

describe Shipment do
  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      s = Factory(:shipment,:reference=>'ordn')
      linkable = Factory(:linkable_attachment,:model_field_uid=>'shp_ref',:value=>'ordn')
      linked = LinkedAttachment.create(:linkable_attachment_id=>linkable.id,:attachable=>s)
      s.reload
      s.linkable_attachments.first.should == linkable
    end
  end
end
