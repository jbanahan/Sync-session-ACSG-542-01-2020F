require 'spec_helper'

describe OpenChain::CustomHandler::DutyCalc::ExportHistoryParser do
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
        att.attachable.drawback_export_histories.create!
        expect{described_class.process_excel_from_attachment(att,@u)}.to change(@u.messages,:count).from(0).to(1)
        expect(@u.messages.first.body).to match /already has DrawbackExportHistory records/
      end
    end
    it "should call parse_excel" do
      DrawbackClaim.any_instance.stub(:can_edit?).and_return true
      att = Factory(:attachment,attachable:Factory(:drawback_claim))
      x = double(:xl_client)
      p = double(:export_history_parser)
      OpenChain::XLClient.should_receive(:new_from_attachable).with(att).and_return(x)
      described_class.should_receive(:new).and_return(p)
      p.should_receive(:parse_excel).with(x)
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
      p.should_receive(:process_rows).with([rows[1],rows[2]])
      p.parse_excel(@xlc)
    end
  end
  describe :parse_csv do
    before :each do
      @data = <<DTA 
"Part NumberExported","Reference 1i.e. AWB #","Reference 2i.e. Invoice","ShipDate","QuantityExported","Dest.Country","DrawbackClaim Number","Average DrawbackEach Item",Reference 3,Exporter,Total
1010510,1Z7R65572002792187,15818-017643321,,10/12/2010,1,CA,31670523013,Lands,1.4949,1.49
1010519,1Z7R65572003073390,15818-017643332,,11/04/2010,1,CA,31670523013,Lands,1.782,1.78
DTA
    end
    it "should create records" do
      expect {described_class.new.parse_csv @data}.to change(DrawbackExportHistory,:count).from(0).to(2)
      d1 = DrawbackExportHistory.first
      expect(d1.part_number).to eq '1010510'
      expect(d1.export_ref_1).to eq '1Z7R65572002792187'
      expect(d1.export_date).to eq Date.new(2010,10,12)
      expect(d1.quantity).to eq 1
      expect(d1.drawback_claim).to be_nil
      expect(d1.claim_amount_per_unit).to eq BigDecimal('1.4949')
      expect(d1.claim_amount).to eq BigDecimal('1.49')
    end
    it "should ignore lines without 11 elements" do
      @data.gsub!(',1.78','')
      expect {described_class.new.parse_csv @data}.to change(DrawbackExportHistory,:count).from(0).to(1)
    end
    it "should match to existing drawback claim" do
      dc = Factory(:drawback_claim,entry_number:'31670523013')
      expect {described_class.new.parse_csv @data}.to change(DrawbackExportHistory,:count).from(0).to(2)
      expect(dc.drawback_export_histories.count).to eq 2
    end
  end
end