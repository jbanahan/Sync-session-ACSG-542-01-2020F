require 'spec_helper'

describe AttachmentProcessJob do
  before :each do
    @s = Factory(:shipment)
    @u = Factory(:user)
    @a = Factory(:attachment)
  end
  describe :validations do
    it "should fail on unknown job name" do
      j = described_class.new(attachable:@s,user:@u,attachment:@a)
      j.job_name = 'OTHER'
      expect{j.save}.to_not change(AttachmentProcessJob,:count)
      expect(j.errors.full_messages.to_a).to eq ['Job name is not recognized.']
    end
    it "should pass on known job name" do
      j = described_class.new(attachable:@s,user:@u,attachment:@a)
      j.job_name = 'Tradecard Pack Manifest'
      expect{j.save!}.to_not raise_error #this would raise exception if validation failed
    end
  end
  describe :process do
    before :each do
      @j = described_class.create!(attachable:@s,user:@u,attachment:@a,job_name:'Tradecard Pack Manifest')
      @tpm = OpenChain::CustomHandler::Tradecard::TradecardPackManifestParser
    end
    it "should delegate to process_attachment method based on job name" do
      @tpm.should_receive(:process_attachment).with(@s,@a,@u)
      @j.process
      @j.reload
      expect(@j.finish_at).to be > 1.minute.ago
    end
  end
end
