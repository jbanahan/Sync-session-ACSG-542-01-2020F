describe OpenChain::CustomHandler::LandsEnd::LeReturnsCommercialInvoiceGenerator do

  subject { described_class.new nil }

  describe "process" do
    let (:custom_file) { 
      cf = instance_double(CustomFile)
      allow(cf).to receive(:attached_file_name).and_return "file.xlsx"
      cf
    }

    let (:user) { Factory(:user, email: "me@there.com") }

    let (:body_row) { 
      ["2", "Match", "1", "LANDS-EBO", "LANDS-EBO", "21571", nil, "ONDNX007922291", "LBO-191010-1 ", "64394301", "Hampton Inn & S", "Janet Pratt", "FREDERICTON", nil, "E3C 0B4", "4211928", "450650", "3625", "WR CS STR FIT STR CHN PNT", "WMS/GIRLS PANTS", "6204.62.00.19", "6204.62.40.21", "BD", 1, 28.11, 28.11, Date.new(2019, 12, 1), "15818-028267659", Date.new(2019, 12, 2), "453", 6.37, 2.19, 0, 0, "124", Date.new(2019, 12, 3), Date.new(2019, 12, 4), "BD", "BDMID", "6204624021", nil]
    }

    before :each do 
      allow(subject).to receive(:custom_file).and_return custom_file
    end

    it "reads data from CustomFile and transforms it to CI Load format" do
      expect(subject).to receive(:foreach).with(custom_file, skip_headers: true).and_yield body_row

      subject.process(user, {file_number: "12345"})

      expect(ActionMailer::Base.deliveries.length).to eq 1

      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq ["me@there.com"]
      expect(m.subject).to eq "Lands' End CI Load File VFCI_12345"
      expect(m.body).to include "Attached is the Lands' End CI Load file generated from file.xlsx.  Please verify the file contents before loading the file into the CI Load program."
      expect(m.attachments["VFCI_12345.xlsx"]).not_to be_nil

      io = StringIO.new
      io.write m.attachments["VFCI_12345.xlsx"].read
      io.rewind
      data = xlsx_data(io, sheet_name: "Sheet1")
      expect(data[0]).to eq ["File #", "Customer", "Inv#", "Inv Date", "C/O", "Part# / Style", "Pcs", "Mid", "Tariff#", "Cotton Fee y/n", "Value (IV)", "Qty#1", "Qty#2", "Gr wt", "PO#", "Ctns", "FIRST SALE", "ndc/mmv", "dept"]
      expect(data[1]).to eq ["12345", "LANDS", "1", nil, "BD", "4211928", 1, "BDMID", "6204624021", nil, 28.11, 1, nil, nil, "64394301", nil, 0, nil, nil]
    end
  end

  describe "can_view?" do

    let (:master_user) { Factory(:master_user) }
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
        expect(subject.can_view?(Factory(:user))).to eq false
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