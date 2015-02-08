require 'spec_helper'

describe OpenChain::CustomHandler::DutyCalc::ClaimAuditParser do
  describe :process_excel_from_attachment do
    before :each do
      @u = Factory(:user)
    end
    context :errors do
      before :each do
        described_class.any_instance.should_not_receive(:parse_excel)
      end
      it "must be attached to a DrawbackClaim" do
        att = Factory(:attachment,attachable:Factory(:order))
        expect{described_class.process_excel_from_attachment(att,@u)}.to change(@u.messages,:count).from(0).to(1)
        expect(@u.messages.first.body).to match /is not attached to a DrawbackClaim/
      end
      it "must be a user who can edit the claim" do
        att = Factory(:attachment,attachable:Factory(:drawback_claim))
        DrawbackClaim.any_instance.stub(:can_edit?).and_return false
        expect{described_class.process_excel_from_attachment(att,@u)}.to change(@u.messages,:count).from(0).to(1)
        expect(@u.messages.first.body).to match /cannot edit DrawbackClaim/
      end
      it "must not have existing export history lines for the claim" do
        DrawbackClaim.any_instance.stub(:can_edit?).and_return true
        att = Factory(:attachment,attachable:Factory(:drawback_claim))
        att.attachable.drawback_claim_audits.create!
        expect{described_class.process_excel_from_attachment(att,@u)}.to change(@u.messages,:count).from(0).to(1)
        expect(@u.messages.first.body).to match /already has DrawbackClaimAudit records/
      end
    end
    it "should call parse_excel" do
      DrawbackClaim.any_instance.stub(:can_edit?).and_return true
      att = Factory(:attachment,attachable:Factory(:drawback_claim,entry_number:'12345678901'))
      x = double(:xl_client)
      p = double(:claim_audit_parser)
      OpenChain::XLClient.should_receive(:new_from_attachable).with(att).and_return(x)
      described_class.should_receive(:new).and_return(p)
      p.should_receive(:parse_excel).with(x,'12345678901')
      expect{described_class.process_excel_from_attachment(att,@u)}.to change(@u.messages,:count).from(0).to(1)
      expect(@u.messages.first.body).to match /success/
    end
  end
  describe :parse_excel do
    before :each do
      @xlc = double(:xl_client)
    end
    it "should receive rows" do
      rows = [[1,2,3,4,5],[1,2,3,4,5,6,7,8,9,0,1],[1,2,3,4,5,6,7,8,9,0,1]]
      @xlc.stub(:all_row_values,0).and_yield(rows[0]).and_yield(rows[1]).and_yield(rows[2])
      p = described_class.new
      p.should_receive(:process_rows).with([rows[1],rows[2]],'12345')
      p.parse_excel(@xlc,'12345')
    end
  end
  describe :parse_csv do
    before :each do
      @data = <<DTA 
Export Date,Produced Date,Import Date,Rcvd Date,Mfg Date,Import Part,Export Part,7501,Qty Claimed,Export Ref 1,Import Ref 1
10/12/2010,10/12/2010,1010510,1010510,23171978003,07/18/2008,07/18/2008,07/18/2008,1,1Z7R65572002792187,402931
11/04/2010,11/04/2010,1010519,1010519,23171887816,05/24/2008,05/24/2008,05/24/2008,1,1Z7R65572003073390,401876
DTA
      @claim_number = '1234'
    end
    it "should create Claim Audits" do
      expect {described_class.new.parse_csv(@data,@claim_number)}.to change(DrawbackClaimAudit,:count).from(0).to(2)
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
      expect {described_class.new.parse_csv(@data,@claim_number)}.to change(DrawbackClaimAudit,:count).from(0).to(1)
    end
    it "should match an existing drawback claim" do
      c = Factory(:drawback_claim,entry_number:@claim_number)
      expect {described_class.new.parse_csv(@data,@claim_number)}.to change(DrawbackClaimAudit,:count).from(0).to(2)
      d = DrawbackClaimAudit.first
      expect(d.drawback_claim).to eq c
    end
  end
end