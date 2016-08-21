require 'spec_helper'

describe OpenChain::CustomHandler::DutyCalc::ClaimAuditParser do
  describe "process_from_attachment" do
    before :each do
      @u = Factory(:user)
    end
    context "errors" do
      before :each do
        expect_any_instance_of(described_class).not_to receive(:parse_excel)
      end
      it "must be attached to a DrawbackClaim" do
        att = Factory(:attachment,attachable:Factory(:order),attached_file_name:'a.xlsx')
        expect{described_class.process_from_attachment(att,@u)}.to change(@u.messages,:count).from(0).to(1)
        expect(@u.messages.first.body).to match /is not attached to a DrawbackClaim/
      end
      it "must be a user who can edit the claim" do
        att = Factory(:attachment,attachable:Factory(:drawback_claim),attached_file_name:'a.xlsx')
        allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return false
        expect{described_class.process_from_attachment(att,@u)}.to change(@u.messages,:count).from(0).to(1)
        expect(@u.messages.first.body).to match /cannot edit DrawbackClaim/
      end
      it "must not have existing export history lines for the claim" do
        allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return true
        att = Factory(:attachment,attachable:Factory(:drawback_claim),attached_file_name:'a.xlsx')
        att.attachable.drawback_claim_audits.create!
        expect{described_class.process_from_attachment(att,@u)}.to change(@u.messages,:count).from(0).to(1)
        expect(@u.messages.first.body).to match /already has DrawbackClaimAudit records/
      end
    end
    it "should call parse_excel" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return true
      dc = Factory(:drawback_claim,entry_number:'12345678901')
      att = Factory(:attachment,attachable:dc,attached_file_name:'a.xlsx')
      x = double(:xl_client)
      p = double(:claim_audit_parser)
      expect(OpenChain::XLClient).to receive(:new_from_attachable).with(att).and_return(x)
      expect(described_class).to receive(:new).and_return(p)
      expect(p).to receive(:parse_excel).with(x,dc)
      expect{described_class.process_from_attachment(att.id,@u.id)}.to change(@u.messages,:count).from(0).to(1)
      expect(@u.messages.first.body).to match /success/
    end
    it "should call parse_csv_from_attachment" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return true
      dc = Factory(:drawback_claim,entry_number:'12345678901')
      att = Factory(:attachment,attachable:dc,attached_file_name:'a.csv')
      p = double(:claim_audit_parser)
      expect(described_class).to receive(:new).and_return(p)
      expect(p).to receive(:parse_csv_from_attachment).with(att,dc)
      expect{described_class.process_from_attachment(att.id,@u.id)}.to change(@u.messages,:count).from(0).to(1)
      expect(@u.messages.first.body).to match /success/
    end
    it "should fail if not csv or xlsx" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return true
      dc = Factory(:drawback_claim,entry_number:'12345678901')
      att = Factory(:attachment,attachable:dc,attached_file_name:'a.txt')
      expect{described_class.process_from_attachment(att.id,@u.id)}.to change(@u.messages,:count).from(0).to(1)
      expect(@u.messages.first.body).to match /Invalid file format/
    end
  end
  describe "parse_excel" do
    before :each do
      @xlc = double(:xl_client)
    end
    it "should receive rows" do
      drawback_claim = double('dc')
      rows = [[1,2,3,4,5],[1,2,3,4,5,6,7,8,9,0,1],[1,2,3,4,5,6,7,8,9,0,1]]
      allow(@xlc).to receive(:all_row_values).with(0).and_yield(rows[0]).and_yield(rows[1]).and_yield(rows[2])
      p = described_class.new
      expect(p).to receive(:process_rows).with([rows[1],rows[2]],drawback_claim)
      p.parse_excel(@xlc,drawback_claim)
    end
  end
  describe "parse_csv_from_attachment" do
    it "should download attachment" do
      claim = double('claim')
      att = Factory(:attachment)
      tmp = double('tempfile')
      expect(tmp).to receive(:path).and_return('x')
      expect(att).to receive(:download_to_tempfile).and_yield(tmp)
      expect(IO).to receive(:read).with('x').and_return('y')
      p = described_class.new
      expect(p).to receive(:parse_csv).with('y',claim)

      p.parse_csv_from_attachment(att,claim)
    end
  end
  describe "parse_csv" do
    before :each do
      @data = <<DTA 
Export Date,Produced Date,Import Date,Rcvd Date,Mfg Date,Import Part,Export Part,7501,Qty Claimed,Export Ref 1,Import Ref 1
10/12/2010,10/12/2010,1010510,1010510,23171978003,07/18/2008,07/18/2008,07/18/2008,1,1Z7R65572002792187,402931
11/04/2010,11/04/2010,1010519,1010519,23171887816,05/24/2008,05/24/2008,05/24/2008,1,1Z7R65572003073390,401876
DTA
      @dc = Factory(:drawback_claim,entry_number:'1234567890')
    end
    it "should create Claim Audits" do
      expect {described_class.new.parse_csv(@data,@dc)}.to change(DrawbackClaimAudit,:count).from(0).to(2)
      d = DrawbackClaimAudit.first
      expect(d.drawback_claim).to eq @dc
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
      expect {described_class.new.parse_csv(@data,@dc)}.to change(DrawbackClaimAudit,:count).from(0).to(1)
    end
  end
end