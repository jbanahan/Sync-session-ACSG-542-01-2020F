require 'spec_helper'

describe OpenChain::LandsEndExportParser do
  before :each do
    @importer = Factory(:company,:importer=>true) 
    @lines = [
      "\"B3_Entry_Nbr\",\"Ca_Import_Dt\",\"Ca_Release_Dt\",\"Carrier_SCAC\",\"Truck_BOL\",\"CCN_Nbr\",\"LE_Order_And_Trailer_Nbr\",\"LE_Order_Tracking_Nbr\",\"B3_Line_Nbr\",\"HS_Nbr\",\"Dutiable_UoM\",\"COO\",\"SKU_Nbr\",\"SKU_Qty\",\"SKU_Unit_price\",\"LE_Order_Currency\",\"Exchange_Rate\",\"Duty_Paid_Dt\",\"Duty_Rate\",\"Duty_Rate_Amt\",\"GST_Amt\",\"PST_HST_Amt\",\"Excise_Tax\",\"Tot_Duty_And_Taxes_Amt\",\"SIMA_Tot_Value\",\"SIMA_Cd\",\"NAFTA_Ind\",\"Client_Cd\",\"Return_Ind\"",
      "\"15818-019998734\",\"1/4/2012\",\"1/3/2012\",\"\",\"\",\"\",\"00104010-11364\",\"1Z7R65572007202242\",1,\"6116.93.00.92\",\"PAR\",\"CN\",\"3250356\",1,6.99,\"USD\",1.021,\"2/24/2012\",18,1.28,.42,0,0,1.7,0,\"\",2,\"LANDSEND-C\",\"\"",
      "\"15818-019998734\",\"1/4/2012\",\"1/3/2012\",\"\",\"\",\"\",\"00104010-11364\",\"1Z7R65572007202242\",1,\"6116.93.00.92\",\"PAR\",\"CN\",\"3318763\",1,6.99,\"USD\",1.021,\"2/24/2012\",18,1.28,.42,0,0,1.7,0,\"\",2,\"LANDSEND-C\",\"\""
    ]
    c = Factory(:country,:iso_code=>"US")
    ot = Factory(:official_tariff,:country=>c,:chapter=>"CHP, X",:heading=>"HD",:hts_code=>"6116930000")
  end
  describe "parse csv file" do
    it "should parse csv ignoring headers" do
      t = Tempfile.new("xzz")
      t << @lines.join("\n")
      t.flush
      OpenChain::LandsEndExportParser.parse_csv_file t.path, @importer
      expect(DutyCalcExportFileLine.all.size).to eq(2)
      t.unlink
    end
  end
  describe "parse_csv_line" do
    it "should parse line into DutyCalcExportFileLine" do
      d = OpenChain::LandsEndExportParser.parse_csv_line @lines[1].parse_csv, 0, @importer
      expect(d.export_date).to eq(Date.new(2012,1,4))
      expect(d.ship_date).to eq(Date.new(2012,1,4))
      expect(d.part_number).to eq("3250356")
      expect(d.carrier).to be_nil
      expect(d.ref_1).to eq("1Z7R65572007202242") #Lands End Tracking Number
      expect(d.ref_2).to eq("15818-019998734") #B3 Number
      expect(d.ref_3).to be_nil
      expect(d.ref_4).to be_nil
      expect(d.destination_country).to eq("CA")
      expect(d.quantity).to eq(1)
      expect(d.description).to eq("CHP")
      expect(d.uom).to eq("EA")
      expect(d.exporter).to eq("Lands End")
      expect(d.status).to be_nil
      expect(d.action_code).to eq("E")
      expect(d.nafta_duty).to be_nil
      expect(d.nafta_us_equiv_duty).to be_nil
      expect(d.nafta_duty_rate).to be_nil
      expect(d.duty_calc_export_file).to be_nil
      expect(d.hts_code).to eq("6116930092")
      expect(d.importer).to eq(@importer)
    end
    it 'should raise exception if part is empty' do
      line = "\"15818-019998734\",\"1/4/2012\",\"1/3/2012\",\"\",\"\",\"\",\"00104010-11364\",\"1Z7R65572007202242\",1,\"6116.93.00.92\",\"PAR\",\"CN\",\"\",1,6.99,\"USD\",1.021,\"2/24/2012\",18,1.28,.42,0,0,1.7,0,\"\",2,\"LANDSEND-C\",\"\"".parse_csv
      expect {OpenChain::LandsEndExportParser.parse_csv_line line, 0, @importer}.to raise_error
    end
    it 'should raise exception if row does not have 29 elements' do
      line = "\"15818-019998734\",\"1/4/2012\",\"1/3/2012\",\"\",\"\",\"\",\"00104010-11364\",\"1Z7R65572007202242\",1,\"6116.93.00.92\",\"PAR\",\"CN\",\"3250356\",1,6.99,\"USD\",1.021,\"2/24/2012\",18,1.28,.42,0,0,1.7,0,\"\",2,\"LANDSEND-C\"".parse_csv
      expect {OpenChain::LandsEndExportParser.parse_csv_line line}.to raise_error
    end
  end
end
