describe OpenChain::CustomHandler::LandsEnd::LeReturnsParser do

  subject { described_class.new nil }

  describe "process_file" do
    let (:custom_file) { instance_double(CustomFile) }
    let (:headers) { ["Client#", "Client Name", "Export Control#", "Export Date", "Reference#", "Ticket#", "Order #", "Returned By", "Address", "City", "Province", "Postal Code", "Part#", "Sub-Div#/Style#", "FactoryBot Code", "Description 1", "Description 2", "CDN HS Code", "US HS Code", "Origin", "Quantity", "Unit Price", "Total", "Date Imported to Canada", "Transaction Imported to Canada", "B3 Date", "Office Imported to Canada", "Duty on Importation", "GST on Importation", "HST/PST on Importation", "ExciseTax on Importation", "Days In Canada", "Order Date", "Date Return Processed"]}
    let (:first_row) {
      ["LANDS-EBO", "LANDS-EBO", "21571", nil, "ONDNX007922291", "LBO-191010-1 ", "64394301", "Hampton Inn & S", "Janet Pratt", "FREDERICTON", nil, "E3C 0B4", "4211928", "450650", "3625", "WR CS STR FIT STR CHN PNT", "WMS/GIRLS PANTS", "6204.62.00.19", "", "BD", "1", "28.11", "28.11", "17/06/2019", "15818-028267659", "17/06/2019", "453", "6.37", "2.19", "0", "0", "124", "14/06/2019", "16/10/2019"]
    }
    let! (:lands_end) { FactoryBot(:importer, system_code: "LANDS1") }
    let (:us) { FactoryBot(:country, iso_code: "US") }
    let! (:product) {
      p = FactoryBot(:product, importer: lands_end, unique_identifier: "LANDS1-4211928")
      p.update_hts_for_country(us, "1234567890")
      p
    }
    let! (:mid) {
      DataCrossReference.add_xref!('mid_xref', '3625', 'BDMID', lands_end.id)
    }

    it "adds COO, MID, HTS to custom file data"  do
      expect(subject).to receive(:foreach).with(custom_file, {skip_headers: false}).and_yield(headers).and_yield(first_row)
      builder = subject.process_file custom_file
      data = xlsx_data(builder, sheet_name: "Merged Product Data")
      expect(data[0]).to eq (["CSV Line #", "Status", "Sequence"] + headers + ["COO", "MID", "HTS_NBR", "COMMENTS"])
      expect(data[1][0..2]).to eq [2, "Exact Match", 1]

      # Validate the date / decimal converted columns are as expected..
      expect(data[1][23]).to eq 1
      expect(data[1][24]).to eq 28.11
      expect(data[1][25]).to eq 28.11
      expect(data[1][26]).to eq Date.new(2019, 6, 17)
      expect(data[1][28]).to eq Date.new(2019, 6, 17)
      expect(data[1][30]).to eq 6.37
      expect(data[1][31]).to eq 2.19
      expect(data[1][32]).to eq 0
      expect(data[1][33]).to eq 0
      expect(data[1][34]).to eq 124
      expect(data[1][35]).to eq Date.new(2019, 6, 14)
      expect(data[1][36]).to eq Date.new(2019, 10, 16)

      # Validate the added fields
      expect(data[1][37]).to eq "BD"
      expect(data[1][38]).to eq "BDMID"
      expect(data[1][39]).to eq "1234567890"
    end

    it "adds an error if product isn't found" do
      product.update! unique_identifier: "MISSING"

      expect(subject).to receive(:foreach).with(custom_file, {skip_headers: false}).and_yield(headers).and_yield(first_row)
      builder = subject.process_file custom_file
      d = XlsxTestReader.new builder
      data = d.raw_data("Merged Product Data")
      expect(data[1][0..2]).to eq [2, "No matching Part Number.", 1]
      expect(d.background_color("Merged Product Data", 1, 0)).to eq "FFFFFF66"
      expect(d.number_format("Merged Product Data", 1, 26)).to eq "YYYY-MM-DD"
      expect(d.number_format("Merged Product Data", 1, 28)).to eq "YYYY-MM-DD"
      expect(d.number_format("Merged Product Data", 1, 35)).to eq "YYYY-MM-DD"
      expect(d.number_format("Merged Product Data", 1, 36)).to eq "YYYY-MM-DD"
    end

    it "adds an error if MID isn't found" do
      mid.destroy

      expect(subject).to receive(:foreach).with(custom_file, {skip_headers: false}).and_yield(headers).and_yield(first_row)
      builder = subject.process_file custom_file
      data = xlsx_data(builder, sheet_name: "Merged Product Data")

      expect(data[1][0..2]).to eq [2, "No matching MID.", 1]
    end

    it "adds an error if COO isn't found" do
      first_row[19] = ""

      expect(subject).to receive(:foreach).with(custom_file, {skip_headers: false}).and_yield(headers).and_yield(first_row)
      builder = subject.process_file custom_file
      data = xlsx_data(builder, sheet_name: "Merged Product Data")

      expect(data[1][0..2]).to eq [2, "No Country of Origin.", 1]
    end
  end

  describe "process" do
    let (:custom_file) { instance_double(CustomFile) }
    let! (:path) {
      allow(custom_file).to receive(:attached_file_name).and_return "file.csv"
    }
    let (:builder) {
      b = instance_double(XlsxBuilder)
      allow(b).to receive(:output_format).and_return "xlsx"
      # We need to write something to the tempfile, otherwise the mailer will strip the attachment.
      allow(b).to receive(:write) do |tempfile|
        tempfile << "testing"
        tempfile.flush
      end
      b
    }
    let (:user) { FactoryBot(:user, email:"me@there.com") }

    before :each do
      allow(subject).to receive(:custom_file).and_return custom_file
    end

    it "processes custom file" do
      allow(subject).to receive(:process_file).with(custom_file).and_return builder
      subject.process user

      expect(ActionMailer::Base.deliveries.length).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "Lands' End Returns File 'file.xlsx'"
      expect(m.body).to include "Attached is the Lands' End returns file generated from file.csv.  Please correct all yellow lines in the attached file and upload corrections to VFI Track."
      expect(m.attachments["file.xlsx"]).not_to be_nil

      m = user.messages.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "File Processing Complete"
      expect(m.body).to eq "Land's End Product Upload processing for file file.csv is complete."
    end
  end

  describe "can_view?" do

    let (:master_user) { FactoryBot(:master_user) }
    let! (:master_setup) {
      ms = stub_master_setup
      allow(ms).to receive(:custom_feature?).with("WWW VFI Track Reports").and_return custom_feature_enabled
      ms
    }

    context "with www custom feature" do
      let (:custom_feature_enabled) { true }

      it "allows master users on the WWW system" do
        expect(subject.can_view?(master_user)).to eq true
      end

      it "does not allow standard users" do
        expect(subject.can_view?(FactoryBot(:user))).to eq false
      end
    end

    context "without www custom feature" do
      let (:custom_feature_enabled) { false }

      it "does not allow master users" do
        expect(subject.can_view?(master_user)).to eq false
      end
    end

  end
end