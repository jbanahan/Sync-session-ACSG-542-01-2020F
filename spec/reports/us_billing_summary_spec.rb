describe OpenChain::Report::UsBillingSummary do
  
  let(:user) { Factory(:master_user) }

  let(:date1) { DateTime.new 2019,3,15 }
  let(:date2) { DateTime.new 2019,3,16 }
  let(:date3) { DateTime.new 2019,3,17 }
  let(:date4) { DateTime.new 2019,3,18 }

  def load_data
    ent =  Factory(:entry, entry_number: "ent num", arrival_date: date1, release_date: date2, entry_port_code: "PORT", broker_reference: "brok ref", 
                           customer_name: "cust name", export_date: date3, master_bills_of_lading: "MBOLS", house_bills_of_lading: "HBOLS",
                           total_units: 10, total_packages: 11, container_numbers: "cont numbers")
    ci = Factory(:commercial_invoice, entry: ent, mfid: "MFID", vendor_name: "vend name", invoice_number: "inv number")
    cil = Factory(:commercial_invoice_line, commercial_invoice: ci, line_number: 1, quantity: 2, unit_of_measure: "UOM", value: 3, 
                                            cotton_fee: 4, hmf: 13, mpf: 14, department: "Dept", po_number: "PO", part_number: "part")
    Factory(:commercial_invoice_tariff, commercial_invoice_line: cil, tariff_description: "tar descr", hts_code: "HTS", gross_weight: 5, 
                                        classification_qty_1: 12, classification_uom_1: "cl uom 1", entered_value: 6, 
                                        duty_amount: 7, duty_rate: 8)
    Factory(:broker_invoice, entry: ent, customer_number: "cust num", invoice_total: 9, invoice_date: date4, suffix: "A")

    nil
  end

  def map
    {"Entry Number" => 0, "Arrival" => 1, "Release" => 2, "Entry Port" => 3, "File Number" => 4, "Customer Name" => 5, "Export Date" => 6, 
     "MBOLs" => 7, "HBOLs" => 8, "MID" => 9, "Vendor" => 10, "Invoice Line" => 11, "Commercial Invoice Number" => 12, "Item Description" => 13, 
     "HTS Code" => 14, "Gross Weight" => 15, "Invoice Quantity" => 16, "Invoice UOM" => 17, "Tariff Quantity" => 18, "Tariff UOM" => 19, 
     "Entered Value" => 20, "Invoice Value" => 21, "Duty Amount" => 22, "Duty Rate" => 23, "Cotton Fee" => 24, "HMF" => 25, "MPF" => 26, 
     "Department" => 27, "PO Number" => 28, "Style" => 29, "Invoice Number" => 30, "Invoice Total" => 31, "Entry Fee Per Line" => 32, 
     "Total Packages" => 33, "Containers" => 34}
  end

  describe "permission?" do
    let(:ms) { stub_master_setup }
    
    before do
      expect(MasterSetup).to receive(:get).and_return ms
      allow(ms).to receive(:custom_feature?).with("WWW").and_return true
      allow(user).to receive(:view_broker_invoices?).and_return true
    end

    it "returns 'true' for master user who can view broker-invoices on the main instance" do
      expect(described_class.permission? user).to eq true
    end

    it "returns 'false' if not on the main instance" do
      allow(ms).to receive(:custom_feature?).with("WWW").and_return false
      expect(described_class.permission? user).to eq false
    end

    it "returns 'false' if non-master user" do
      user.company.update_attributes! master: false
      expect(described_class.permission? user).to eq false
    end

    it "returns 'false' if user can't view broker invoices" do
      allow(user).to receive(:view_broker_invoices?).and_return false
      expect(described_class.permission? user).to eq false
    end
  end

  describe "run_report" do
    before { load_data }

    it "returns correct tempfile" do
      tempfile = described_class.run_report(user, {'start_date' => date4 - 1.day, 'end_date' => date4 + 1.day, 'customer_number' => 'cust num'})
      reader = XlsxTestReader.new(tempfile.path).raw_workbook_data
      sheet = reader["Billing Summary"]
      tempfile.close
      expect(sheet[0]).to eq map.keys
      #check datetime conversions
      expect(sheet[1][map["Release"]]).to eq(date2 - 1.day)
      expect(sheet[1][map["Arrival"]]).to eq(date1 - 1.day)
    end

  end

  describe "query" do
    before { load_data }

    it "returns expected result" do
      qry = described_class.new.query("'cust num'", (date4 - 1.day), (date4 + 1.day))
      results = ActiveRecord::Base.connection.execute qry
      expect(results.count).to eq 1
      expect(results.fields).to eq map.keys
      r = results.first
      
      expect(r[map["Entry Number"]]).to eq "ent num"
      expect(r[map["Arrival"]]).to eq date1
      expect(r[map["Release"]]).to eq date2
      expect(r[map["Entry Port"]]).to eq "PORT"
      expect(r[map["File Number"]]).to eq "brok ref"
      expect(r[map["Customer Name"]]).to eq "cust name"
      expect(r[map["Export Date"]]).to eq date3
      expect(r[map["MBOLs"]]).to eq "MBOLS"
      expect(r[map["HBOLs"]]).to eq "HBOLS"
      expect(r[map["MID"]]).to eq "MFID"
      expect(r[map["Vendor"]]).to eq "vend name"
      expect(r[map["Invoice Line"]]).to eq 1
      expect(r[map["Commercial Invoice Number"]]).to eq "inv number"
      expect(r[map["Item Description"]]).to eq "tar descr"
      expect(r[map["HTS Code"]]).to eq "HTS"
      expect(r[map["Gross Weight"]]).to eq 5
      expect(r[map["Invoice Quantity"]]).to eq 2
      expect(r[map["Invoice UOM"]]).to eq "UOM"
      expect(r[map["Tariff Quantity"]]).to eq 12
      expect(r[map["Tariff UOM"]]).to eq "cl uom 1"
      expect(r[map["Entered Value"]]).to eq 6
      expect(r[map["Invoice Value"]]).to eq 3
      expect(r[map["Duty Amount"]]).to eq 7
      expect(r[map["Duty Rate"]]).to eq 8
      expect(r[map["Cotton Fee"]]).to eq 4
      expect(r[map["HMF"]]).to eq 13
      expect(r[map["MPF"]]).to eq 14
      expect(r[map["Department"]]).to eq "Dept"
      expect(r[map["PO Number"]]).to eq "PO"
      expect(r[map["Style"]]).to eq "part"
      expect(r[map["Invoice Number"]]).to eq "brok refA"
      expect(r[map["Invoice Total"]]).to eq 9
      expect(r[map["Entry Fee Per Line"]]).to eq 1.8
      expect(r[map["Total Packages"]]).to eq 11
      expect(r[map["Containers"]]).to eq "cont numbers"
    end

    it "excludes results after end_date" do
      qry = described_class.new.query("'cust num'", (date4 + 1.day), (date4 + 2.days))
      res = ActiveRecord::Base.connection.execute qry
      expect(res.count).to eq 0
    end

    it "excludes results before start_date" do
      qry = described_class.new.query("'cust num'", (date4 - 2.days), (date4 - 1.day))
      res = ActiveRecord::Base.connection.execute qry
      expect(res.count).to eq 0
    end

    it "excludes results for other customers" do
      qry = described_class.new.query("'cust num 2'", (date4 - 1.day), (date4 + 1.day))
      res = ActiveRecord::Base.connection.execute qry
      expect(res.count).to eq 0
    end
  end
end

