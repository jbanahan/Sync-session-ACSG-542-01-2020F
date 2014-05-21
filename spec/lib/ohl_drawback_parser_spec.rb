require 'spec_helper'

describe OpenChain::OhlDrawbackParser do
  before :each do 
    {'CN'=>'CHINA','TW'=>'TAIWAN','KH'=>'CAMBODIA','VN'=>'VIET NAM','US'=>'UNITED STATES'}.each do |k,v|
      Factory(:country, :name=>v, :iso_code=>k)
    end
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    @sample_path = 'spec/support/bin/ohl_drawback_sample.xls'
    OpenChain::OhlDrawbackParser.parse @sample_path
  end
  it 'should create entries based on sample, skipping Mode = "-1"' do
    entries = Entry.all
    entries.should have(4).items
    entries.collect {|e| e.entry_number}.should == ["11350368418", "11353554642", "11365647418", "OHL03410879"]
  end
  it "should map new 20 column format" do
    ent = Entry.find_by_entry_number "OHL03410879"
    ent.importer.name.should == "UNDER ARMOUR INC."
    ent.arrival_date.to_date.should == "Thu, 17 Apr 2014".to_date
    ent.entry_port_code.should == "2704"
    ent.mpf.should == 485
    ent.transport_mode_code.should == "11"
    ent.total_invoiced_value.should == 528971
    ent.total_duty.should == 93098.89
    ent.merchandise_description.should == "BACKPACKS/SACKPACKS OF MAN-MADE FIBERS 100% POLYESTER"
    ent.import_country.iso_code.should == "US" #Check this logic
    ent.total_duty_direct.should == 39109.6
    ent.commercial_invoices.count.should == 1
    ci = ent.commercial_invoices.first
    ci.commercial_invoice_lines.count.should == 4
    ln = ci.commercial_invoice_lines.first
    ln.part_number.should == "1251829-389"
    ln.po_number.should == "4500514847"
    ln.quantity.should == 2700
    ln.country_origin_code.should == "CN"
    tr = ln.commercial_invoice_tariffs.first
    tr.hts_code.should == "4202923020"
    tr.duty_amount.should == 6253.63
    tr.classification_qty_1.should == 2700
    tr.classification_uom_1.should == "NO"
    tr.entered_value.should == 1997
  end
  it 'should map newer 31 column format' do
    ent = Entry.find_by_entry_number '11365647418'
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
  end
  it 'should map header fields' do
    ent = Entry.find_by_entry_number '11350368418'
    ent.entry_port_code.should == '1303'
    ent.arrival_date.should == @est.parse('2010-12-27') 
    ent.mpf.should == BigDecimal('139.20')
    ent.transport_mode_code.should == '40'
    ent.total_invoiced_value.should == BigDecimal('66285.00') 
    ent.total_duty.should == BigDecimal('15403.01')
    ent.total_duty_direct.should == BigDecimal('15542.21')
    ent.merchandise_description.should == 'WEARING APPAREL, FOOTWEAR'
  end
  it 'should handle empty mpf' do
    ent = Entry.find_by_entry_number '11353554642'
    ent.mpf.should be_nil
  end
  it 'should map invoice header fields' do
    ent = Entry.find_by_entry_number '11350368418'
    ent.should have(1).commercial_invoices
    ci = ent.commercial_invoices.first
    ci.invoice_number = 'N/A'
  end
  it 'should map invoice line fields' do
    lines = Entry.find_by_entry_number('11353554642').commercial_invoices.first.commercial_invoice_lines
    lines.should have(15).items
    first_line = lines.first
    first_line.part_number.should == '1216859-001'
    first_line.po_number.should == '4500178680'
    first_line.quantity.should == 5724 #convert dozens
    last_line = lines.last
    last_line.part_number.should == '1217342-100'
    last_line.po_number.should == '4500187813'
    last_line.quantity.should == 111
  end
  it 'should map hts fields' do
    lines = Entry.find_by_entry_number('11353554642').commercial_invoices.first.commercial_invoice_lines
    lines.each {|line| line.should have(1).commercial_invoice_tariffs}
    first_hts = lines.first.commercial_invoice_tariffs.first
    first_hts.hts_code.should == '6104632006'
    first_hts.duty_amount.should == BigDecimal('0.00')
    first_hts.classification_qty_1.should == BigDecimal('477')
    first_hts.classification_uom_1.should == 'DOZ'
    first_hts.entered_value.should == BigDecimal('61544.00')

    other_hts = Entry.find_by_entry_number('11350368418').commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.first
    other_hts.duty_amount.should == BigDecimal('26.35')
    other_hts.classification_qty_1.should == BigDecimal('1')
    other_hts.classification_uom_1.should == 'DOZ'
  end
  it 'should replace invoice lines' do
    #process again
    OpenChain::OhlDrawbackParser.parse @sample_path
    lines = Entry.find_by_entry_number('11353554642').commercial_invoices.first.commercial_invoice_lines
    lines.should have(15).items
  end
  it 'should create importer company' do
    c = Company.find_by_name_and_importer('UNDER ARMOUR INC.',true)
    Entry.all.each {|ent| ent.importer.should == c}
  end
  it 'should update existing entry' do
    ent = Entry.find_by_entry_number('11350368418')
    ent.update_attributes(:merchandise_description=>'X')
    OpenChain::OhlDrawbackParser.parse @sample_path
    found = Entry.find_by_entry_number('11350368418')
    found.id.should == ent.id
    found.merchandise_description.should == 'WEARING APPAREL, FOOTWEAR'
    Entry.all.should have(4).items
  end
  it 'should map source' do
    Entry.where(:source_system=>'OHL Drawback').all.should have(4).items
  end
  it 'should map import country' do
    Entry.first.import_country.iso_code.should == 'US'
  end
  it 'should write time to process' do
    Entry.first.time_to_process.should > 0
  end
  context :country_of_origin do
    it 'should map country of origin based on code' do
      lines = Entry.find_by_entry_number('11353554642').commercial_invoices.first.commercial_invoice_lines
      lines.find_by_part_number("1216024-290").country_origin_code.should == "KH"
    end
    it 'should leave blank if country not 2 letter found' do
      lines = Entry.find_by_entry_number('11353554642').commercial_invoices.first.commercial_invoice_lines
      lines.find_by_part_number("1216024-454").country_origin_code.should == ""
    end
  end
end
