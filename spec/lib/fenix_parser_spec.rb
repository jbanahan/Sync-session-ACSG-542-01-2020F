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
    @duty_amount = BigDecimal("1.27")
    @gst_rate_code = '5'
    @gst_amount = BigDecimal("5.05")
    @sima_amount = BigDecimal("8.20")
    @excise_amount = BigDecimal("2.22")
    @excise_rate_code = '3'
    @entry_lambda = lambda { |new_style = false|
      data = new_style ? "B3L," : ""
      data += "\"#{@barcode}\",#{@file_number},\" 0 \",\"#{@importer_tax_id}\",#{@transport_mode_code},#{@entry_port_code},\"#{@carrier_code}\",\"#{@voyage}\",\"#{@container}\",#{@exit_port_code},#{@entry_type},\"#{@vendor_name}\",\"#{@cargo_control_no}\",\"#{@bill_of_lading}\",\"#{@header_po}\", #{@invoice_sequence} ,\"#{@invoice_number}\",\"#{@ship_terms}\",#{@invoice_date},Net30, 50 , #{@invoice_page} , #{@invoice_line} ,\"#{@part_number}\",\"CAT NOROX MEKP-925H CS560\",\"#{@detail_po}\",#{@country_export_code},#{@country_origin_code}, #{@tariff_treatment} ,\"#{@hts}\",#{@tariff_provision}, #{@hts_qty} ,#{@hts_uom}, #{@val_for_duty} ,\"\", 0 , 1 , #{@comm_qty} ,#{@comm_uom}, #{@unit_price} ,#{@line_value},       967.68,#{@direct_shipment_date},#{@currency}, #{@exchange_rate} ,#{@entered_value}, 0 ,#{@duty_amount}, #{@gst_rate_code} ,#{@gst_amount},#{@sima_amount}, #{@excise_rate_code} ,#{@excise_amount},         48.85,,,#{@duty_due_date},#{@across_sent_date},#{@pars_ack_date},#{@pars_rej_date},,,#{@release_date},#{@cadex_accept_date},#{@cadex_sent_date},,\"\",,,,,,,\"\",\"\",\"\",\"\", 0 , 0 ,, 0 ,01/30/2012,\"#{@employee_name}\",\"#{@release_type}\",\"\",\"N\",\" 0 \",\" 1 \",\"#{@file_logged_date}\",\" \",\"\",\"Roadway Express\",\"\",\"\",\"SYRGIS PERFORMANCE INITIATORS\",\"SYRGIS PERFORMANCE INITIATORS\",\"SYRGIS   \",\"\", 1 ,        967.68"
      data
    }
  end
  it 'should save an entry with one line' do
    OpenChain::FenixParser.parse @entry_lambda.call, {:bucket=>'bucket', :key=>'key'}
    ent = Entry.find_by_broker_reference @file_number
    ent.last_file_bucket.should == 'bucket'
    ent.last_file_path.should == 'key'
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
    ent.release_date.should == @est.parse_us_base_format(@release_date.gsub(',',' '))
    ent.cadex_sent_date.should == @est.parse_us_base_format(@cadex_sent_date.gsub(',',' '))
    ent.cadex_accept_date.should == @est.parse_us_base_format(@cadex_accept_date.gsub(',',' '))
    ent.origin_country_codes.should == @country_origin_code
    ent.export_country_codes.should == @country_export_code
    ent.release_type.should == @release_type
    ent.employee_name.should == @employee_name
    ent.file_logged_date.should == @est.parse_us_base_format("#{@file_logged_date},12:00am")
    ent.po_numbers.should == @header_po
    ent.container_numbers.should == @container
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

  it 'should skip newstyle lines (for now)' do
    data = @entry_lambda.call(true)
    data += "\nSD,#{@barcode},12345,,,,,\nCCN,12345,987454\nCON,12345,65456546"

    OpenChain::FenixParser.any_instance.should_not_receive(:parse_entry)
    OpenChain::FenixParser.parse data
  end

  it 'should skip newstyle lines (for now) but handle oldstyle ones' do
    data = @entry_lambda.call(true)
    data += "\nSD,#{@barcode},12345,,,,,\nCCN,12345,987454\nCON,12345,65456546\n"
    data += @entry_lambda.call

    OpenChain::FenixParser.parse data

    ent = Entry.find_by_broker_reference @file_number
    ent.should_not be_nil
  end

  context 'importer company' do
    it "should create importer" do
      OpenChain::FenixParser.parse @entry_lambda.call
      ent = Entry.find_by_broker_reference @file_number
      imp = ent.importer
      imp.name.should == @importer_tax_id
      imp.fenix_customer_number.should == @importer_tax_id
      imp.should be_importer
    end
    it "should link to existing importer" do
      imp = Factory(:company,:fenix_customer_number=>@importer_tax_id,:importer=>true)
      OpenChain::FenixParser.parse @entry_lambda.call
      ent = Entry.find_by_broker_reference @file_number
      ent.importer.should == imp
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
        @invoices.each do |inv|
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
          data += @entry_lambda.call+"\r\n"
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
        Entry.find_by_broker_reference(@file_number).container_numbers.should == "x\n y"
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
