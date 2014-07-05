require 'spec_helper'

describe OpenChain::CustomHandler::DutyCalc::ExportHistoryParser do
  describe :parse do
    before :each do
      @data = <<DTA 
"Part NumberExported","Reference 1i.e. AWB #","Reference 2i.e. Invoice","ShipDate","QuantityExported","Dest.Country","DrawbackClaim Number","Average DrawbackEach Item",Reference 3,Exporter,Total
1010510,1Z7R65572002792187,15818-017643321,,10/12/2010,1,CA,31670523013,Lands,1.4949,1.49
1010519,1Z7R65572003073390,15818-017643332,,11/04/2010,1,CA,31670523013,Lands,1.782,1.78
DTA
    end
    it "should create records" do
      expect {described_class.new.parse @data}.to change(DrawbackExportHistory,:count).from(0).to(2)
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
      expect {described_class.new.parse @data}.to change(DrawbackExportHistory,:count).from(0).to(1)
    end
    it "should match to existing drawback claim" do
      dc = Factory(:drawback_claim,entry_number:'31670523013')
      expect {described_class.new.parse @data}.to change(DrawbackExportHistory,:count).from(0).to(2)
      expect(dc.drawback_export_histories.count).to eq 2
    end
  end
end