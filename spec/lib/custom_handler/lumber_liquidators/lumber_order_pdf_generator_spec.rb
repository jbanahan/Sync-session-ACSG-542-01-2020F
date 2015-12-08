require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberOrderPdfGenerator do
  describe '#create!' do
    it 'should create pdf and attach to order' do
      Timecop.freeze(Time.now) do
        o = Factory(:order,order_number:'ABC')
        expect{described_class.create! o}.to change(Attachment,:count).from(0).to(1)
        o.reload
        
        att = o.attachments.first
        expect(att.attachment_type).to eq 'Order Printout'
        expect(att.attached_file_name).to eq "order_ABC_#{Time.now.strftime('%Y%m%d%H%M%S%L')}.pdf"
      end
    end
  end

  ##########################
  # NOT TESTING #render method 
  # which should be tested manually when modifying PDF generation
  ##########################
end