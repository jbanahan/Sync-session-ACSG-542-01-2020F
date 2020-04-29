describe OpenChain::CustomHandler::UnderArmour::UnderArmourFtzParser do

  before :each do
    @line = "1600,113-4873420-0,85075306,1200739-001,7,285,ID,6402992760,892.05,26.7615,0.03,0,0,UA LOCKER SLIDE - BLK/SLV"
    @port_code = "1303"
    @box_37 = 100
    @box_40 = 101
    @total_value = 102
    @total_mpf = 103
    @entered_date = 1.day.ago
    @parser = described_class.new(@total_value, @total_mpf,
      @entered_date, @port_code, @box_37, @box_40)
  end

  it "should match to existing export line and create import line" do
    exp = Factory(:duty_calc_export_file_line, :ref_1=>'85075306')
    t = Tempfile.new("ftz")
    t << @line
    t.flush
    @parser.process_csv t.path
    expect(Product.first.unique_identifier).to eq("1200739-001")
    expect(DrawbackImportLine.all.size).to eq(1)
    d = DrawbackImportLine.first
    expect(d.product).to eq(Product.first)
    expect(d.entry_number).to eq("11348734200")
    expect(d.import_date.strftime("%m/%d/%Y")).to eq(@entered_date.strftime("%m/%d/%Y"))
    expect(d.received_date.strftime("%m/%d/%Y")).to eq(@entered_date.strftime("%m/%d/%Y"))
    expect(d.port_code).to eq(@port_code)
    expect(d.box_37_duty).to eq(@box_37)
    expect(d.box_40_duty).to eq(@box_40)
    expect(d.total_invoice_value).to eq(@total_value)
    expect(d.total_mpf).to eq(@total_mpf)
    expect(d.country_of_origin_code).to eq("ID")
    expect(d.part_number).to eq("1200739-001-7+ID")
    expect(d.hts_code).to eq("6402992760")
    expect(d.description).to eq("UA LOCKER SLIDE - BLK/SLV")
    expect(d.unit_of_measure).to eq("EA")
    expect(d.quantity).to eq(285)
    expect(d.unit_price).to eq(3.13)
    expect(d.rate).to eq(0.03)
    expect(d.duty_per_unit).to eq(0.0939)
  end
  it "should not create import lines if they already exist" do
    exp = Factory(:duty_calc_export_file_line, :ref_1=>'85075306')
    t = Tempfile.new("ftz")
    t << @line
    t.flush
    @parser.process_csv t.path
    @parser.process_csv t.path
    expect(DrawbackImportLine.all.size).to eq(1)
  end
  it "should not create import lines if export lines don't already exist" do
    t = Tempfile.new("ftz")
    t << @line
    t.flush
    @parser.process_csv t.path
    expect(DrawbackImportLine.all).to be_empty
    expect(Product.all).to be_empty
  end

end
