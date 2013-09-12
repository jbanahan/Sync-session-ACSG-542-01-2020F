require 'spec_helper'

describe OpenChain::FenixParser do

  before :each do
    Factory(:country,:iso_code=>'CA')
    @mdy = '%m/%d/%Y'
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    @barcode = '11981000774460'
    @file_number = '234812'
    @importer_tax_id ='833764202RM0001'
    @importer_number = "IMPSOSO"
    @importer_name = "Importer So-And-So"
    @cargo_control_no = '20134310243091'
    @ship_terms = 'Fob'
    @direct_shipment_date = '12/14/2012'
    @transport_mode_code = " 9 "
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
    @release_date = '01/09/2012,11:19am'
    @cadex_sent_date = '01/10/2012,12:15pm'
    @cadex_accept_date = '01/11/2012,01:13pm'
    @invoice_number = '12345'
    @invoice_date = '04/16/2012'
    @vendor_name = 'MR Vendor'
    @release_type = '1251'
    @employee_name = 'MIKE'
    @file_logged_date = '12/16/2011'
    @invoice_sequence = 1
    @invoice_page = 1
    @invoice_line = 1
    @part_number = '123BBB'
    @header_po = '123531'
    @detail_po = ''
    @container = 'cont'
    @bill_of_lading = 'mbol'
    @tariff_treatment = '2'
    @hts = '30.30.30.30.03'
    @tariff_provision = '9977'
    @hts_qty = 100
    @hts_uom = 'DOZ'
    @comm_qty = 1200
    @comm_uom = 'PCS'
    @val_for_duty = '23'
    @unit_price = BigDecimal("12.21")
    @line_value = BigDecimal("14652.00")
    @currency = 'USD'
    @exchange_rate = BigDecimal("1.01")
    @entered_value = BigDecimal('14652.01')
    @duty_amount = BigDecimal("813.19")
    @gst_rate_code = '5'
    @gst_amount = BigDecimal("5.05")
    @sima_amount = BigDecimal("8.20")
    @excise_amount = BigDecimal("2.22")
    @excise_rate_code = '3'
    @additional_container_numbers = ['456', '789']
    @additional_cargo_control_numbers = ['asdf', 'sdfa']
    @activities = {
      '180' => [Time.new(2013,4,1,10,0), Time.new(2013,4,1,18,0)],
      '490' => [Time.new(2013,4,2,10,0), Time.new(2013,4,2,18,0)],
      '10' => [Date.new(2013,4,2), Date.new(2013,4,3)]
    }
    @additional_bols = ["123456", "9876542321"]
    @duty_rate = BigDecimal.new "5.55"
    @entry_lambda = lambda { |new_style = true, multi_line = true|
      data = new_style ? "B3L," : ""
      data += "\"#{@barcode}\",#{@file_number},\" 0 \",\"#{@importer_tax_id}\",#{@transport_mode_code},#{@entry_port_code},\"#{@carrier_code}\",\"#{@voyage}\",\"#{@container}\",#{@exit_port_code},#{@entry_type},\"#{@vendor_name}\",\"#{@cargo_control_no}\",\"#{@bill_of_lading}\",\"#{@header_po}\", #{@invoice_sequence} ,\"#{@invoice_number}\",\"#{@ship_terms}\",#{@invoice_date},Net30, 50 , #{@invoice_page} , #{@invoice_line} ,\"#{@part_number}\",\"CAT NOROX MEKP-925H CS560\",\"#{@detail_po}\",#{@country_export_code},#{@country_origin_code}, #{@tariff_treatment} ,\"#{@hts}\",#{@tariff_provision}, #{@hts_qty} ,#{@hts_uom}, #{@val_for_duty} ,\"\", 0 , 1 , #{@comm_qty} ,#{@comm_uom}, #{@unit_price} ,#{@line_value},       967.68,#{@direct_shipment_date},#{@currency}, #{@exchange_rate} ,#{@entered_value}, #{@duty_rate} ,#{@duty_amount}, #{@gst_rate_code} ,#{@gst_amount},#{@sima_amount}, #{@excise_rate_code} ,#{@excise_amount},         48.85,,,#{@duty_due_date},#{@across_sent_date},#{@pars_ack_date},#{@pars_rej_date},,,#{@release_date},#{@cadex_accept_date},#{@cadex_sent_date},,\"\",,,,,,,\"\",\"\",\"\",\"\", 0 , 0 ,, 0 ,01/30/2012,\"#{@employee_name}\",\"#{@release_type}\",\"\",\"N\",\" 0 \",\" 1 \",\"#{@file_logged_date}\",\" \",\"\",\"Roadway Express\",\"\",\"\",\"SYRGIS PERFORMANCE INITIATORS\",\"SYRGIS PERFORMANCE INITIATORS\",\"SYRGIS   \",\"\", 1 ,        967.68,,#{@importer_number},#{@importer_name}"
      if new_style && multi_line
        @additional_container_numbers.each do |container|
          data += "\r\nCON,#{@barcode},#{container}"
        end

        @additional_cargo_control_numbers.each do |ccn|
          data += "\r\nCCN,#{@barcode},#{ccn}"
        end
        
        @activities.each do |activity_number, date_times|
          date_times.each do |date|
            # For some reason Fenix adds spaces before and after the activity number
            time_segment = (date.is_a?(Date) ? "" : date.strftime('%H%M'))
            data += "\r\nSD,#{@barcode},\" #{activity_number} \",#{date.strftime('%Y%m%d')},#{time_segment},USERID,NOTES"
          end
        end

        @additional_bols.each do |bol|
          data += "\r\nBL,#{@barcode},#{bol}"
        end
      end

      data
    }
  end

  def do_shared_test entry_data
    # Make sure the locking mechanism is utilized
    Lock.should_receive(:acquire).with(Lock::FENIX_PARSER_LOCK).and_yield
    
    OpenChain::FenixParser.parse entry_data, {:bucket=>'bucket', :key=>'file/path/b3_detail_rns_114401_2013052958482.1369859062.csv'}
    ent = Entry.find_by_broker_reference @file_number
    ent.last_file_bucket.should == 'bucket'
    ent.last_file_path.should == 'file/path/b3_detail_rns_114401_2013052958482.1369859062.csv'
    ent.import_country.should == Country.find_by_iso_code('CA')
    ent.entry_number.should == @barcode
    ent.importer_tax_id.should == @importer_tax_id
    ent.last_exported_from_source.should == ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("20130529") + Integer(58482).seconds

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
    ent.release_date.should == @est.parse_us_base_format(@release_date.gsub(',',' '))
    ent.cadex_sent_date.should == @est.parse_us_base_format(@cadex_sent_date.gsub(',',' '))
    ent.cadex_accept_date.should == @est.parse_us_base_format(@cadex_accept_date.gsub(',',' '))
    ent.origin_country_codes.should == @country_origin_code
    ent.export_country_codes.should == @country_export_code
    ent.release_type.should == @release_type
    ent.employee_name.should == @employee_name
    ent.file_logged_date.should == @est.parse_us_base_format("#{@file_logged_date},12:00am")
    ent.po_numbers.should == @header_po
    ent.customer_number.should == @importer_number
    ent.customer_name.should == @importer_name
    
    ent.vendor_names.should == @vendor_name
    ent.total_invoiced_value.should == @line_value
    ent.total_duty.should == @duty_amount
    ent.time_to_process.should be > 0
    ent.source_system.should == OpenChain::FenixParser::SOURCE_CODE
    ent.entered_value.should == @entered_value
    ent.commercial_invoice_numbers == @invoice_number

    #commercial invoice header
    ent.commercial_invoices.should have(1).invoice
    ci = ent.commercial_invoices.first
    ci.invoice_number.should == @invoice_number
    ci.invoice_date.should == Date.strptime(@invoice_date,@mdy)
    ci.vendor_name.should == @vendor_name
    ci.currency.should == @currency
    ci.exchange_rate.should == @exchange_rate
    ci.invoice_value.should == @line_value

    ci.commercial_invoice_lines.should have(1).line
    line = ci.commercial_invoice_lines.first
    line.part_number.should == @part_number
    line.country_origin_code.should == @country_origin_code
    line.country_export_code.should == @country_export_code
    line.quantity.should == @comm_qty
    line.unit_of_measure.should == @comm_uom
    line.unit_price.should == @unit_price
    line.value.should == @line_value
    line.line_number.should == 1 

    line.should have(1).commercial_invoice_tariffs
    tar = line.commercial_invoice_tariffs.first
    tar.spi_primary.should == @tariff_treatment
    tar.hts_code.should == @hts
    tar.tariff_provision.should == @tariff_provision
    tar.classification_qty_1.should == @hts_qty
    tar.classification_uom_1.should == @hts_uom
    tar.value_for_duty_code.should == @val_for_duty
    tar.duty_amount.should == @duty_amount
    tar.entered_value.should == @entered_value
    tar.gst_rate_code.should == @gst_rate_code
    tar.gst_amount.should == @gst_amount
    tar.sima_amount.should == @sima_amount
    tar.excise_rate_code.should == @excise_rate_code
    tar.excise_amount.should == @excise_amount
    tar.duty_rate.should == (@duty_rate / 100).round(3)

    ent
  end


  it 'should save an entry with one line' do
    ent = do_shared_test @entry_lambda.call(false)

    # These are file differences that are handled differently now with the new style entry format
    ent.cargo_control_number.should == @cargo_control_no
    ent.container_numbers.should == @container
    ent.first_do_issued_date.should be_nil
    ent.docs_received_date.should be_nil
  end
  
  it 'should save an entry with one main line in the new format' do
    ent = do_shared_test @entry_lambda.call

    # New Entry file differences 
    
    # We're pulling cargo control number from B3L and CCN lines
    ccn = ent.cargo_control_number.split("\n ")
    ccn.length.should == @additional_cargo_control_numbers.length + 1
    ([@cargo_control_no] + @additional_cargo_control_numbers).each do |n|
      ccn.include?(n).should be_true
    end

    # We're pulling container from B3L and CON lines
    containers = ent.container_numbers.split("\n ")
    containers.length.should == @additional_container_numbers.length + 1
    ([@container] + @additional_container_numbers).each do |n|
      containers.include?(n).should be_true
    end
    # Need to use local time since we pulled the entry back from the DB 
    ent.first_do_issued_date.should == @activities['180'][0].in_time_zone(Time.zone)
    # Since the actual date may have crossed date timelines from local to parser time, we need to compare the date against parser time
    ent.docs_received_date.should == @activities['490'][0].in_time_zone(ActiveSupport::TimeZone["Eastern Time (US & Canada)"]).to_date
    ent.eta_date.should == @activities['10'][1]

    # Master Bills should include ones from BL lines
    bols = ent.master_bills_of_lading.split("\n ")
    [@bill_of_lading, @additional_bols].flatten.each {|bol|
      bols.include?(bol).should be_true
    }
    
    # House Bills should be blank
    ent.house_bills_of_lading.should be_nil
  end

  it "should store container numbers in house bills field on air shipments" do
    @transport_mode_code = "1"
    ent = do_shared_test @entry_lambda.call

    # We're pulling container from B3L and CON lines
    house_bills = ent.house_bills_of_lading.split("\n ")
    house_bills.length.should == @additional_container_numbers.length + 1
    ([@container] + @additional_container_numbers).each do |n|
      house_bills.include?(n).should be_true
    end
  end

  it "should store container numbers in house bills field on truck shipments" do
    @transport_mode_code = "2"
    ent = do_shared_test @entry_lambda.call

    # We're pulling container from B3L and CON lines
    house_bills = ent.house_bills_of_lading.split("\n ")
    house_bills.length.should == @additional_container_numbers.length + 1
    ([@container] + @additional_container_numbers).each do |n|
      house_bills.include?(n).should be_true
    end
  end

  it 'should call link_broker_invoices' do
    Entry.any_instance.should_receive :link_broker_invoices
    OpenChain::FenixParser.parse @entry_lambda.call
  end
  it 'should overwrite lines on reprocess' do
    2.times {OpenChain::FenixParser.parse @entry_lambda.call}
    Entry.where(:broker_reference=>@file_number).should have(1).record
    Entry.find_by_broker_reference(@file_number).should have(1).commercial_invoices
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
    ci_line = ent.commercial_invoices.first.commercial_invoice_lines.first
    ci_line.country_origin_code.should == 'US'
    ci_line.country_export_code.should == 'US'
    ci_line.state_origin_code.should == 'IN'
    ci_line.state_export_code.should == 'NJ'
  end
  it 'should 0 pad exit code to 4 chars' do # port ' 708  ' should be '0708'
    @exit_port_code = ' 444 '
    OpenChain::FenixParser.parse @entry_lambda.call
    Entry.find_by_broker_reference(@file_number).us_exit_port_code.should == '0444'
  end

  it 'should parse files with almost no information in them' do
    #extra commas added to pass the line length check
    entry_data = lambda {
      data = '"1234567890",12345,"My Company",TAXID,,,,,,,,'
      data 
    }

    OpenChain::FenixParser.parse entry_data.call
    entry = Entry.find_by_broker_reference 12345
    entry.should_not be_nil
    entry.entry_number.should == "1234567890"
    entry.importer_tax_id.should == "TAXID"
    entry.file_logged_date.should == ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now.midnight
    
    entry.commercial_invoices.length.should == 0
  end

  it 'should read master bills and container numbers for entries without invoice lines' do
    entry_data = lambda {
      data = '"1234567890",12345,"My Company",TAXID,,,,,CONT,,,,,MASTERBILL'
      data 
    }

    OpenChain::FenixParser.parse entry_data.call
    entry = Entry.find_by_broker_reference 12345
    entry.should_not be_nil
    entry.master_bills_of_lading.should == "MASTERBILL"
    entry.container_numbers.should == "CONT"
    
    entry.commercial_invoices.length.should == 0
  end

  it 'should fall back to using entry number and source system lookup to find imaging shell records' do
    existing_entry = Factory(:entry,:entry_number=>@entry_number, :source_system=>OpenChain::FenixParser::SOURCE_CODE)
    
    #extra commas added to pass the line length check
    entry_data = lambda {
      data = "\"#{@entry_number}\",12345,\"My Company\",TAXID,,,,,,,,"
      data 
    }

    OpenChain::FenixParser.parse entry_data.call
    existing_entry.reload

    existing_entry.broker_reference.should == "12345"
    existing_entry.entry_number.should == @entry_number
    existing_entry.importer_tax_id.should == "TAXID"
    existing_entry.file_logged_date.should == ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now.midnight
    
    existing_entry.commercial_invoices.length.should == 0
  end

  it "should skip files with older system export times than current entry" do
    export_date = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("20130529") + Integer(58482).seconds

    Factory(:entry,:broker_reference=>@file_number,:source_system=>OpenChain::FenixParser::SOURCE_CODE, :last_exported_from_source=>export_date)
    # Add a second to the time and make sure the entry has a value to match (.ie it was updated)
    OpenChain::FenixParser.parse @entry_lambda.call, {:key=>'b3_detail_rns_114401_2013052958483.1369859062.csv'}
    entries = Entry.where(:broker_reference=>@file_number)
    entries.should have(1).entries
    # Verify the updated last exported date was used
    entries[0].last_exported_from_source.should == ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("20130529") + Integer(58483).seconds
  end

  it "should process files with same system export times as current entry" do
    # We want to make sure we do reprocess entries with the same export dates, this allows us to run larger
    # reprocess processes to get older data, but then only reprocess the most up to date file.
    export_date = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("20130529") + Integer(58482).seconds
    entry = Factory(:entry,:broker_reference=>@file_number,:source_system=>OpenChain::FenixParser::SOURCE_CODE, :last_exported_from_source=>export_date)
    
    # Add a second to the time and make sure the entry has a value to match (.ie it was updated)
    OpenChain::FenixParser.parse @entry_lambda.call, {:key=>'b3_detail_rns_114401_2013052958482.1369859062.csv'}
    entries = Entry.where(:broker_reference=>@file_number)
    entries.should have(1).entries
   
    # All we really need to do is make sure the entry got saved by the parser and not skipped.
    # Verifying any piece of data not set in the factory is present should be enough to prove this.
    entries[0].entry_number.should == @barcode
  end

  it "should process files missing export date only if entry is missing export date" do
    entry = Factory(:entry,:broker_reference=>@file_number,:source_system=>OpenChain::FenixParser::SOURCE_CODE)
    
    OpenChain::FenixParser.parse @entry_lambda.call
    entries = Entry.where(:broker_reference=>@file_number)
    entries.should have(1).entries
   
    # All we really need to do is make sure the entry got saved by the parser and not skipped.
    # Verifying any piece of data not set in the factory is present should be enough to prove this.
    entries[0].entry_number.should == @barcode
  end

  it "should handle supporting line types with missing entry numbers in them" do
    lines = []

    first_entry_number = @barcode
    first_broker_ref = @file_number

    # Basically, we're splitting the lines up, replacing the 2nd index on non-B3L lines,
    # and then re-assembling the lines
    @entry_lambda.call.split("\r\n").each {|line| lines << line.split(",")}
    lines.each {|line| line[1] == "0000000" if line[0] != "B3L"}
    lines = lines.collect {|line| line.join(",")}.join("\r\n")

    @barcode = "123456"
    @file_number = "987654"

    # Add another b3 after the "invalid" lines to make sure it also gets parsed right
    lines += "\r\n" + @entry_lambda.call(true, false)
  
    OpenChain::FenixParser.parse lines

    entries = Entry.order("entries.id ASC").all
    entries.should have(2).entries

    # The ETA date comes from a SD supporting line, so by checking for it it makes sure we're parsing those lines
    # even if the entry number doesn't match
    entries[0].entry_number.should == first_entry_number
    entries[0].eta_date.should == @activities['10'][1]

    # Make sure we also created that second entry
    entries[1].entry_number.should == @barcode
  end

  it "should handle date time values with missing time components" do
    @release_date = "01/09/2012,"
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    ent.release_date.should == @est.parse_us_base_format(@release_date.gsub(',',' 12:00am'))
  end

  it "should handle date time values with invalid date times" do
    @release_date = "192012,"
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    ent.release_date.should be_nil
  end

  it "should handle 0 for duty rate" do
    @duty_rate = 0
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    ent.commercial_invoice_lines.first.commercial_invoice_tariffs.first.duty_rate.should == BigDecimal("0")
  end

  it "should handle blank duty rate" do
    @duty_rate = ""
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    ent.commercial_invoice_lines.first.commercial_invoice_tariffs.first.duty_rate.should be_nil
  end

  it "should handle specific duty" do 
    # Make sure we're not translating specific duty values like we do for adval duties
    @duty_rate = "1.23"
    @hts_qty = "100.50"
    @duty_amount = "123.62"

    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    ent.commercial_invoice_lines.first.commercial_invoice_tariffs.first.duty_rate.should == BigDecimal(@duty_rate)
    # Make sure we're not truncating the classification quantity
    ent.commercial_invoice_lines.first.commercial_invoice_tariffs.first.classification_qty_1.should == BigDecimal(@hts_qty)
  end

  context 'importer company' do
    it "should create importer" do
      OpenChain::FenixParser.parse @entry_lambda.call
      ent = Entry.find_by_broker_reference @file_number
      imp = ent.importer
      imp.name.should == @importer_name
      imp.fenix_customer_number.should == @importer_tax_id
      imp.should be_importer
    end
    it "should link to existing importer" do
      # Make sure we're not updating importer names that aren't tax ids
      imp = Factory(:company,:fenix_customer_number=>@importer_tax_id,:importer=>true, :name=>"Test")
      OpenChain::FenixParser.parse @entry_lambda.call
      ent = Entry.find_by_broker_reference @file_number
      ent.importer.should == imp
      imp.name.should == "Test"
    end
    it "should update an existing importer's name if the name is the tax id" do
      imp = Factory(:company,:fenix_customer_number=>@importer_tax_id,:importer=>true, :name=>@importer_tax_id)
      OpenChain::FenixParser.parse @entry_lambda.call
      ent = Entry.find_by_broker_reference @file_number
      ent.importer.id.should == imp.id
      ent.importer.name.should == @importer_name
    end
    it "should change the entry's importer id on an update if the importer changed" do
      imp = Factory(:company, fenix_customer_number: "ABC", importer: true)
      updated_imp = Factory(:company, fenix_customer_number: @importer_tax_id,importer: true)
      ent = Factory(:entry, broker_reference: @file_number, source_system: "Fenix", importer: imp)

      OpenChain::FenixParser.parse @entry_lambda.call
      ent = Entry.find_by_broker_reference @file_number
      ent.importer.id.should == updated_imp.id
    end
  end
  context 'multi line' do
    before :each do
      @invoices = [
        {:seq=>1,:inv_num => '12345'},
        {:seq=>2,:inv_num => '5555555'}
      ]
      @multi_line_lambda = lambda {
        data = ""
        @invoices.each_with_index do |inv, i|
          @invoice_number = inv[:inv_num]
          @invoice_sequence = inv[:seq]
          @detail_po = inv[:detail_po] if inv[:detail_po]
          @bill_of_lading = inv[:bol] if inv[:bol]
          @container = inv[:cont] if inv[:cont]
          @vendor_name = inv[:vend] if inv[:vend]
          @country_origin_code = inv[:org] if inv[:org]
          @country_export_code = inv[:exp] if inv[:exp]
          @comm_qty = inv[:cq] if inv[:cq]
          @line_value = inv[:line_val] if inv[:line_val]
          @duty_amount = inv[:duty] if inv[:duty]
          @entered_value = inv[:entered_value] if inv[:entered_value]
          @gst_amount = inv[:gst_amount] if inv[:gst_amount]
          @part_number = inv[:part_number] if inv[:part_number]
          data += @entry_lambda.call(true, i==0)+"\r\n"
        end
        data.strip
      }  
      
    end
    it 'should total entered value' do
      @invoices[0][:entered_value]=1
      @invoices[1][:entered_value]=2
      OpenChain::FenixParser.parse @multi_line_lambda.call
      Entry.find_by_broker_reference(@file_number).entered_value.should == 3
    end
    it 'should total GST' do
      @invoices[0][:duty] = 2
      @invoices[0][:gst_amount] = 4
      @invoices[1][:duty] = 6 
      @invoices[1][:gst_amount] = 5
      OpenChain::FenixParser.parse @multi_line_lambda.call
      ent = Entry.find_by_broker_reference(@file_number)
      ent.total_gst.should == 9
      ent.total_duty_gst.should == 17
    end
    it 'should save an entry with multiple invoices' do 
      OpenChain::FenixParser.parse @multi_line_lambda.call
      entries = Entry.where(:broker_reference=>@file_number)
      entries.should have(1).entry
      entries.first.should have(2).commercial_invoices
    end
    it 'should save multiple invoice lines for the same invoice' do
      @invoices[1][:seq]=1 #make both invoices part of same sequence
      OpenChain::FenixParser.parse @multi_line_lambda.call
      entries = Entry.where(:broker_reference=>@file_number)
      entries.should have(1).entry
      entries.first.should have(1).commercial_invoices
      entries.first.commercial_invoices.first.should have(2).commercial_invoice_lines
      entries.first.commercial_invoices.first.commercial_invoice_lines.first.line_number.should == 1
      entries.first.commercial_invoices.first.commercial_invoice_lines.last.line_number.should == 2
    end
    it 'should overwrite header PO if populated in description 2 field' do
      @invoices[0][:detail_po] = 'a'
      @invoices[1][:detail_po] = 'b'
      OpenChain::FenixParser.parse @multi_line_lambda.call
      ent = Entry.find_by_broker_reference @file_number
      ent.commercial_invoices.first.commercial_invoice_lines.first.po_number.should == 'a'
      ent.commercial_invoices.last.commercial_invoice_lines.first.po_number.should == 'b'
      ent.po_numbers.should == "a\n b"
    end
    context 'accumulate fields' do
      it 'invoice value - different invoices' do
        ['19.10','20.03'].each_with_index {|b,i| @invoices[i][:line_val]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        ent = Entry.find_by_broker_reference(@file_number)
        ent.total_invoiced_value.should == BigDecimal('39.13')
        invoice_vals = ent.commercial_invoices.collect {|i| i.invoice_value}
        invoice_vals.should == [BigDecimal('19.10'),BigDecimal('20.03')]
      end
      it 'invoice value - same invoices' do
        ['19.10','20.03'].each_with_index {|b,i| 
          @invoices[i][:line_val]=b
          @invoices[i][:seq]=1
        }
        OpenChain::FenixParser.parse @multi_line_lambda.call
        ent = Entry.find_by_broker_reference(@file_number)
        ent.total_invoiced_value.should == BigDecimal('39.13')
        ent.should have(1).commercial_invoices
        ent.commercial_invoices.first.invoice_value.should == BigDecimal('39.13')
      end
      it 'duty amount' do
        ['9.10','10.10'].each_with_index {|b,i| @invoices[i][:duty]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        Entry.find_by_broker_reference(@file_number).total_duty.should == BigDecimal('19.20')
      end
      it 'units' do
        ['50.12','18.15'].each_with_index {|b,i| @invoices[i][:cq]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        Entry.find_by_broker_reference(@file_number).total_units.should == BigDecimal('68.27')
      end
      it 'bills of lading' do
        # Disable the additional BL lines
        @additional_bols = []
        ['x','y'].each_with_index {|b,i| @invoices[i][:bol]=b} 
        OpenChain::FenixParser.parse @multi_line_lambda.call
        Entry.find_by_broker_reference(@file_number).master_bills_of_lading.should == "x\n y"
      end
      it 'vendor names' do
        ['x','y'].each_with_index {|b,i| @invoices[i][:vend]=b} 
        OpenChain::FenixParser.parse @multi_line_lambda.call
        Entry.find_by_broker_reference(@file_number).vendor_names.should == "x\n y"
      end
      it 'origin country codes' do
        ['CN','UIN'].each_with_index {|b,i| @invoices[i][:org]=b} 
        OpenChain::FenixParser.parse @multi_line_lambda.call
        Entry.find_by_broker_reference(@file_number).origin_country_codes.should == "CN\n US"
      end
      it 'export country codes' do
        ['PR','UNJ'].each_with_index {|b,i| @invoices[i][:exp]=b} 
        OpenChain::FenixParser.parse @multi_line_lambda.call
        Entry.find_by_broker_reference(@file_number).export_country_codes.should == "PR\n US"
      end
      it 'origin state codes' do
        ['CN','UIN'].each_with_index {|b,i| @invoices[i][:org]=b} 
        OpenChain::FenixParser.parse @multi_line_lambda.call
        Entry.find_by_broker_reference(@file_number).origin_state_codes.should == "IN"
      end
      it 'export state codes' do
        ['UNV','UIN'].each_with_index {|b,i| @invoices[i][:exp]=b} 
        OpenChain::FenixParser.parse @multi_line_lambda.call
        Entry.find_by_broker_reference(@file_number).export_state_codes.should == "NV\n IN"
      end
      it 'container numbers' do
        ['x','y'].each_with_index {|b,i| @invoices[i][:cont]=b} 
        OpenChain::FenixParser.parse @multi_line_lambda.call
        containers = Entry.find_by_broker_reference(@file_number).container_numbers.split("\n ")
        # Make sure we're accounting for the container numbers pulled from the CON records
        containers.include?('x').should be_true
        containers.include?('y').should be_true
        @additional_container_numbers.each do |c|
          containers.include?(c).should be_true
        end
      end
      it "part numbers" do
        ['x','y'].each_with_index {|b,i| @invoices[i][:part_number]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        Entry.find_by_broker_reference(@file_number).part_numbers.should == "x\n y"
      end
      it "invoice numbers" do
        OpenChain::FenixParser.parse @multi_line_lambda.call
        Entry.find_by_broker_reference(@file_number).commercial_invoice_numbers.split("\n ").should == [@invoices[0][:inv_num], @invoices[1][:inv_num]]
      end

      it "should not use bols that are 15 chars long and are subsets of a BL line number" do
        # This is a stupid RL workaround to allow them to use more than the max # of chars for a 
        # master bill.  When they use an extra long BOL, the portion of the number that doesn't overflow
        # the field is keyed into the standard header level field.  We don't want that value to show
        # in the system (since it's essentially a nonsense number at this point).
        @additional_bols = ["abcd", "1234567890123456789"]
        ["123456789012345",'y'].each_with_index {|b,i| @invoices[i][:bol]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        entry = Entry.find_by_broker_reference(@file_number)
        bols = entry.master_bills_of_lading.split("\n ")
        [@additional_bols, "y"].flatten.each do |bol|
          bols.include?(bol).should be_true
        end

        bols.include?("123456789012345").should be_false
      end
    end
  end
  describe 'process_past_days' do
    it "should delay processing" do
      OpenChain::FenixParser.should_receive(:delay).exactly(3).times.and_return(OpenChain::FenixParser)
      OpenChain::FenixParser.should_receive(:process_day).exactly(3).times
      OpenChain::FenixParser.process_past_days 3
    end
  end
  describe 'process_day' do
    it 'should process all files from the given day' do
      d = Date.new
      OpenChain::S3.should_receive(:integration_keys).with(d,"/opt/wftpserver/ftproot/www-vfitrack-net/_fenix").and_yield("a").and_yield("b")
      OpenChain::S3.should_receive(:get_data).with(OpenChain::S3.integration_bucket_name,"a").and_return("x")
      OpenChain::S3.should_receive(:get_data).with(OpenChain::S3.integration_bucket_name,"b").and_return("y")
      OpenChain::FenixParser.should_receive(:parse).with("x",{:bucket=>OpenChain::S3.integration_bucket_name,:key=>"a",:imaging=>false})
      OpenChain::FenixParser.should_receive(:parse).with("y",{:bucket=>OpenChain::S3.integration_bucket_name,:key=>"b",:imaging=>false})
      OpenChain::FenixParser.process_day d
    end
  end
end
