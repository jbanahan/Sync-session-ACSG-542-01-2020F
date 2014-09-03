require 'spec_helper'

describe OpenChain::CustomHandler::LandsEnd::LeReturnsCommercialInvoiceGenerator do

  def make_source_row data
    row = []
    row[22] = data[:coo]
    row[16] = data[:style]
    row[23] = data[:units]
    row[45] = data[:mid]
    row[46] = data[:hts]
    row[24] = data[:unit_price]
    row[9] = data[:po]

    row
  end

  def make_out_row file, data
    extract = []
    extract[0] = file # File #
    extract[1] = "LANDS" # Customer
    extract[2] = "1" # Invoice Number
    extract[3] = nil # Inv Date
    extract[4] = data[:coo] # C/O
    extract[5] = data[:style] # Style
    extract[6] = data[:units] # Units
    extract[7] = data[:mid] # MID
    extract[8] = data[:hts] # HTS
    extract[9] = nil # Cotton Fee
    extract[10] = BigDecimal.new(data[:unit_price].to_s) # Unit Price
    extract[11] = 1 # Qty 1
    extract[12] = nil  #Qty 2
    extract[13] = nil # Gross Weight
    extract[14] = data[:po] # PO #
    extract[15] = nil # Cartons
    extract[16] = 0 # First Sale
    extract[17] = nil # ndc/mmv
    extract[18] = nil # dept

    extract
  end

  describe "process_file" do
    it "converts file via xlcient from returns format to CI Load format" do
      g = described_class.new(nil)
      xl = double("XLClient")
      g.stub(:xl_client).with("s3_path").and_return xl
      values = [
        ["Header"], # Header is ignored
        make_source_row(coo: "CN ", style: " Style", units: 5.5, unit_price: 12.50, mid: "MID", hts: "1234.56.7890", po: "PO"),
        make_source_row(coo: "ZZ", style: 123, units: "5", unit_price: "1.50", mid: "MID2", hts: 98766543, po: 456.0)
      ]
      xl.should_receive(:all_row_values).and_yield(values[0]).and_yield(values[1]).and_yield(values[2])

      fout = StringIO.new
      fout.binmode

      g.process_file "s3_path", fout, "File#"

      fout.rewind
      wb = Spreadsheet.open fout
      sheet = wb.worksheets.find {|s| s.name == "Sheet1"}
      expect(sheet).not_to be_nil
      expect(sheet.row(0)).to eq ["File #", "Customer", "Inv#", "Inv Date", "C/O", "Part# / Style", "Pcs", "Mid", "Tariff#", "Cotton Fee y/n", "Value (IV)", "Qty#1", "Qty#2", "Gr wt", "PO#", "Ctns", "FIRST SALE", "ndc/mmv", "dept"]
      expect(sheet.row(1)).to eq make_out_row("File#", coo: "CN", style: "Style", units: 5, unit_price: 12.50, mid: "MID", hts: "1234567890", po: "PO")
      expect(sheet.row(2)).to eq make_out_row("File#", coo: "ZZ", style: "123", units: 5, unit_price: 1.50, mid: "MID2", hts: "98766543", po: "456")
    end
  end

  describe "generate_and_email" do

    it "generates CI load file and emails it" do
      cf = double("CustomFile")
      cf.stub(:attached).and_return cf
      cf.stub(:path).and_return "s3/path/file.txt"
      g = described_class.new cf

      g.should_receive(:process_file).with("s3/path/file.txt", instance_of(Tempfile), "12345") do |path, t, file|
        t << "Testing"
      end
      u = Factory(:user, email: "me@there.com")
      g.generate_and_email u, "12345"

      expect(ActionMailer::Base.deliveries.size).to eq 1
      m = ActionMailer::Base.deliveries.first
      expect(m.to).to eq [u.email]
      expect(m.subject).to eq "Lands' End CI Load File VFCI_12345"
      expect(m.body.raw_source).to include "Attached is the Lands' End CI Load file generated from file.txt.  Please verify the file contents before loading the file into the CI Load program."
      expect(m.attachments["VFCI_12345.xls"].read).to eq "Testing"

    end
  end

  describe "can_view?" do
    it "allows company master to view in www-vfitrack-net" do
      ms = double("MasterSetup")
      MasterSetup.should_receive(:get).and_return ms
      ms.should_receive(:system_code).and_return "www-vfitrack-net"

      u = Factory(:master_user)
      expect(described_class.new(nil).can_view? u).to be_true
    end

    it "prevents non-master user" do
      u = Factory(:user)
      expect(described_class.new(nil).can_view? u).to be_false
    end

    it "prevents non-vfitrack user" do
      ms = double("MasterSetup")
      MasterSetup.should_receive(:get).and_return ms
      ms.should_receive(:system_code).and_return "test"

      u = Factory(:master_user)
      expect(described_class.new(nil).can_view? u).to be_false
    end
  end
end