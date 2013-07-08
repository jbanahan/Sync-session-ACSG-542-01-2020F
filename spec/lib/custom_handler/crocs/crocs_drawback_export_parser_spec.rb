require 'spec_helper'

describe OpenChain::CustomHandler::Crocs::CrocsDrawbackExportParser do
  before :each do
    @data = "\"5675291\",\"34813\",\"5322514\",\"03-08-2011\",\"THE FORZANI GROUP\",\"MISSISSAUGA DISTRIBUTION CENTRE\",\"3109, SC TDC #3109\",\"MISSISSAUGA\",\"ON\",\"L5T 2R7\",\"CA\",\"10970001440\",\"Crcbnd Jaunt Blk W7\",\"CN\",30,\"Pairs\",\"FEFX\",\"FedEx Freight - Canada\",\"12982\"" 
    @c = Factory(:company)
  end
  it "should parse row" do
    d = described_class.parse_csv_line @data.parse_csv, 1, @c 
    d.importer.should == @c
    d.export_date.should == Date.new(2011,3,8)
    d.ship_date.should == Date.new(2011,3,8)
    d.part_number.should == '10970001440'
    d.carrier.should == 'FedEx Freight - Canada'
    d.ref_1.should == '5675291'
    d.ref_2.should == '34813'
    d.ref_3.should == '5322514'
    d.destination_country.should == 'CA'
    d.quantity.should == 30
    d.description.should == 'Crcbnd Jaunt Blk W7' 
    d.uom.should == 'Pairs'
    d.exporter.should == 'Crocs'
    d.action_code.should == 'E'
  end
end
