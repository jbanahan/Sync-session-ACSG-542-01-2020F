require 'spec_helper'

describe OpenChain::CustomHandler::DutyCalc::ClaimAuditParser do
  describe :parse do
    before :each do
      @data = <<DTA 
Export Date,Produced Date,Import Date,Rcvd Date,Mfg Date,Import Part,Export Part,7501,Qty Claimed,Export Ref 1,Import Ref 1
10/12/2010,10/12/2010,1010510,1010510,23171978003,07/18/2008,07/18/2008,07/18/2008,1,1Z7R65572002792187,402931
11/04/2010,11/04/2010,1010519,1010519,23171887816,05/24/2008,05/24/2008,05/24/2008,1,1Z7R65572003073390,401876
DTA
      @claim_number = '1234'
    end
    it "should create Claim Audits" do
      expect {described_class.new.parse(@data,@claim_number)}.to change(DrawbackClaimAudit,:count).from(0).to(2)
      d = DrawbackClaimAudit.first
      expect(d.drawback_claim).to be_nil
      expect(d.export_date).to eq Date.new(2010,10,12)
      expect(d.import_date).to eq Date.new(2008,7,18)
      expect(d.import_part_number).to eq '1010510'
      expect(d.export_part_number).to eq '1010510'
      expect(d.import_entry_number).to eq '23171978003'
      expect(d.quantity).to eq 1
      expect(d.export_ref_1).to eq '1Z7R65572002792187'
      expect(d.import_ref_1).to eq '402931'
    end
    it "should skip rows without 11 item and a value in the last position" do
      @data.gsub!(',401876','')
      expect {described_class.new.parse(@data,@claim_number)}.to change(DrawbackClaimAudit,:count).from(0).to(1)
    end
    it "should match an existing drawback claim" do
      c = Factory(:drawback_claim,entry_number:@claim_number)
      expect {described_class.new.parse(@data,@claim_number)}.to change(DrawbackClaimAudit,:count).from(0).to(2)
      d = DrawbackClaimAudit.first
      expect(d.drawback_claim).to eq c
    end
  end
end