describe OpenChain::CustomHandler::Crocs::CrocsDrawbackExportParser do
  before :each do
    @data = "\"5675291\",\"34813\",\"5322514\",\"4/8/11\",\"THE FORZANI GROUP\",\"MISSISSAUGA DISTRIBUTION CENTRE\",\"3109, SC TDC #3109\",\"MISSISSAUGA\",\"ON\",\"L5T 2R7\",\"CA\",\"10970001440\",\"Crcbnd Jaunt Blk W7\",\"CN\",30,\"Pairs\",\"FEFX\",\"FedEx Freight - Canada\""
    @c = Factory(:company)
  end
  it "should parse row" do
    d = described_class.parse_csv_line @data.parse_csv, 1, @c
    expect(d.importer).to eq(@c)
    expect(d.export_date).to eq(Date.new(2011, 4, 8))
    expect(d.ship_date).to eq(Date.new(2011, 4, 8))
    expect(d.part_number).to eq('10970001440-CN')
    expect(d.carrier).to eq('FedEx Freight - Canada')
    expect(d.ref_1).to eq('5675291')
    expect(d.ref_2).to eq('34813')
    expect(d.ref_3).to eq('5322514')
    expect(d.destination_country).to eq('CA')
    expect(d.quantity).to eq(30)
    expect(d.description).to eq('Crcbnd Jaunt Blk W7')
    expect(d.uom).to eq('Pairs')
    expect(d.exporter).to eq('Crocs')
    expect(d.action_code).to eq('E')
  end
end
