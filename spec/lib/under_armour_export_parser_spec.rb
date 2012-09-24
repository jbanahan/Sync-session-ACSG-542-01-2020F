require 'spec_helper'

describe OpenChain::UnderArmourExportParser do
  
  before :each do 
    #UNDER ARMOUR IS DESIGNED TO RUN IN THEIR OWN DATABASE AND USES THE FIRST IMPORTER IN THE DB
    @importer = Factory(:company,:importer=>true) 
  end
  context "AAFES Exports" do
    before :each do
      DrawbackImportLine.create!(:part_number=>"1000375-609-LG+CN",:import_date=>"2011-10-01",:quantity=>10,:product_id=>Factory(:product,:unique_identifier=>'1000375-609').id)
      DrawbackImportLine.create!(:part_number=>"1000377-001-XXL+TW",:import_date=>"2011-10-01",:quantity=>10,:product_id=>Factory(:product,:unique_identifier=>'1000377-001').id)
      DrawbackImportLine.create!(:part_number=>"1000377-001-XXL+MY",:import_date=>"2011-11-01",:quantity=>10,:product_id=>Product.find_by_unique_identifier('1000377-001').id)
      @lines = [
"Style,Color,UPC,PO Number,PO Line Number,Export Date,TCMD CONTAINER,VAN TCN,PO Received Date,Vendor,VENDOR NAME,Facility,ISO,FACNAME,Item,DESC,CRC,STYLE2,Units Received,Cost,Recd $",
"1000375-609,LG,698611559156,0055404558,5,10/2/2011,MSKU 812950 ,HX7NNW-3903-S0622M2,11-Nov-11,60581514,UNDER ARMOUR,1375142,DE,GRAFENWOEHR MAIN STORE,470566840000001,UA MEN TOP MAROON LARGE,4947811,1000375609,20,$9.50 ,$190.00",
"1000377-001,XXL,698611562095,0016052969,10,12/25/2011,APZU 474489 ,HX7NNW-4696-M0022M2,6-Feb-12,60581514,UNDER ARMOUR,1463665,KW,KW ARIFJAN Z6,470551939000013,TSHRT MEN XXL BLK,1387244,1000377-080 ,24,$11.88 ,$285.12", 
"1000377-410,XL,698611562149,0014599787,2,8/14/2011,SBOP,,9-Oct-10,60581507,UNDER ARMOUR,1365550,DE,GE VILSECK PXTRA,470551939000012,TSHRT MEN XL MDN,1387243,1000377-080,6,$12.50 ,$75.00 "
      ]
      @t = Tempfile.new("xyz")
      @t << @lines.join("\n") 
      @t.flush
      @messages = OpenChain::UnderArmourExportParser.parse_aafes_csv_file @t.path 
    end
    after :each do
      @t.close
    end
    it "should parse multi line CSV" do
      line = DutyCalcExportFileLine.find_by_part_number '1000375-609-LG+CN'
      line.export_date.should == Date.new(2011,10,2)
      line.ship_date.should == Date.new(2011,10,2)
      line.ref_1.should == '0055404558'
      line.ref_2.should == '5'
      line.ref_3.should == "AAFES - NOT FOR ABI"
      line.destination_country.should == 'DE'
      line.quantity.should == 20
      line.description.should == "UA MEN TOP MAROON LARGE"
      line.uom.should == "EA"
      line.action_code.should == 'E'
      line.duty_calc_export_file_id.should be_nil
      line.importer.should == @importer
    end
    it "should pick country of origin for most recent import prior to export if multiple are found" do
      DutyCalcExportFileLine.find_by_part_number('1000377-001-XXL+MY').should_not be_nil
      DutyCalcExportFileLine.find_by_part_number('1000377-001-XXL+TW').should be_nil
    end
    it "should skip lines without country of origin match" do
      DutyCalcExportFileLine.where("part_number like \"1000377-410%\"").should be_empty
    end
    it "should return skipped lines" do
      @messages.should have(1).message
      @messages.first.should include "Could not find country of origin for 1000377-410"
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
    describe :parse_csv_file do
      it "should parse multi line csv ignoring headers" do
        content = @lines.join("\n")
        t = Tempfile.new("xyz")
        t << content
        t.flush
        OpenChain::UnderArmourExportParser.parse_csv_file t.path
        DutyCalcExportFileLine.all.should have(2).items
      end
    end

    describe :parse_csv_line do
      it "should parse a line into a DutyCalcExportFileLine" do
        OpenChain::UnderArmourExportParser.parse_csv_line @lines[1]
        DutyCalcExportFileLine.count.should == 1
        d = DutyCalcExportFileLine.first
        d.export_date.should == Date.new(2010,3,5)
        d.ship_date.should == Date.new(2010,3,5)
        d.part_number.should == "1000382-001-LG+BD"
        d.carrier.should be_nil
        d.ref_1.should == "85439724"
        d.ref_2.should == "3452168"
        d.ref_3.should be_nil
        d.ref_4.should be_nil
        d.destination_country.should == "CA"
        d.quantity.should == 4
        d.schedule_b_code.should == "6110303060"
        d.description.should == "TECH TEE SS-BLK"
        d.uom.should == "EA"
        d.exporter.should == "Under Armour"
        d.status.should be_nil
        d.action_code.should == "E"
        d.nafta_duty.should be_nil
        d.nafta_us_equiv_duty.should be_nil
        d.nafta_duty_rate.should be_nil
        d.duty_calc_export_file.should be_nil
        d.importer.should == @importer
      end
      
      it 'should raise exception if style is empty' do
        line = "3452168,85439724,,1,LG,BD,TECH TEE SS-BLK,4,A. ROY SPORTS,MONTREAL,QC,K9J 7Y8,CA,A. ROY SPORTS,MONTREAL,QC,H1B 2Y8,CA,20100305,20100305,6110.30.3060,5.53,16.5,49.99,8.85559E+15,,4.97086E+11,,FW12 H/F SMS,FIE,7.55"
        lambda {OpenChain::UnderArmourExportParser.parse_csv_line line}.should raise_error
      end
      it 'should raise exception if color is empty' do
        line = "3452168,85439724,1005492,,LG,BD,TECH TEE SS-BLK,4,A. ROY SPORTS,MONTREAL,QC,K9J 7Y8,CA,A. ROY SPORTS,MONTREAL,QC,H1B 2Y8,CA,20100305,20100305,6110.30.3060,5.53,16.5,49.99,8.85559E+15,,4.97086E+11,,FW12 H/F SMS,FIE,7.55"
        lambda {OpenChain::UnderArmourExportParser.parse_csv_line line}.should raise_error
      end
      it 'should raise exception if size is empty' do
        line = "3452168,85439724,1005492,1,,BD,TECH TEE SS-BLK,4,A. ROY SPORTS,MONTREAL,QC,K9J 7Y8,CA,A. ROY SPORTS,MONTREAL,QC,H1B 2Y8,CA,20100305,20100305,6110.30.3060,5.53,16.5,49.99,8.85559E+15,,4.97086E+11,,FW12 H/F SMS,FIE,7.55"
        lambda {OpenChain::UnderArmourExportParser.parse_csv_line line}.should raise_error
      end
      it 'should raise exception if COO is empty' do
        line = "3452168,85439724,1005492,1,LG,,TECH TEE SS-BLK,4,A. ROY SPORTS,MONTREAL,QC,K9J 7Y8,CA,A. ROY SPORTS,MONTREAL,QC,H1B 2Y8,CA,20100305,20100305,6110.30.3060,5.53,16.5,49.99,8.85559E+15,,4.97086E+11,,FW12 H/F SMS,FIE,7.55"
        lambda {OpenChain::UnderArmourExportParser.parse_csv_line line}.should raise_error
      end
      it 'should raise exception if row does not have 32 elements' do
        line = "3452168,85439724,1005492,1,LG,TECH TEE SS-BLK,4,A. ROY SPORTS,MONTREAL,QC,K9J 7Y8,CA,A. ROY SPORTS,MONTREAL,QC,H1B 2Y8,CA,20100305,20100305,6110.30.3060,5.53,16.5,49.99,8.85559E+15,,4.97086E+11,,FW12 H/F SMS,FIE,7.55"
        lambda {OpenChain::UnderArmourExportParser.parse_csv_line line}.should raise_error
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
      OpenChain::UnderArmourExportParser.parse_fmi_csv_file t.path
      DutyCalcExportFileLine.all.should have(2).items
    end

    describe :parse_fmi_csv_line do
      it "should parse a line into a DutyCalcExportFileLine" do
        OpenChain::UnderArmourExportParser.parse_fmi_csv_line @lines[1]
        DutyCalcExportFileLine.count.should == 1
        d = DutyCalcExportFileLine.first
        d.export_date.should == Date.new(2010,1,7)
        d.ship_date.should == Date.new(2010,1,7)
        d.part_number.should == "1211721-001-LG+CN"
        d.carrier.should be_nil
        d.ref_1.should == "4500110966"
        d.ref_2.should == "161051"
        d.ref_3.should be_nil
        d.ref_4.should be_nil
        d.destination_country.should == "CA"
        d.quantity.should == 100
        d.schedule_b_code.should be_nil
        d.description.should == "CA LOOSE BATTLE LS-BLK/GPH"
        d.uom.should == "EA"
        d.exporter.should == "Under Armour"
        d.status.should be_nil
        d.action_code.should == "E"
        d.nafta_duty.should be_nil
        d.nafta_us_equiv_duty.should be_nil
        d.nafta_duty_rate.should be_nil
        d.duty_calc_export_file.should be_nil
        d.importer.should == @importer
      end
    end
  end
end

