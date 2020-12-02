describe OpenChain::OhlDrawbackParser do
  before :all do
    @companies = Company.all
    {'CN'=>'CHINA', 'TW'=>'TAIWAN', 'KH'=>'CAMBODIA', 'VN'=>'VIET NAM', 'US'=>'UNITED STATES'}.each do |k, v|
      create(:country, :name=>v, :iso_code=>k)
    end
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    @sample_path = 'spec/support/bin/ohl_drawback_sample.xls'
    OpenChain::OhlDrawbackParser.parse @sample_path
  end
  after :all do
    Country.all.destroy_all
    Entry.all.destroy_all
    Company.destroy_all
  end
  it 'should create entries based on sample, skipping Mode = "-1"' do
    entries = Entry.all
    expect(entries.size).to eq(4)
    expect(entries.collect {|e| e.entry_number}).to eq(["11350368418", "11353554642", "11365647418", "OHL03410879"])
  end
  it "should map new 20 column format" do
    ent = Entry.find_by entry_number: "OHL03410879"
    expect(ent.importer.name).to eq("UNDER ARMOUR INC.")
    expect(ent.arrival_date.to_date).to eq(@est.parse("2014-04-17").to_date)
    expect(ent.entry_port_code).to eq("2704")
    expect(ent.mpf).to eq(485)
    expect(ent.transport_mode_code).to eq("11")
    expect(ent.total_invoiced_value).to eq(528971)
    expect(ent.total_duty).to eq(93098.89)
    expect(ent.merchandise_description).to eq("BACKPACKS/SACKPACKS OF MAN-MADE FIBERS 100% POLYESTER")
    expect(ent.import_country.iso_code).to eq("US") # Check this logic
    expect(ent.total_duty_direct).to eq(39109.6)
    expect(ent.commercial_invoices.count).to eq(1)
    ci = ent.commercial_invoices.first
    expect(ci.commercial_invoice_lines.count).to eq(4)
    ln = ci.commercial_invoice_lines.first
    expect(ln.part_number).to eq("1251829-389")
    expect(ln.po_number).to eq("4500514847")
    expect(ln.quantity).to eq(2700)
    expect(ln.country_origin_code).to eq("CN")
    tr = ln.commercial_invoice_tariffs.first
    expect(tr.hts_code).to eq("4202923020")
    expect(tr.duty_amount).to eq(6253.63)
    expect(tr.classification_qty_1).to eq(2700)
    expect(tr.classification_uom_1).to eq("NO")
    expect(tr.entered_value).to eq(BigDecimal.new('35532'))
    expect(tr.duty_rate).to eq(BigDecimal('0.056'))
  end
  it 'should map newer 31 column format' do
    ent = Entry.find_by entry_number: '11365647418'
    expect(ent.entry_port_code).to eql '4601'
    expect(ent.arrival_date).to eql @est.parse('2014-04-01')
    expect(ent.mpf).to eql BigDecimal(485)
    expect(ent.transport_mode_code).to eql '11'
    expect(ent.total_invoiced_value).to eql BigDecimal('280512.00')
    expect(ent.total_duty).to eql BigDecimal('0')
    expect(ent.total_duty_direct).to eql BigDecimal('43.41')
    expect(ent.merchandise_description).to eql '1307 MENS & WOMENS WEARING APPAREL'
    expect(ent.commercial_invoices.count).to eql 1
    ci = ent.commercial_invoices.first
    expect(ci.commercial_invoice_lines.count).to eql 1
    ln = ci.commercial_invoice_lines.first
    expect(ln.country_origin_code).to eql 'JO'
    expect(ln.part_number).to eql '1233719-025'
    expect(ln.po_number).to eql '4500493274'
    expect(ln.quantity).to eql 3528
    tr = ln.commercial_invoice_tariffs.first
    expect(tr.hts_code).to eq '6109901090'
    expect(tr.duty_amount).to eq BigDecimal('0')
    expect(tr.classification_qty_1).to eq BigDecimal('294')
    expect(tr.classification_uom_1).to eq 'DOZ'
    expect(tr.entered_value).to eq BigDecimal('14575')
    expect(tr.duty_rate).to eq BigDecimal('0.012')
  end
  it 'should map header fields' do
    ent = Entry.find_by entry_number: '11350368418'
    expect(ent.entry_port_code).to eq('1303')
    expect(ent.arrival_date).to eq(@est.parse('2010-12-27'))
    expect(ent.mpf).to eq(BigDecimal('139.20'))
    expect(ent.transport_mode_code).to eq('40')
    expect(ent.total_invoiced_value).to eq(BigDecimal('66285.00'))
    expect(ent.total_duty).to eq(BigDecimal('15403.01'))
    expect(ent.total_duty_direct).to eq(BigDecimal('15542.21'))
    expect(ent.merchandise_description).to eq('WEARING APPAREL, FOOTWEAR')
  end
  it 'should handle empty mpf' do
    ent = Entry.find_by entry_number: '11353554642'
    expect(ent.mpf).to be_nil
  end
  it 'should map invoice header fields' do
    ent = Entry.find_by entry_number: '11350368418'
    expect(ent.commercial_invoices.size).to eq(1)
    ci = ent.commercial_invoices.first
    ci.invoice_number = 'N/A'
  end
  it 'should map invoice line fields' do
    lines = Entry.find_by(entry_number: '11353554642').commercial_invoices.first.commercial_invoice_lines
    expect(lines.size).to eq(15)
    first_line = lines.first
    expect(first_line.part_number).to eq('1216859-001')
    expect(first_line.po_number).to eq('4500178680')
    expect(first_line.quantity).to eq(5724) # convert dozens
    last_line = lines.last
    expect(last_line.part_number).to eq('1217342-100')
    expect(last_line.po_number).to eq('4500187813')
    expect(last_line.quantity).to eq(111)
  end
  it 'should map hts fields' do
    lines = Entry.find_by(entry_number: '11353554642').commercial_invoices.first.commercial_invoice_lines
    lines.each {|line| expect(line.commercial_invoice_tariffs.size).to eq(1)}
    first_hts = lines.first.commercial_invoice_tariffs.first
    expect(first_hts.hts_code).to eq('6104632006')
    expect(first_hts.duty_amount).to eq(BigDecimal('0.00'))
    expect(first_hts.classification_qty_1).to eq(BigDecimal('477'))
    expect(first_hts.classification_uom_1).to eq('DOZ')
    expect(first_hts.entered_value).to eq(BigDecimal('61544.00'))
    expect(first_hts.duty_rate).to eq(BigDecimal('0.034'))

    other_hts = Entry.find_by(entry_number: '11350368418').commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.first
    expect(other_hts.duty_amount).to eq(BigDecimal('26.35'))
    expect(other_hts.classification_qty_1).to eq(BigDecimal('1'))
    expect(other_hts.classification_uom_1).to eq('DOZ')
    expect(other_hts.duty_rate).to eq(BigDecimal('0.17'))
  end
  it 'should replace invoice lines' do
    # process again
    OpenChain::OhlDrawbackParser.parse @sample_path
    lines = Entry.find_by(entry_number: '11353554642').commercial_invoices.first.commercial_invoice_lines
    expect(lines.size).to eq(15)
  end
  it 'should create importer company' do
    c = Company.find_by_name_and_importer('UNDER ARMOUR INC.', true)
    Entry.all.each {|ent| expect(ent.importer).to eq(c)}
  end
  it 'should update existing entry' do
    ent = Entry.find_by(entry_number: '11350368418')
    ent.update_attributes(:merchandise_description=>'X')
    OpenChain::OhlDrawbackParser.parse @sample_path
    found = Entry.find_by entry_number: ('11350368418')
    expect(found.id).to eq(ent.id)
    expect(found.merchandise_description).to eq('WEARING APPAREL, FOOTWEAR')
    expect(Entry.all.size).to eq(4)
  end
  it 'should map source' do
    expect(Entry.where(:source_system=>'OHL Drawback').all.size).to eq(4)
  end
  it 'should map import country' do
    expect(Entry.first.import_country.iso_code).to eq('US')
  end
  it 'should write time to process' do
    expect(Entry.first.time_to_process).to be > 0
  end
  context "country_of_origin" do
    it 'should map country of origin based on code' do
      lines = Entry.find_by(entry_number: '11353554642').commercial_invoices.first.commercial_invoice_lines
      expect(lines.find_by_part_number("1216024-290").country_origin_code).to eq("KH")
    end
    it 'should leave blank if country not 2 letter found' do
      lines = Entry.find_by(entry_number: '11353554642').commercial_invoices.first.commercial_invoice_lines
      expect(lines.find_by_part_number("1216024-454").country_origin_code).to eq("")
    end
  end
end
