require 'spec_helper'

describe OpenChain::UnderArmourExportParser do
  
  context "DH Exports" do
    before :each do
      @lines = [
        "SO Num,Delivery,Style,Color,Size,SKU,COO,Item Desc.,Units,Sold To Name,City,Ship To Name,State,Zip,Country,PT Sh Date,Ctn Sh Date,HTS,CCI,Cust.,Cust Line Value,Carton,",
        "3452168,85439724,1000382,001,LG,85439724-1000382-001-LG-BD,BD,TECH TEE SS-BLK,4,A. ROY SPORTS,MONTREAL,A. ROY SPORTS,QC,H1B 2Y8,CA,20100305,20100305,6110.30.3060,5.53,$14.55,$58.20,8838140040135440,",
        "3452168,85439724,1000382,001,MD,85439724-1000382-001-MD-BD,BD,TECH TEE SS-BLK,4,A. ROY SPORTS,MONTREAL,A. ROY SPORTS,QC,H1B 2Y8,CA,20100305,20100305,6110.30.3060,5.53,$14.55,$58.20,8838140040135440,"
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
      end
      
      it "should raise exception if all part number components are not found" do
        #this record is missing the size in the combined part number
        bad_line = "3452168,85439724,1000382,001,MD,85439724-1000382-001-BD,BD,TECH TEE SS-BLK,4,A. ROY SPORTS,MONTREAL,A. ROY SPORTS,QC,H1B 2Y8,CA,20100305,20100305,6110.30.3060,5.53,$14.55,$58.20,8838140040135440,"
        lambda {OpenChain::UnderArmourExportParser.parse_csv_line bad_line}.should raise_error
        DutyCalcExportFileLine.all.should be_empty
      end
      it "should raise exception if a part number component is empty" do
        #this record has an empty color in the combined part number
        bad_line = "3452168,85439724,1000382,001,MD,85439724-1000382--MD-BD,BD,TECH TEE SS-BLK,4,A. ROY SPORTS,MONTREAL,A. ROY SPORTS,QC,H1B 2Y8,CA,20100305,20100305,6110.30.3060,5.53,$14.55,$58.20,8838140040135440,"
        lambda {OpenChain::UnderArmourExportParser.parse_csv_line bad_line}.should raise_error
        DutyCalcExportFileLine.all.should be_empty
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
      end
    end
  end
end

