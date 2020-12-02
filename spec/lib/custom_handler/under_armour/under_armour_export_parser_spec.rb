describe OpenChain::CustomHandler::UnderArmour::UnderArmourExportParser do

  before :each do
    # UNDER ARMOUR IS DESIGNED TO RUN IN THEIR OWN DATABASE AND USES THE FIRST IMPORTER IN THE DB
    @importer = create(:company, :importer=>true)
  end
  context "AAFES Exports" do
    before :each do
      DrawbackImportLine.create!(:part_number=>"1000375-609-LG+CN", :import_date=>"2011-10-01", :quantity=>10, :product_id=>create(:product, :unique_identifier=>'1000375-609').id)
      DrawbackImportLine.create!(:part_number=>"1000377-001-XXL+TW", :import_date=>"2011-10-01", :quantity=>10, :product_id=>create(:product, :unique_identifier=>'1000377-001').id)
      DrawbackImportLine.create!(:part_number=>"1000377-001-XXL+MY", :import_date=>"2011-11-01", :quantity=>10, :product_id=>Product.find_by(unique_identifier: '1000377-001').id)
      @lines = [
"Style,Color,UPC,PO Number,PO Line Number,Export Date,TCMD CONTAINER,VAN TCN,PO Received Date,Vendor,VENDOR NAME,Facility,ISO,FACNAME,Item,DESC,CRC,STYLE2,Units Received,Cost,Recd $",
"1000375-609,LG,698611559156,0055404558,5,10/2/2011,MSKU 812950 ,HX7NNW-3903-S0622M2,11-Nov-11,60581514,UNDER ARMOUR,1375142,DE,GRAFENWOEHR MAIN STORE,470566840000001,UA MEN TOP MAROON LARGE,4947811,1000375609,20,$9.50 ,$190.00",
"1000377-001,XXL,698611562095,0016052969,10,12/25/2011,APZU 474489 ,HX7NNW-4696-M0022M2,6-Feb-12,60581514,UNDER ARMOUR,1463665,KW,KW ARIFJAN Z6,470551939000013,TSHRT MEN XXL BLK,1387244,1000377-080 ,24,$11.88 ,$285.12",
"1000377-410,XL,698611562149,0014599787,2,8/14/2011,SBOP,,9-Oct-10,60581507,UNDER ARMOUR,1365550,DE,GE VILSECK PXTRA,470551939000012,TSHRT MEN XL MDN,1387243,1000377-080,6,$12.50 ,$75.00 "
      ]
      @t = Tempfile.new("xyz")
      @t << @lines.join("\n")
      @t.flush
      @messages = described_class.parse_aafes_csv_file @t.path
    end
    after :each do
      @t.close
    end
    it "should parse multi line CSV" do
      line = DutyCalcExportFileLine.find_by(part_number: '1000375-609-LG+CN')
      expect(line.export_date).to eq(Date.new(2011, 10, 2))
      expect(line.ship_date).to eq(Date.new(2011, 10, 2))
      expect(line.ref_1).to eq('0055404558')
      expect(line.ref_2).to eq('5')
      expect(line.ref_3).to eq("AAFES - NOT FOR ABI")
      expect(line.destination_country).to eq('DE')
      expect(line.quantity).to eq(20)
      expect(line.description).to eq("UA MEN TOP MAROON LARGE")
      expect(line.uom).to eq("EA")
      expect(line.action_code).to eq('E')
      expect(line.duty_calc_export_file_id).to be_nil
      expect(line.importer).to eq(@importer)
    end
    it "should pick country of origin for most recent import prior to export if multiple are found" do
      expect(DutyCalcExportFileLine.find_by(part_number: '1000377-001-XXL+MY')).not_to be_nil
      expect(DutyCalcExportFileLine.find_by(part_number: '1000377-001-XXL+TW')).to be_nil
    end
    it "should skip lines without country of origin match" do
      expect(DutyCalcExportFileLine.where("part_number like \"1000377-410%\"")).to be_empty
    end
    it "should return skipped lines" do
      expect(@messages.size).to eq(1)
      expect(@messages.first).to include "Could not find country of origin for 1000377-410"
    end
  end
  context "DH Exports" do
    before :each do
      @lines = [
        "SO Num,Delivery,Style,Color,Size,COO,Item Desc.,Units,Sold To Name,SO City,SO State,SO Zip,SO Cntry,Ship To Name,SH City,SH State,SO Zip,SO Country,PT Sh Date,Ctn Sh Date,HTS,CCI,Cust.,Retail,Carton,BOL,Ctn. Track,DBox Track,Pro Number,Cust PO,ShipVia,ActWeight",
        "3452168,85439724,1000382,1,LG,BD,TECH TEE SS-BLK,4,A. ROY SPORTS,MONTREAL,QC,K9J 7Y8,CA,A. ROY SPORTS,MONTREAL,QC,H1B 2Y8,CA,20100305,20100305,6110.30.3060,5.53,16.5,49.99,8.85559E+15,,4.97086E+11,4.97086E+11,,FW12 H/F SMS,FIE,7.55",
        "3452168,85439724,1000382,1,MD,BD,TECH TEE SS-BLK,4,A. ROY SPORTS,MONTREAL,QC,K9J 7Y8,CA,A. ROY SPORTS,MONTREAL,QC,H1B 2Y8,CA,20100305,20100305,6110.30.3060,5.53,16.5,49.99,8.85559E+15,,4.97086E+11,4.97086E+11,,FW12 H/F SMS,FIE,7.55"
      ]
    end
    describe "parse_csv_file" do
      it "should handle non-ascii characters" do
        described_class.parse_csv_file 'spec/support/bin/ua_outbound_unicode.csv', @importer
        expect(DutyCalcExportFileLine.all.size).to eq(1)
        expect(DutyCalcExportFileLine.first.description).to eq('UA PERFECT CAPRI-BLK/BLK Qu bec')
      end
      it "should parse multi line csv ignoring headers" do
        content = @lines.join("\n")
        t = Tempfile.new("xyz")
        t << content
        t.flush
        described_class.parse_csv_file t.path, @importer
        expect(DutyCalcExportFileLine.all.size).to eq(2)
        t.unlink
      end
      it "should skip empty lines without error" do
        @lines << "  "
        content = @lines.join("\n")
        t = Tempfile.new("xyz")
        t << content
        t.flush
        described_class.parse_csv_file t.path, @importer
        expect(DutyCalcExportFileLine.all.size).to eq(2)
        t.unlink
      end
    end

    describe "parse_csv_line" do
      it "should parse a line into a DutyCalcExportFileLine" do
        d = described_class.parse_csv_line @lines[1].parse_csv, 0, @importer
        expect(d.export_date).to eq(Date.new(2010, 3, 5))
        expect(d.ship_date).to eq(Date.new(2010, 3, 5))
        expect(d.part_number).to eq("1000382-001-LG+BD")
        expect(d.carrier).to be_nil
        expect(d.ref_1).to eq("85439724")
        expect(d.ref_2).to eq("3452168")
        expect(d.ref_3).to be_nil
        expect(d.ref_4).to be_nil
        expect(d.destination_country).to eq("CA")
        expect(d.quantity).to eq(4)
        expect(d.schedule_b_code).to eq("6110303060")
        expect(d.description).to eq("TECH TEE SS-BLK")
        expect(d.uom).to eq("EA")
        expect(d.exporter).to eq("Under Armour")
        expect(d.status).to be_nil
        expect(d.action_code).to eq("E")
        expect(d.nafta_duty).to be_nil
        expect(d.nafta_us_equiv_duty).to be_nil
        expect(d.nafta_duty_rate).to be_nil
        expect(d.duty_calc_export_file).to be_nil
        expect(d.importer).to eq(@importer)
      end

      it 'should raise exception if row does not have 32 elements' do
        line = "3452168,85439724,1005492,1,LG,TECH TEE SS-BLK,4,A. ROY SPORTS,MONTREAL,QC,K9J 7Y8,CA,A. ROY SPORTS,MONTREAL,QC,H1B 2Y8,CA,20100305,20100305,6110.30.3060,5.53,16.5,49.99,8.85559E+15,,4.97086E+11,,FW12 H/F SMS,FIE,7.55".parse_csv
        expect {described_class.parse_csv_line line, 0, @importer}.to raise_error(/elements/)
      end
    end
  end

  context "FMI Exports" do
    before :each do
      @lines = [
        "PO Number,COO,COO,Customer Order (PO),TPM Shipped Date,TPM Orig Locn Id,Material,Material,AFS Grid,TPM Ship To Name,TPM Ship To ID,Country,Country,Ship-To Party,Ship-To Party,Address,City,Container #,TPM Master BoL,Shipped Qty,Net Price,Net Price",
        "4500110966,CN,China,161051,1/7/2010,FMI Logistics LAX - HUBFMI,1211721-001,CA LOOSE BATTLE LS-BLK/GPH,LG,FORZANI GROUP LTD-DC CENTRE,20006049,CA,Canada,20006049,FORZANI GROUP LTD-DC CENTRE,#,MISSISSAUGA,41902,#,100,$877.00 ,$8.77",
        "4500110966,CN,China,161051,1/7/2010,FMI Logistics LAX - HUBFMI,1211721-001,CA LOOSE BATTLE LS-BLK/GPH,MD,FORZANI GROUP LTD-DC CENTRE,20006049,CA,Canada,20006049,FORZANI GROUP LTD-DC CENTRE,#,MISSISSAUGA,41902,#,75,$657.75 ,$8.77"
      ]
    end
    it "should parse file ignoring headers" do
      content = @lines.join("\n")
      t = Tempfile.new("xyz")
      t << content
      t.flush
      described_class.parse_fmi_csv_file t.path
      expect(DutyCalcExportFileLine.all.size).to eq(2)
    end

    describe "parse_fmi_csv_line" do
      it "should parse a line into a DutyCalcExportFileLine" do
        described_class.parse_fmi_csv_line @lines[1]
        expect(DutyCalcExportFileLine.count).to eq(1)
        d = DutyCalcExportFileLine.first
        expect(d.export_date).to eq(Date.new(2010, 1, 7))
        expect(d.ship_date).to eq(Date.new(2010, 1, 7))
        expect(d.part_number).to eq("1211721-001-LG+CN")
        expect(d.carrier).to be_nil
        expect(d.ref_1).to eq("4500110966")
        expect(d.ref_2).to eq("161051")
        expect(d.ref_3).to be_nil
        expect(d.ref_4).to be_nil
        expect(d.destination_country).to eq("CA")
        expect(d.quantity).to eq(100)
        expect(d.schedule_b_code).to be_nil
        expect(d.description).to eq("CA LOOSE BATTLE LS-BLK/GPH")
        expect(d.uom).to eq("EA")
        expect(d.exporter).to eq("Under Armour")
        expect(d.status).to be_nil
        expect(d.action_code).to eq("E")
        expect(d.nafta_duty).to be_nil
        expect(d.nafta_us_equiv_duty).to be_nil
        expect(d.nafta_duty_rate).to be_nil
        expect(d.duty_calc_export_file).to be_nil
        expect(d.importer).to eq(@importer)
      end
    end
  end
end
