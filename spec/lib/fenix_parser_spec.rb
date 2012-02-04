require 'spec_helper'

describe OpenChain::FenixParser do

  before :each do
    Factory(:country,:iso_code=>'CA')
    @mdy = '%m/%d/%Y'
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    @barcode = '11981000774460'
    @file_number = '234812'
    @importer_tax_id ='833764202RM0001' 
    @cargo_control_no = '20134310243091'
    @ship_terms = 'Fob'
    @direct_shipment_date = '12/14/2012'
    @transport_mode_code = " 2 "
    @entry_port_code = '456'
    @carrier_code = '1234'
    @voyage = '19191'
    @exit_port_code = '0708'
    @entry_type = 'AB'
    @country_export_code='CN'
    @country_origin_code='VN'
    @duty_due_date = '01/26/2012'
    @across_sent_date = '01/27/2012,09:24am'
    @pars_ack_date = '01/28/2012,11:15am'
    @pars_rej_date = '01/08/2012,11:15am'
    @invoice_number = '12345'
    @invoice_date = '04/16/2012'
    @vendor_name = 'MR Vendor'
    @entry_lambda = lambda {
      data = "\"#{@barcode}\",#{@file_number},\" 0 \",\"#{@importer_tax_id}\",#{@transport_mode_code},#{@entry_port_code},\"#{@carrier_code}\",\"#{@voyage}\",\"\",#{@exit_port_code},#{@entry_type},\"#{@vendor_name}\",\"#{@cargo_control_no}\",\"\",\"4522126971\", 1 ,\"#{@invoice_number}\",\"#{@ship_terms}\",#{@invoice_date},Net30, 50 , 1 , 1 ,\"57639\",\"CAT NOROX MEKP-925H CS560\",\"\",#{@country_export_code},#{@country_origin_code}, 2 ,\"2909.60.00.00\",0000, 174 ,KGM, 13 ,\"\", 0 , 1 , 384 ,NMB, 2.52 ,        967.68,       967.68,#{@direct_shipment_date},USD, 1.0097 ,        977.07, 0 ,          0.00, 5 ,         48.85,          0.00, 0 ,          0.00,         48.85,,,#{@duty_due_date},#{@across_sent_date},#{@pars_ack_date},#{@pars_rej_date},,,01/30/2012,09:48pm,,,,,,\"\",,,,,,,\"\",\"\",\"\",\"\", 0 , 0 ,, 0 ,01/30/2012,\"TINA\",\"1251\",\"\",\"N\",\" 0 \",\" 1 \",\"01/26/2012\",\" \",\"\",\"Roadway Express\",\"\",\"\",\"SYRGIS PERFORMANCE INITIATORS\",\"SYRGIS PERFORMANCE INITIATORS\",\"SYRGIS   \",\"\", 1 ,        967.68"
      data
    }
  end
  it 'should save an entry with one line' do
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    ent.import_country.should == Country.find_by_iso_code('CA')
    ent.entry_number.should == @barcode
    ent.importer_tax_id.should == @importer_tax_id
    ent.cargo_control_number.should == @cargo_control_no
    ent.ship_terms.should == @ship_terms.upcase
    ent.direct_shipment_date.should == Date.strptime(@direct_shipment_date, @mdy)
    ent.transport_mode_code.should == @transport_mode_code.strip
    ent.entry_port_code.should == @entry_port_code
    ent.carrier_code.should == @carrier_code
    ent.voyage.should == @voyage
    ent.us_exit_port_code.should == @exit_port_code
    ent.entry_type.should == @entry_type
    ent.duty_due_date.should == Date.strptime(@duty_due_date, @mdy)
    ent.across_sent_date.should == @est.parse_us_base_format(@across_sent_date.gsub(',',' '))
    ent.entry_filed_date.should == ent.across_sent_date
    ent.pars_ack_date.should == @est.parse_us_base_format(@pars_ack_date.gsub(',',' '))
    ent.first_release_date.should == ent.pars_ack_date
    ent.pars_reject_date.should == @est.parse_us_base_format(@pars_rej_date.gsub(',',' '))
    ent.origin_country_codes.should == @country_origin_code
    ent.export_country_codes.should == @country_export_code

    #commercial invoice header
    ent.commercial_invoices.should have(1).invoice
    ci = ent.commercial_invoices.first
    ci.invoice_number.should == @invoice_number
    ci.invoice_date.should == Date.strptime(@invoice_date,@mdy)
    ci.vendor_name.should == @vendor_name
  end
  it 'should handle blank date time' do
    @across_sent_date = ','
    OpenChain::FenixParser.parse @entry_lambda.call
    Entry.find_by_broker_reference(@file_number).across_sent_date.should be_nil
  end
  it 'should find exit port in schedule d' do
    @exit_port_code == '1234'
    port = Factory(:port,:schedule_d_code=>@exit_port_code)
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    ent.us_exit_port.should == port
  end
  it 'should only update entries with Fenix as source code' do
    Factory(:entry,:broker_reference=>@file_number) #not source code
    OpenChain::FenixParser.parse @entry_lambda.call
    Entry.where(:broker_reference=>@file_number).should have(2).entries
  end
  it 'should update if fenix is source code' do
    Factory(:entry,:broker_reference=>@file_number,:source_system=>OpenChain::FenixParser::SOURCE_CODE) #not source code
    OpenChain::FenixParser.parse @entry_lambda.call
    Entry.where(:broker_reference=>@file_number).should have(1).entries
  end
  it 'should split origin/export country codes that are 3 digits starting w/ U into US & state code' do
    @country_origin_code = 'UIN'
    @country_export_code = 'UNJ'
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    ent.origin_country_codes.should == 'US'
    ent.export_country_codes.should == 'US'
    ent.export_state_codes.should == 'NJ'
    ent.origin_state_codes.should == 'IN'
  end
  it 'should 0 pad exit code to 4 chars' do # port ' 708  ' should be '0708'
    @exit_port_code = ' 444 '
    OpenChain::FenixParser.parse @entry_lambda.call
    Entry.find_by_broker_reference(@file_number).us_exit_port_code.should == '0444'
  end
  context 'multi line' do
    it 'should save an entry with multiple lines one time'
    it 'should overwrite header PO if populated in description 2 field'
    context 'accumulate fields' do
      it 'bills of lading'
      it 'vendor names'
      it 'origin country codes'
      it 'export country codes'
      it 'origin state codes'
      it 'export state codes'
      it 'container numbers'
    end
  end
end
