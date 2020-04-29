describe OpenChain::CustomHandler::DutyCalc::ExportHistoryParser do
  describe "process_from_attachment" do
    before :each do
      @u = Factory(:user)
    end
    context "errors" do
      before :each do
        expect_any_instance_of(described_class).not_to receive(:parse_excel)
      end
      it "must be attached to a DrawbackClaim" do
        att = Factory(:attachment, attachable:Factory(:order), attached_file_name:'hello.xlsx')
        expect {described_class.process_from_attachment(att.id, @u.id)}.to change(@u.messages, :count).from(0).to(1)
        expect(@u.messages.first.body).to match /is not attached to a DrawbackClaim/
      end
      it "must be a user who can edit the claim" do
        att = Factory(:attachment, attachable:Factory(:drawback_claim), attached_file_name:'hello.xlsx')
        allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return false
        expect {described_class.process_from_attachment(att.id, @u.id)}.to change(@u.messages, :count).from(0).to(1)
        expect(@u.messages.first.body).to match /cannot edit DrawbackClaim/
      end
      it "must not have existing export history lines for the claim" do
        allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return true
        att = Factory(:attachment, attachable:Factory(:drawback_claim), attached_file_name:'hello.xlsx')
        att.attachable.drawback_export_histories.create!
        expect {described_class.process_from_attachment(att.id, @u.id)}.to change(@u.messages, :count).from(0).to(1)
        expect(@u.messages.first.body).to match /already has DrawbackExportHistory records/
      end
    end
    it "should call parse_excel" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return true
      claim = Factory(:drawback_claim)
      att = Factory(:attachment, attachable:claim, attached_file_name:'something.xlsx')
      x = double(:xl_client)
      p = double(:export_history_parser)
      expect(OpenChain::XLClient).to receive(:new_from_attachable).with(att).and_return(x)
      expect(described_class).to receive(:new).and_return(p)
      expect(p).to receive(:parse_excel).with(x, claim)
      expect {described_class.process_from_attachment(att.id, @u.id)}.to change(@u.messages, :count).from(0).to(1)
      expect(@u.messages.first.body).to match /success/
    end
    it "should call parse CSV" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return true
      claim = Factory(:drawback_claim)
      att = Factory(:attachment, attachable:claim, attached_file_name:'something.csv')
      p = double(:export_history_parser)
      expect(described_class).to receive(:new).and_return(p)
      expect(p).to receive(:parse_csv_from_attachment).with(att, claim)
      expect {described_class.process_from_attachment(att.id, @u.id)}.to change(@u.messages, :count).from(0).to(1)
      expect(@u.messages.first.body).to match /success/
    end
    it "should fail if not xlsx or csv" do
      allow_any_instance_of(DrawbackClaim).to receive(:can_edit?).and_return true
      claim = Factory(:drawback_claim)
      att = Factory(:attachment, attachable:claim, attached_file_name:'something.txt')
      expect {described_class.process_from_attachment(att.id, @u.id)}.to change(@u.messages, :count).from(0).to(1)
      expect(@u.messages.first.body).to match /Invalid file format/
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
      expect(p).to receive(:parse_csv).with('y', claim)

      p.parse_csv_from_attachment(att, claim)
    end
  end
  describe "parse_excel" do
    it "should receive rows" do
      xlc = double(:xl_client)
      rows = [[1, 2, 3, 4, 5], [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1], [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1]]
      allow(xlc).to receive(:all_row_values).and_yield(rows[0]).and_yield(rows[1]).and_yield(rows[2])

      dc = double('drawback_claim')

      p = described_class.new
      expect(p).to receive(:process_rows).with([rows[1], rows[2]], dc)
      p.parse_excel(xlc, dc)
    end
  end
  describe "parse_csv" do
    before :each do
      @data = <<DTA
"Part NumberExported","Reference 1i.e. AWB #","Reference 2i.e. Invoice","ShipDate","QuantityExported","Dest.Country","DrawbackClaim Number","Average DrawbackEach Item",Reference 3,Exporter,Total
1010510,1Z7R65572002792187,15818-017643321,,10/12/2010,1,CA,31670523013,Lands,1.4949,1.49
1010519,1Z7R65572003073390,15818-017643332,,11/04/2010,1,CA,31670523013,Lands,1.782,1.78
DTA
      @dc = Factory(:drawback_claim, entry_number:'316-7052301-3')
    end
    it "should create records" do
      expect { described_class.new.parse_csv(@data, @dc) }.to change(DrawbackExportHistory, :count).from(0).to(2)
      d1 = DrawbackExportHistory.first
      expect(d1.part_number).to eq '1010510'
      expect(d1.export_ref_1).to eq '1Z7R65572002792187'
      expect(d1.export_date).to eq Date.new(2010, 10, 12)
      expect(d1.quantity).to eq 1
      expect(d1.drawback_claim).to eq @dc
      expect(d1.claim_amount_per_unit).to eq BigDecimal('1.4949')
      expect(d1.claim_amount).to eq BigDecimal('1.49')
    end
    it "should ignore lines without 11 elements" do
      @data.gsub!(',1.78', '')
      expect {described_class.new.parse_csv @data, @dc}.to change(DrawbackExportHistory, :count).from(0).to(1)
    end
    it "should raise error if claim entry number doesn't match passed in claim" do
      bad_dc = Factory(:drawback_claim, entry_number:'31670523XXX')
      expect {described_class.new.parse_csv @data, bad_dc}.to raise_error(/Claim number/)
    end
  end
end
