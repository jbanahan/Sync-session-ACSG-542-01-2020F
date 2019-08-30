describe OpenChain::CustomHandler::LandsEnd::LeProductParser do
  let(:user) do
    u = Factory(:master_user)
    allow(u).to receive(:edit_products?).and_return true
    u
  end

  let(:cf) do 
    file = instance_double "CustomFile"
    allow(file).to receive(:attached_file_name).and_return "filename.xlsx"  
    file
  end

  describe "can_view?" do
    let(:ms) { stub_master_setup }

    before do
      allow(ms).to receive(:custom_feature?).with("Lands End Parts").and_return true
      cf
    end

    it "allows master user with edit permission when custom feature is present" do
      expect(described_class.can_view? user).to eq true
    end

    it "blocks non-master user" do
      user.company.update! master: false
      user.reload
      expect(described_class.can_view? user).to eq false
    end

    it "blocks user without edit permission" do
      allow(user).to receive(:edit_products?).and_return false
      expect(described_class.can_view? user).to eq false
    end

    it "returns 'false' if custom feature isn't present" do
      allow(ms).to receive(:custom_feature?).with("Lands End Parts").and_return false
      expect(described_class.can_view? user).to eq false
    end
  end

  describe "process" do
    let(:user) { Factory :user }

    subject { described_class.new cf }
    
    it "assigns completion message" do
      expect(subject).to receive(:process_file).with cf, user
      subject.process user
      expect(user.messages.length).to eq 1
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete"
      expect(m.body).to eq "Land's End Product Upload processing for file filename.xlsx is complete."
    end

    it "assigns error message" do
      expect(subject).to receive(:process_file).with(cf, user).and_raise "ERROR!!"
      subject.process user
      expect(user.messages.length).to eq 1
      m = user.messages.first
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "Unable to process file filename.xlsx due to the following error:<br>ERROR!!"
    end
  end

  describe "process_file" do
    let(:header) { ["Style_Nbr", "Style_Desc", "SKU_Nbr", "Vendor_Nbr", "Vendor_Name", "Factory_Nbr", "COO", "Exception_Cd", "Suffix_Ind", "Suffix_Desc", "HTS_Cd"] }
    let(:row_1) { ["2196", "WM MATERNITY 3Q SLVE FLIP CUFF STRETCH BLOUSE", "2521281", "3676", "LF MENS GROUP LLC", "", "ID", "", "", "", "6206.30.3041"] }
    let(:row_2) { ["2196", "WM MATERNITY 3Q SLVE FLIP CUFF STRETCH BLOUSE", "2521282", "3676", "LF MENS GROUP LLC", "", "ID", "", "", "", "6206.30.3041"] }
    let(:row_3) { ["51356", "COED LS INTERLOCK POLO - LK", "1963821", "2997", "SEARS.", "", "CN", "", "", "", "6105.10.0030"] }
    let(:row_4) { ["51356", "COED LS INTERLOCK POLO - LK", "1963822", "2997", "SEARS.", "", "CN", "", "", "", "6105.10.0031"] }
    let(:us) { Factory(:country, iso_code: "US") }
    let(:imp) { Factory(:company, system_code: "LANDS1") }
    subject { described_class.new cf }
    let(:cdefs) { subject.cdefs }
    before { us; cf; imp }

    it "parses products" do
      expect(subject).to receive(:foreach).with(cf, skip_headers: true).and_yield(row_1).and_yield(row_2).and_yield(row_3).and_yield(row_4)
      expect{ subject.process_file cf, user }.to change(Product, :count).from(0).to(2)
      p1, p2 = Product.all

      expect(p1.unique_identifier).to eq "LANDS1-2196"
      expect(p1.custom_value(cdefs[:prod_part_number])).to eq "2196"
      expect(p1.custom_value(cdefs[:prod_short_description])).to eq "WM MATERNITY 3Q SLVE FLIP CUFF STRETCH BLOUSE"
      expect(p1.classifications.length).to eq 1
      cl = p1.classifications.first
      expect(cl.country).to eq us
      expect(cl.tariff_records.length).to eq 1
      expect(cl.tariff_records.first.hts_1).to eq "6206303041"
      expect(p1.entity_snapshots.length).to eq 1
      es = p1.entity_snapshots.first
      expect(es.user).to eq user
      expect(es.context).to eq "LeProductParser"

      expect(p2.unique_identifier).to eq "LANDS1-51356"
      expect(p2.custom_value(cdefs[:prod_part_number])).to eq "51356"
      expect(p2.custom_value(cdefs[:prod_short_description])).to eq "COED LS INTERLOCK POLO - LK"
      expect(p2.classifications.length).to eq 1
      cl = p2.classifications.first
      expect(cl.country).to eq us
      expect(cl.tariff_records.length).to eq 0
      es = p2.entity_snapshots.first
      expect(es.user).to eq user
      expect(es.context).to eq "LeProductParser"
    end

    it "updates products" do
      expect(subject).to receive(:foreach).with(cf, skip_headers: true).and_yield(row_1).and_yield(row_2).and_yield(row_3).and_yield(row_4)
      expect{ subject.process_file cf, user }.to change(Product, :count).from(0).to(2)
      p1, p2 = Product.all

      row_1 = ["2196", "PERSONALIZED ORNAMENT", "4996236", "1706", "WHITE SWAN FINE PEWTER", "", "US", "", "", "", "9505.10.2500"]
      row_2 = ["2196", "PERSONALIZED ORNAMENT", "4996237", "1706", "WHITE SWAN FINE PEWTER", "", "US", "", "", "", "9505.10.2500"]
      row_3 = ["51356", "WM SS PLEATED SOFT BLOUSE", "3388954", "2594", "VENTURA ENTERPRISE CO INC", "", "LK", "", "", "", "6206.40.3030"]
      row_4 = ["51356", "WM SS PLEATED SOFT BLOUSE", "3388955", "2594", "VENTURA ENTERPRISE CO INC", "", "LK", "", "", "", "6206.40.3031"]

      expect(subject).to receive(:foreach).with(cf, skip_headers: true).and_yield(row_1).and_yield(row_2).and_yield(row_3).and_yield(row_4)
      expect{ subject.process_file cf, user }.to_not change(Product, :count)
      p1.reload; p2.reload

      expect(p1.unique_identifier).to eq "LANDS1-2196"
      expect(p1.custom_value(cdefs[:prod_part_number])).to eq "2196"
      expect(p1.custom_value(cdefs[:prod_short_description])).to eq "PERSONALIZED ORNAMENT"
      expect(p1.classifications.length).to eq 1
      cl = p1.classifications.first
      expect(cl.country).to eq us
      expect(cl.tariff_records.length).to eq 1
      expect(cl.tariff_records.first.hts_1).to eq "9505102500"
      expect(p1.entity_snapshots.length).to eq 2

      expect(p2.unique_identifier).to eq "LANDS1-51356"
      expect(p2.custom_value(cdefs[:prod_part_number])).to eq "51356"
      expect(p2.custom_value(cdefs[:prod_short_description])).to eq "WM SS PLEATED SOFT BLOUSE"
      expect(p2.classifications.length).to eq 1
      cl = p2.classifications.first
      expect(cl.country).to eq us
      expect(cl.tariff_records.length).to eq 0
      expect(p2.entity_snapshots.length).to eq 2
    end
  end

end
