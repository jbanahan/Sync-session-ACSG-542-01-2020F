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
    @entry_port_code = '0456'
    @carrier_code = '1234'
    @carrier_name = 'Carrier'
    @voyage = '19191'
    @exit_port_code = '0708'
    @entry_type = 'AB'
    @country_export_code='CN'
    @country_origin_code='VN'
    @duty_due_date = '01/26/2012'
    @across_sent_date = '01/27/2012,09:24am'
    @pars_ack_date = '01/28/2012,11:15am'
    @pars_rej_date = '01/08/2012,11:15am'
    @release_date = '09/20/2015,11:19am'
    @cadex_sent_date = '01/10/2012,12:15pm'
    @cadex_accept_date = '01/11/2012,01:13pm'
    @invoice_number = '12345'
    @invoice_date = '04/16/2012'
    @vendor_name = 'MR Vendor'
    @vendor_number = "12345"
    @release_type = '1251'
    @employee_name = 'MIKE'
    @activity_employee_name = 'DAVE'
    @file_logged_date = '12/16/2011'
    @invoice_sequence = 1
    @invoice_page = 1
    @invoice_line = 1
    @part_number = '123BBB'
    @tariff_desc = "Tariff Description With Windows-1252 Char 100µl"
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
    @exchange_rate = BigDecimal("1.01")
    @invoice_value = BigDecimal("14798.52") # = line_value * exchange_rate
    @entered_value = BigDecimal('14652.01')
    @currency = 'USD'
    @duty_amount = BigDecimal("813.19")
    @gst_rate_code = '5'
    @gst_amount = BigDecimal("5.05")
    @sima_amount = BigDecimal("8.20")
    @sima_code = "1"
    @excise_amount = BigDecimal("2.22")
    @excise_rate_code = '3'
    @adjusted_vcc = BigDecimal("1.05") + @line_value
    @adjustments_per_piece = BigDecimal("0.25")
    @additional_container_numbers = ['456', '789']
    @additional_cargo_control_numbers = ['asdf', 'sdfa']
    @activities = {
      '180' => [Time.new(2013,4,1,10,0), Time.new(2013,4,1,18,0)],
      '490' => [Time.new(2013,4,2,10,0), Time.new(2013,4,2,18,0)],
      '10' => [Date.new(2013,4,2), Date.new(2013,4,3)],
      '1276' => [Time.new(2013,4,4,10,0), Time.new(2013,4,4,18,0)],
      '5' => [Time.new(2013,4,4,10,0)],
      '105' => [Time.new(2014,9,3,12,2), Time.new(2014,9,3,7,57)]
    }
    # Note the values stored as dates are sent in such a manner that if they're improperly handled
    # in the parser will show the incorrect date value (.ie they'll be rolled forward a day when they shouldn't)
    @new_activities = {
      'DOGIVEN' => [Time.new(2015,4,1,10,0), Time.new(2015,4,1,18,0)],
      'DOCREQ' => [Time.new(2015,4,2,23,0), Time.new(2015,4,2,23,0)],
      'ETA' => [Date.new(2015,4,2), Date.new(2015,4,3)],
      'RNSCUSREL' => [Time.new(2015,9,8,12,2), Time.new(2015,9,9,12,2)],
      'CADXTRAN' => [Time.new(2015,9,10,12,2), Time.new(2015,9,11,12,2)],
      'CADXACCP' => [Time.new(2015,9,12,12,2), Time.new(2015,9,13,12,2)],
      'ACSREFF' => [Time.new(2015,4,4,10,0), Time.new(2015,4,4,18,0)],
      'CADK84REC' => [Time.new(2015,4,4,23,59)],
      'B3P' => [Time.new(2015,9,3,12,2), Time.new(2015,9,3,7,57)],
      'KPIDOC' => [Time.new(2017,7,7,12,2), Time.new(2017,7,7,7,57)],
      'KPIPO' => [Time.new(2017,7,8,12,2), Time.new(2017,7,8,7,57)],
      'KPIHTS' => [Time.new(2017,7,9,12,2), Time.new(2017,7,9,7,57)],
      'KPIOGD' => [Time.new(2017,7,10,12,2), Time.new(2017,7,10,7,57)],
      'KPIVAL' => [Time.new(2017,7,11,12,2), Time.new(2017,7,11,7,57)],
      'KPIPART' => [Time.new(2017,7,12,12,2), Time.new(2017,7,12,7,57)],
      'KPIIOR' => [Time.new(2017,7,13,12,2), Time.new(2017,7,13,7,57)],
      "MANINFREC" => [Time.new(2017,7,14,12,2), Time.new(2017,7,14,7,57)],
      "SPLITSHPT" => [Time.new(2017,7,15,12,2), Time.new(2017,7,15,7,57)],
      "ACSDECACCP" => [Time.new(2017,7,14,12,2), Time.new(2017,7,14,7,57)]
    }
    @use_new_activities = false
    @additional_bols = ["123456", "9876542321"]
    @duty_rate = BigDecimal.new "5.55"
    @customer_reference = "REFERENCE #"
    @number_of_pieces = "99"
    @gross_weight = "25.50"
    @consignee_name = "Consignee"
    @b3_line_number = 25
    @subheader_number = 3
    @special_authority = "123-456"

    # Timestamp is also the indicator to the parser that the file is from Fenix ND...which should be what we default to now
    @timestamp = ["T", "20150904", "201516"]
    @entry_lambda = lambda { |new_style = true, multi_line = true, time_stamp = true|
      data = ""
      data += (@timestamp.join(", ") + "\r\n") if time_stamp
      data += new_style ? "B3L," : ""
      data += "\"#{@barcode}\",#{@file_number},\" 0 \",\"#{@importer_tax_id}\",#{@transport_mode_code},#{@entry_port_code},\"#{@carrier_code}\",\"#{@voyage}\",\"#{@container}\",#{@exit_port_code},#{@entry_type},\"#{@vendor_name}\",\"#{@cargo_control_no}\",\"#{@bill_of_lading}\",\"#{@header_po}\", #{@invoice_sequence} ,\"#{@invoice_number}\",\"#{@ship_terms}\",#{@invoice_date},Net30, 50 , #{@invoice_page} , #{@invoice_line} ,\"#{@part_number}\",\"#{@tariff_desc}\",\"#{@detail_po}\",#{@country_export_code},#{@country_origin_code}, #{@tariff_treatment} ,\"#{@hts}\",#{@tariff_provision}, #{@hts_qty} ,#{@hts_uom}, #{@val_for_duty} ,#{@special_authority}, #{@sima_code} , 1 , #{@comm_qty} ,#{@comm_uom}, #{@unit_price} ,#{@line_value},       967.68,#{@direct_shipment_date},#{@currency}, #{@exchange_rate} ,#{@entered_value}, #{@duty_rate} ,#{@duty_amount}, #{@gst_rate_code} ,#{@gst_amount},#{@sima_amount}, #{@excise_rate_code} ,#{@excise_amount},         48.85,,,#{@duty_due_date},#{@across_sent_date},#{@pars_ack_date},#{@pars_rej_date},,,#{@release_date},#{@cadex_accept_date},#{@cadex_sent_date},,\"\",,,,,,,\"\",\"\",\"\",\"\", 0 , 0 ,, 0 ,01/30/2012,\"#{@employee_name}\",\"#{@release_type}\",\"\",\"N\",\" #{@b3_line_number} \",\" #{@subheader_number} \",\"#{@file_logged_date}\",\" \",\"\",\"#{@carrier_name}\",\"#{@consignee_name}\",\"PURCHASER\",\"SHIPPER\",\"EXPORTER\",\"#{@vendor_number}\",\"#{@customer_reference}\", 1 ,        #{@adjusted_vcc},,#{@importer_number},#{@importer_name},#{@number_of_pieces},#{@gross_weight},,,#{@adjustments_per_piece}"
      if new_style && multi_line
        @additional_container_numbers.each do |container|
          data += "\r\nCON,#{@barcode},#{container}"
        end

        @additional_cargo_control_numbers.each do |ccn|
          data += "\r\nCCN,#{@barcode},#{ccn}"
        end

        activities = @use_new_activities ? @new_activities : @activities

        activities.each do |activity_number, date_times|
          date_times.each do |date|
            time_segment = (date.is_a?(Date) ? "" : date.strftime('%H%M'))
            user = (activity_number == "5" ? @activity_employee_name : "USERID")

            # For some reason Fenix adds spaces before and after the activity number
            data += "\r\nSD,#{@barcode},\" #{activity_number} \",#{date.strftime('%Y%m%d')},#{time_segment},#{user},NOTES"
          end
        end

        @additional_bols.each do |bol|
          data += "\r\nBL,#{@barcode},#{bol}"
        end
      end

      data.encode "Windows-1252"
    }

    @broadcasted_event = nil
    allow_any_instance_of(Entry).to receive(:broadcast_event) do |instance, event|
      @broadcasted_event = event
    end
  end

  def do_shared_test entry_data
    # Make sure the locking mechanism is utilized
    expect(Lock).to receive(:acquire).with(Lock::FENIX_PARSER_LOCK, times:3).and_yield

    OpenChain::FenixParser.parse entry_data, {:bucket=>'bucket', :key=>'file/path/b3_detail_rns_114401_2013052958482.1369859062.csv'}
    ent = Entry.find_by_broker_reference @file_number
    expect(ent.last_file_bucket).to eq('bucket')
    expect(ent.last_file_path).to eq('file/path/b3_detail_rns_114401_2013052958482.1369859062.csv')
    expect(ent.import_country).to eq(Country.find_by_iso_code('CA'))
    expect(ent.entry_number).to eq(@barcode)
    expect(ent.importer_tax_id).to eq(@importer_tax_id)
    expect(ent.last_exported_from_source).to eq(ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("20150904201516"))

    expect(ent.ship_terms).to eq(@ship_terms.upcase)
    expect(ent.direct_shipment_date).to eq(Date.strptime(@direct_shipment_date, @mdy))
    expect(ent.transport_mode_code).to eq(@transport_mode_code.strip)
    expect(ent.entry_port_code).to eq(@entry_port_code)
    expect(ent.carrier_code).to eq(@carrier_code)
    expect(ent.carrier_name).to eq(@carrier_name)
    expect(ent.voyage).to eq(@voyage)
    expect(ent.us_exit_port_code).to eq(@exit_port_code)
    expect(ent.entry_type).to eq(@entry_type)
    expect(ent.duty_due_date).to eq(Date.strptime(@duty_due_date, @mdy))
    expect(ent.across_sent_date).to eq(@est.parse_us_base_format(@across_sent_date.gsub(',',' ')))
    expect(ent.entry_filed_date).to eq(ent.across_sent_date)
    expect(ent.pars_ack_date).to eq(@est.parse_us_base_format(@pars_ack_date.gsub(',',' ')))
    expect(ent.first_release_date).to eq(ent.pars_ack_date)
    expect(ent.pars_reject_date).to eq(@est.parse_us_base_format(@pars_rej_date.gsub(',',' ')))
    expect(ent.release_date).to eq(@est.parse_us_base_format(@release_date.gsub(',',' ')))
    expect(ent.cadex_sent_date).to eq(@est.parse_us_base_format(@cadex_sent_date.gsub(',',' ')))
    expect(ent.cadex_accept_date).to eq(@est.parse_us_base_format(@cadex_accept_date.gsub(',',' ')))
    expect(ent.k84_month).to eq(1)
    expect(ent.origin_country_codes).to eq(@country_origin_code)
    expect(ent.export_country_codes).to eq(@country_export_code)
    expect(ent.release_type).to eq(@release_type)
    expect(ent.file_logged_date).to eq(@est.parse_us_base_format("#{@file_logged_date},12:00am"))
    expect(ent.po_numbers).to eq(@header_po)
    expect(ent.customer_number).to eq(@importer_number)
    expect(ent.customer_name).to eq(@importer_name)
    expect(ent.customer_references).to eq(@customer_reference)

    expect(ent.vendor_names).to eq(@vendor_name)
    expect(ent.total_invoiced_value).to eq(@line_value)
    expect(ent.total_duty).to eq(@duty_amount)
    expect(ent.time_to_process).to be > 0
    expect(ent.source_system).to eq(OpenChain::FenixParser::SOURCE_CODE)
    expect(ent.entered_value).to eq(@entered_value)
    expect(ent.commercial_invoice_numbers).to eq(@invoice_number)
    expect(ent.gross_weight).to eq(@gross_weight.to_i)
    expect(ent.total_packages).to eq(@number_of_pieces.to_i)
    expect(ent.total_packages_uom).to eq("PKGS")
    expect(ent.ult_consignee_name).to eq(@consignee_name)
    expect(ent.summary_line_count).to eq 25

    #commercial invoice header
    expect(ent.commercial_invoices.size).to eq(1)
    ci = ent.commercial_invoices.first
    expect(ci.invoice_number).to eq(@invoice_number)
    expect(ci.invoice_date).to eq(Date.strptime(@invoice_date,@mdy))
    expect(ci.vendor_name).to eq(@vendor_name)
    expect(ci.mfid).to eq(@vendor_number)
    expect(ci.currency).to eq(@currency)
    expect(ci.exchange_rate).to eq(@exchange_rate)
    expect(ci.invoice_value).to eq(@invoice_value)

    expect(ci.commercial_invoice_lines.size).to eq(1)
    line = ci.commercial_invoice_lines.first
    expect(line.part_number).to eq(@part_number)
    expect(line.country_origin_code).to eq(@country_origin_code)
    expect(line.country_export_code).to eq(@country_export_code)
    expect(line.quantity).to eq(@comm_qty)
    expect(line.unit_of_measure).to eq(@comm_uom)
    expect(line.unit_price).to eq(@unit_price)
    expect(line.value).to eq(@line_value)
    expect(line.line_number).to eq(1)
    expect(line.customer_reference).to eq(@customer_reference)
    expect(line.adjustments_amount).to eq(BigDecimal(".25"))
    expect(line.customs_line_number).to eq(@b3_line_number)
    expect(line.subheader_number).to eq(@subheader_number)

    expect(line.commercial_invoice_tariffs.size).to eq(1)
    tar = line.commercial_invoice_tariffs.first
    expect(tar.spi_primary).to eq(@tariff_treatment)
    expect(tar.hts_code).to eq(@hts)
    expect(tar.tariff_provision).to eq(@tariff_provision)
    expect(tar.classification_qty_1).to eq(@hts_qty)
    expect(tar.classification_uom_1).to eq(@hts_uom)
    expect(tar.value_for_duty_code).to eq(@val_for_duty)
    expect(tar.duty_amount).to eq(@duty_amount)
    expect(tar.entered_value).to eq(@entered_value)
    expect(tar.gst_rate_code).to eq(@gst_rate_code)
    expect(tar.gst_amount).to eq(@gst_amount)
    expect(tar.sima_amount).to eq(@sima_amount)
    expect(tar.sima_code).to eq(@sima_code)
    expect(tar.excise_rate_code).to eq(@excise_rate_code)
    expect(tar.excise_amount).to eq(@excise_amount)
    expect(tar.duty_rate).to eq((@duty_rate / 100).round(3))
    expect(tar.tariff_description).to eq(@tariff_desc)
    expect(tar.special_authority).to eq(@special_authority)

    expect(@broadcasted_event).to eq(:save)

    expect(ent.entity_snapshots.length).to eq 1
    ent
  end

  it "sets hold-date fields correctly" do
    @release_date = nil
    expect(Lock).to receive(:acquire).with(Lock::FENIX_PARSER_LOCK, times:3).and_yield

    OpenChain::FenixParser.parse @entry_lambda.call(true), {:bucket=>'bucket', :key=>'file/path/b3_detail_rns_114401_2013052958482.1369859062.csv'}
    ent = Entry.find_by_broker_reference @file_number

    expect(ent.on_hold).to eq true
    expect(ent.hold_date).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(@activities['1276'][1].to_s).in_time_zone(Time.zone)
    expect(ent.hold_release_date).to be_nil
    expect(ent.exam_release_date).to be_nil
  end

  it "sets hold-release date fields correctly" do
    # ent = do_shared_test @entry_lambda.call(false)
    expect(Lock).to receive(:acquire).with(Lock::FENIX_PARSER_LOCK, times:3).and_yield

    OpenChain::FenixParser.parse @entry_lambda.call(false), {:bucket=>'bucket', :key=>'file/path/b3_detail_rns_114401_2013052958482.1369859062.csv'}
    ent = Entry.find_by_broker_reference @file_number


    expect(ent.on_hold).to eq false
    expect(ent.hold_date).to be_nil
    expect(ent.hold_release_date.strftime("%m/%d/%Y")).to eq @release_date[0, 10]
    expect(ent.exam_release_date.strftime("%m/%d/%Y")).to eq @release_date[0, 10]
  end

  it 'should save an entry with one line' do
    ent = do_shared_test @entry_lambda.call(false)

    # These are file differences that are handled differently now with the new style entry format
    expect(ent.cargo_control_number).to eq(@cargo_control_no)
    expect(ent.container_numbers).to eq(@container)
    expect(ent.first_do_issued_date).to be_nil
    expect(ent.docs_received_date).to be_nil
    expect(ent.exam_ordered_date).to be_nil
    expect(ent.employee_name).to eq(@employee_name)
  end

  it 'should save an entry with one main line in the new format' do
    # Wrap this in a block using another timezone so we know that the dates we parse out are all relative to Eastern timezone.
    Time.use_zone("Hawaii") do
      ent = do_shared_test @entry_lambda.call

      # New Entry file differences

      # We're pulling cargo control number from B3L and CCN lines
      ccn = ent.cargo_control_number.split("\n ")
      expect(ccn.length).to eq(@additional_cargo_control_numbers.length + 1)
      ([@cargo_control_no] + @additional_cargo_control_numbers).each do |n|
        expect(ccn.include?(n)).to be_truthy
      end

      # We're pulling container from B3L and CON lines
      containers = ent.container_numbers.split("\n ")
      expect(containers.length).to eq(@additional_container_numbers.length + 1)
      ([@container] + @additional_container_numbers).each do |n|
        expect(containers.include?(n)).to be_truthy
      end
      # Need to use local time since we pulled the entry back from the DB
      expect(ent.first_do_issued_date).to eq(ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(@activities['180'][0].to_s).in_time_zone(Time.zone))
      # Since the actual date may have crossed date timelines from local to parser time, we need to compare the date against parser time
      expect(ent.docs_received_date).to eq(@activities['490'][0].in_time_zone(ActiveSupport::TimeZone["Eastern Time (US & Canada)"]).to_date)
      expect(ent.eta_date).to eq(@activities['10'][1])
      expect(ent.exam_ordered_date).to eq(ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(@activities['1276'][1].to_s).in_time_zone(Time.zone))
      expect(ent.b3_print_date).to eq(ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(@activities['105'][1].to_s).in_time_zone(Time.zone))

      # Master Bills should include ones from BL lines
      bols = ent.master_bills_of_lading.split("\n ")
      [@bill_of_lading, @additional_bols].flatten.each {|bol|
        expect(bols.include?(bol)).to be_truthy
      }

      # House Bills should be blank
      expect(ent.house_bills_of_lading).to be_nil

      expect(ent.employee_name).to eq(@activity_employee_name)
    end
  end

  it "should store container numbers in house bills field on air shipments" do
    @transport_mode_code = "1"
    ent = do_shared_test @entry_lambda.call

    # We're pulling container from B3L and CON lines
    house_bills = ent.house_bills_of_lading.split("\n ")
    expect(house_bills.length).to eq(@additional_container_numbers.length + 1)
    ([@container] + @additional_container_numbers).each do |n|
      expect(house_bills.include?(n)).to be_truthy
    end
  end

  it "should store container numbers in house bills field on truck shipments" do
    @transport_mode_code = "2"
    ent = do_shared_test @entry_lambda.call

    # We're pulling container from B3L and CON lines
    house_bills = ent.house_bills_of_lading.split("\n ")
    expect(house_bills.length).to eq(@additional_container_numbers.length + 1)
    ([@container] + @additional_container_numbers).each do |n|
      expect(house_bills.include?(n)).to be_truthy
    end
  end

  it 'should call link_broker_invoices' do
    expect_any_instance_of(Entry).to receive :link_broker_invoices
    OpenChain::FenixParser.parse @entry_lambda.call
  end
  it 'should overwrite lines on reprocess' do
    2.times {OpenChain::FenixParser.parse @entry_lambda.call}
    expect(Entry.where(:broker_reference=>@file_number).size).to eq(1)
    expect(Entry.find_by_broker_reference(@file_number).commercial_invoices.size).to eq(1)
  end
  it "should zero pad port codes" do
    @entry_port_code = '1'
    OpenChain::FenixParser.parse @entry_lambda.call
    expect(Entry.first.entry_port_code).to eq('0001')
  end


  it 'should handle blank date time' do
    @across_sent_date = ','
    OpenChain::FenixParser.parse @entry_lambda.call
    expect(Entry.find_by_broker_reference(@file_number).across_sent_date).to be_nil
  end
  it 'should find exit port in schedule d' do
    @exit_port_code = '1234'
    port = Factory(:port,:schedule_d_code=>@exit_port_code)
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    expect(ent.us_exit_port).to eq(port)
  end
  it 'should only update entries with Fenix as source code' do
    Factory(:entry,:broker_reference=>@file_number) #not source code
    OpenChain::FenixParser.parse @entry_lambda.call
    expect(Entry.where(:broker_reference=>@file_number).entries.size).to eq(2)
  end
  it 'should update if fenix is source code' do
    Factory(:entry,:broker_reference=>@file_number,:source_system=>OpenChain::FenixParser::SOURCE_CODE) #not source code
    OpenChain::FenixParser.parse @entry_lambda.call
    expect(Entry.where(:broker_reference=>@file_number).entries.size).to eq(1)
  end
  it 'should split origin/export country codes that are 3 digits starting w/ U into US & state code' do
    @country_origin_code = 'UIN'
    @country_export_code = 'UNJ'
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    expect(ent.origin_country_codes).to eq('US')
    expect(ent.export_country_codes).to eq('US')
    expect(ent.export_state_codes).to eq('NJ')
    expect(ent.origin_state_codes).to eq('IN')
    ci_line = ent.commercial_invoices.first.commercial_invoice_lines.first
    expect(ci_line.country_origin_code).to eq('US')
    expect(ci_line.country_export_code).to eq('US')
    expect(ci_line.state_origin_code).to eq('IN')
    expect(ci_line.state_export_code).to eq('NJ')
  end
  it 'should 0 pad exit code to 4 chars' do
    # port ' 708  ' should be '0708'
    @exit_port_code = ' 444 '
    OpenChain::FenixParser.parse @entry_lambda.call
    expect(Entry.find_by_broker_reference(@file_number).us_exit_port_code).to eq('0444')
  end

  it 'should parse files with almost no information in them' do
    #extra commas added to pass the line length check
    entry_data = lambda {
      data = '"1234567890",12345,"My Company",TAXID,,,,,,,,'
      data
    }

    OpenChain::FenixParser.parse entry_data.call
    entry = Entry.find_by_broker_reference 12345
    expect(entry).not_to be_nil
    expect(entry.entry_number).to eq("1234567890")
    expect(entry.importer_tax_id).to eq("TAXID")
    expect(entry.file_logged_date).to eq(ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now.midnight)

    expect(entry.commercial_invoices.length).to eq(0)
  end

  it 'should read master bills and container numbers for entries without invoice lines' do
    entry_data = lambda {
      data = '"1234567890",12345,"My Company",TAXID,,,,,CONT,,,,,MASTERBILL'
      data
    }

    OpenChain::FenixParser.parse entry_data.call
    entry = Entry.find_by_broker_reference 12345
    expect(entry).not_to be_nil
    expect(entry.master_bills_of_lading).to eq("MASTERBILL")
    expect(entry.container_numbers).to eq("CONT")

    expect(entry.commercial_invoices.length).to eq(0)
  end

  it 'should fall back to using entry number and source system lookup to find imaging shell records' do
    existing_entry = Factory(:entry,:entry_number=>@barcode, :source_system=>OpenChain::FenixParser::SOURCE_CODE)

    #extra commas added to pass the line length check
    entry_data = lambda {
      data = "\"#{@barcode}\",12345,\"My Company\",TAXID,,,,,,,,"
      data
    }

    OpenChain::FenixParser.parse entry_data.call
    existing_entry.reload

    expect(existing_entry.broker_reference).to eq("12345")
    expect(existing_entry.entry_number).to eq(@barcode)
    expect(existing_entry.importer_tax_id).to eq("TAXID")
    expect(existing_entry.file_logged_date).to eq(ActiveSupport::TimeZone["Eastern Time (US & Canada)"].now.midnight)

    expect(existing_entry.commercial_invoices.length).to eq(0)
  end

  it "should skip files with older system export times than current entry" do
    export_date = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(@timestamp[1] + @timestamp[2])

    Factory(:entry,:broker_reference=>@file_number,:source_system=>OpenChain::FenixParser::SOURCE_CODE, :last_exported_from_source=>export_date)
    # Add a second to the time and make sure the entry has a value to match (.ie it was updated)
    @timestamp[2] = (@timestamp[2].to_i + 1).to_s
    OpenChain::FenixParser.parse @entry_lambda.call
    entries = Entry.where(:broker_reference=>@file_number)
    expect(entries.entries.size).to eq(1)
    # Verify the updated last exported date was used
    expect(entries[0].last_exported_from_source).to eq(ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(@timestamp[1] + @timestamp[2]))
  end

  it "should process files with same system export times as current entry" do
    # We want to make sure we do reprocess entries with the same export dates, this allows us to run larger
    # reprocess processes to get older data, but then only reprocess the most up to date file.
    export_date = ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(@timestamp[1] + @timestamp[2])
    entry = Factory(:entry,:broker_reference=>@file_number,:source_system=>OpenChain::FenixParser::SOURCE_CODE, :last_exported_from_source=>export_date)

    OpenChain::FenixParser.parse @entry_lambda.call
    entries = Entry.where(:broker_reference=>@file_number)
    expect(entries.entries.size).to eq(1)

    # All we really need to do is make sure the entry got saved by the parser and not skipped.
    # Verifying any piece of data not set in the factory is present should be enough to prove this.
    expect(entries[0].entry_number).to eq(@barcode)
  end

  it "should process files missing export date only if entry is missing export date" do
    entry = Factory(:entry,:broker_reference=>@file_number,:source_system=>OpenChain::FenixParser::SOURCE_CODE)

    OpenChain::FenixParser.parse @entry_lambda.call
    entries = Entry.where(:broker_reference=>@file_number)
    expect(entries.entries.size).to eq(1)

    # All we really need to do is make sure the entry got saved by the parser and not skipped.
    # Verifying any piece of data not set in the factory is present should be enough to prove this.
    expect(entries[0].entry_number).to eq(@barcode)
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
    expect(entries.entries.size).to eq(2)

    # The ETA date comes from a SD supporting line, so by checking for it it makes sure we're parsing those lines
    # even if the entry number doesn't match
    expect(entries[0].entry_number).to eq(first_entry_number)
    expect(entries[0].eta_date).to eq(@activities['10'][1])

    # Make sure we also created that second entry
    expect(entries[1].entry_number).to eq(@barcode)
  end

  it "should handle date time values with missing time components" do
    @release_date = "01/09/2012,"
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    expect(ent.release_date).to eq(@est.parse_us_base_format(@release_date.gsub(',',' 12:00am')))
  end

  it "should handle date time values with invalid date times" do
    @release_date = "192012,"
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    expect(ent.release_date).to be_nil
  end

  it "should handle 0 for duty rate" do
    @duty_rate = 0
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    expect(ent.commercial_invoice_lines.first.commercial_invoice_tariffs.first.duty_rate).to eq(BigDecimal("0"))
  end

  it "should handle blank duty rate" do
    @duty_rate = ""
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    expect(ent.commercial_invoice_lines.first.commercial_invoice_tariffs.first.duty_rate).to be_nil
  end

  it "should handle specific duty" do
    # Make sure we're not translating specific duty values like we do for adval duties
    @duty_rate = "1.23"
    @hts_qty = "100.50"
    @duty_amount = "123.62"

    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    expect(ent.commercial_invoice_lines.first.commercial_invoice_tariffs.first.duty_rate).to eq(BigDecimal(@duty_rate))
    # Make sure we're not truncating the classification quantity
    expect(ent.commercial_invoice_lines.first.commercial_invoice_tariffs.first.classification_qty_1).to eq(BigDecimal(@hts_qty))
  end

  it "prefers adval rate when rate calculations are within 1 cent of each other" do
    @duty_rate = "7"
    @hts_qty = "3"
    @duty_amount = "21"
    # This value results in the adval calculation being 1 cent off the specific calculation, in which case
    # we still want the advalorem rate prefered
    @entered_value = "300.10"

    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    expect(ent.commercial_invoice_lines.first.commercial_invoice_tariffs.first.duty_rate).to eq(BigDecimal("0.07"))
  end

  it "should retry with_lock 5 times and re-raise error if failed after that" do
    expect(Lock).to receive(:with_lock_retry).with(instance_of(Entry)).and_raise  ActiveRecord::StatementInvalid
    expect {OpenChain::FenixParser.parse @entry_lambda.call}.to raise_error ActiveRecord::StatementInvalid
  end

  it "should not set total packages uom if total packages is blank" do
    @number_of_pieces = ""
    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    expect(ent.total_packages).to be_nil
    expect(ent.total_packages_uom).to be_nil
  end

  it "migrates attachments associated with shell records to this new entry" do
    ent = Entry.create! source_system: 'Fenix', entry_number: nil, broker_reference: @file_number

    shell_entry = Entry.create! source_system: 'Fenix', entry_number: @barcode
    shell_entry.attachments << Attachment.create!(attached_file_name: "file.txt")
    shell_entry.save!

    OpenChain::FenixParser.parse @entry_lambda.call
    ent.reload

    expect(ent.attachments.size).to eq 1
    expect(ent.attachments.first.attached_file_name).to eq "file.txt"

    expect(Entry.where(id: shell_entry.id).first).to be_nil
  end

  it "does not blank out release date or cadex accept date if LVS file has been received" do
    entry = Factory(:entry,:broker_reference=>@file_number,:source_system=>OpenChain::FenixParser::SOURCE_CODE, k84_receive_date: Time.zone.now, cadex_accept_date: Time.zone.now, release_date: Time.zone.now, cadex_sent_date: Time.zone.now)
    @release_date = ','
    @cadex_accept_date = ','
    @cadex_sent_date = ','

    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    expect(ent.cadex_accept_date.to_i).to eq entry.cadex_accept_date.to_i
    expect(ent.cadex_sent_date.to_i).to eq entry.cadex_sent_date.to_i
    expect(ent.release_date.to_i).to eq entry.release_date.to_i
  end

  it "allows updates (but not blanks) to release date / cadex accept if LVS file has been received" do
    entry = Factory(:entry,:broker_reference=>@file_number,:source_system=>OpenChain::FenixParser::SOURCE_CODE, k84_receive_date: Time.zone.now, cadex_accept_date: Time.zone.now, release_date: Time.zone.now, cadex_sent_date: Time.zone.now)

    OpenChain::FenixParser.parse @entry_lambda.call
    ent = Entry.find_by_broker_reference @file_number
    expect(ent.cadex_accept_date.strftime("%m/%d/%Y")).to eq @cadex_accept_date[0, 10]
    expect(ent.cadex_sent_date.strftime("%m/%d/%Y")).to eq @cadex_sent_date[0, 10]
    expect(ent.release_date.strftime("%m/%d/%Y")).to eq @release_date[0, 10]
  end

  it "skips purged entres" do
    EntryPurge.create! source_system: 'Fenix', broker_reference: @file_number, date_purged: (ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse(@timestamp[1] + @timestamp[2]) + 1.day)
    OpenChain::FenixParser.parse @entry_lambda.call
    expect(Entry.find_by_broker_reference @file_number).to be_nil
  end

  it "creates new entries if purged before current source system export date" do
    EntryPurge.create! source_system: 'Fenix', broker_reference: @file_number, date_purged: Time.zone.parse("2015-01-01 00:00")
    OpenChain::FenixParser.parse @entry_lambda.call
    expect(Entry.find_by_broker_reference @file_number).not_to be_nil
  end

  it "uses old timestamp from filename if no timestamp record" do
    OpenChain::FenixParser.parse @entry_lambda.call(true, false, false), {:key=>'b3_detail_rns_114401_2013052958483.1369859062.csv'}
    e = Entry.where(:broker_reference=>@file_number).first
    expect(e.last_exported_from_source).to eq (ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("20130529") + Integer(58483).seconds)
  end

  it "parses new activity record identifiers" do
    @use_new_activities = true

    OpenChain::FenixParser.parse @entry_lambda.call
    e = Entry.find_by_broker_reference @file_number

    tz = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    expect(e.first_do_issued_date).to eq tz.parse(@new_activities['DOGIVEN'][0].to_s).in_time_zone(Time.zone)
    expect(e.docs_received_date).to eq tz.parse(@new_activities['DOCREQ'][0].to_s).to_date
    expect(e.eta_date).to eq Date.new(2015,4,3)
    expect(e.release_date).to eq tz.parse(@new_activities['RNSCUSREL'][1].to_s).in_time_zone(Time.zone)
    expect(e.cadex_sent_date).to eq tz.parse(@new_activities['CADXTRAN'][1].to_s).in_time_zone(Time.zone)
    expect(e.cadex_accept_date).to eq tz.parse(@new_activities['CADXACCP'][1].to_s).in_time_zone(Time.zone)
    expect(e.exam_ordered_date).to eq tz.parse(@new_activities['ACSREFF'][1].to_s).in_time_zone(Time.zone)
    expect(e.k84_receive_date).to eq tz.parse(@new_activities['CADK84REC'][0].to_s).to_date
    expect(e.b3_print_date).to eq tz.parse(@new_activities['B3P'][1].to_s).in_time_zone(Time.zone)
    expect(e.documentation_request_date).to eq tz.parse(@new_activities['KPIDOC'][1].to_s).in_time_zone(Time.zone)
    expect(e.po_request_date).to eq tz.parse(@new_activities['KPIPO'][1].to_s).in_time_zone(Time.zone)
    expect(e.tariff_request_date).to eq tz.parse(@new_activities['KPIHTS'][1].to_s).in_time_zone(Time.zone)
    expect(e.ogd_request_date).to eq tz.parse(@new_activities['KPIOGD'][1].to_s).in_time_zone(Time.zone)
    expect(e.value_currency_request_date).to eq tz.parse(@new_activities['KPIVAL'][1].to_s).in_time_zone(Time.zone)
    expect(e.part_number_request_date).to eq tz.parse(@new_activities['KPIPART'][1].to_s).in_time_zone(Time.zone)
    expect(e.importer_request_date).to eq tz.parse(@new_activities['KPIIOR'][1].to_s).in_time_zone(Time.zone)
    expect(e.manifest_info_received_date).to eq tz.parse(@new_activities['MANINFREC'][1].to_s).in_time_zone(Time.zone)
    expect(e.split_shipment_date).to eq tz.parse(@new_activities['SPLITSHPT'][1].to_s).in_time_zone(Time.zone)
    expect(e.split_shipment).to eq true
    expect(e.across_declaration_accepted).to eq tz.parse(@new_activities['ACSDECACCP'][1].to_s).in_time_zone(Time.zone)
  end

  it 'requests LVS child data if entry type is F' do
    c = double("OpenChain::FenixSqlProxyClient")
    expect_any_instance_of(OpenChain::FenixSqlProxyClient).to receive(:delay).and_return c
    expect(c).to receive(:request_lvs_child_transactions).with(@barcode)

    @entry_type = "F"
    OpenChain::FenixParser.parse @entry_lambda.call
  end

  it "uses cadex accept as release date for F type entries" do
    @entry_type = "F"

    OpenChain::FenixParser.parse @entry_lambda.call
    entry = Entry.where(broker_reference: @file_number).first
    expect(entry.release_date).to eq entry.cadex_accept_date
  end

  it "sets exchnage rate to 1 if missing and currency is CAD" do
    @currency = 'CAD'
    @exchange_rate = ""
    OpenChain::FenixParser.parse @entry_lambda.call
    e = Entry.find_by_broker_reference @file_number

    expect(e.commercial_invoices.first.exchange_rate).to eq BigDecimal(1)
  end

  it "raises an error if non-CAD currency exchange rate is missing" do
    @exchange_rate = ""
    expect {OpenChain::FenixParser.parse @entry_lambda.call}.to raise_error "File # / Invoice # #{@file_number} / #{@invoice_number} was missing an exchange rate.  Exchange rate must be present for commercial invoices where the currency is not CAD."
  end

  it "doesn't fail if invoice line is missing duty amount" do
    # Sometimes an entry is pre-keyed and sits around and gets sent across to VFI Track missing some duty information
    # Just make sure this doesn't fail.
    @duty_amount = ""
    OpenChain::FenixParser.parse @entry_lambda.call
    e = Entry.find_by_broker_reference @file_number

    expect(e.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.first.duty_amount).to be_nil
  end

  it "assigns fiscal month to entry" do
    imp = Factory(:company, fenix_customer_number: "833764202RM0001", fiscal_reference: "ent_release_date")
    fm = Factory(:fiscal_month, company: imp, year: 2015, month_number: 1, start_date: Date.new(2015,9,1), end_date: Date.new(2015,9,30))
    OpenChain::FenixParser.parse @entry_lambda.call
    e = Entry.find_by_broker_reference @file_number
    expect(e.fiscal_date).to eq fm.start_date
    expect(e.fiscal_month).to eq 1
    expect(e.fiscal_year).to eq 2015
  end    

  context "with fenix admin group" do
    let (:group) {Group.create! system_code: "fenix_admin", name: "Fenix Admin"}
    let (:user) {u = Factory(:user); group.users << u; group.save!; u}

    it "raises an error if Fenix ND entry attempts to update an old entry" do
      user
      entry = Factory(:entry,:entry_number=>@barcode, broker_reference: "REFERENCE", :source_system=>OpenChain::FenixParser::SOURCE_CODE, release_date: ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("2015-09-17 23:59"))
      OpenChain::FenixParser.parse @entry_lambda.call(true, false, true)
      # verify the entry wasn't updated
      entry.reload
      expect(entry.broker_reference).to eq "REFERENCE"
      m = ActionMailer::Base.deliveries.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "Transaction # #{@barcode} cannot be reused in Fenix ND"
      expect(m.body).to include "Transaction # #{entry.entry_number} / File # #{@file_number} has been used previously in old Fenix as File # #{entry.broker_reference}. Please correct this Fenix ND file and resend to VFI Track."
    end
  end

  it "doesn't raise an error if Fenix ND entry attempts to update an entry released after 9/18" do
    Factory(:entry,:broker_reference=>@file_number,:source_system=>OpenChain::FenixParser::SOURCE_CODE, release_date: ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("2015-09-18 00:01"))
    expect{OpenChain::FenixParser.parse @entry_lambda.call(true, false, true)}.not_to raise_error
  end

  it "parses old style assists" do
    OpenChain::FenixParser.parse @entry_lambda.call(true, false, false)
    e = Entry.find_by_broker_reference @file_number
    line = e.commercial_invoices.first.commercial_invoice_lines.first
    expect(line.adjustments_amount).to eq (@adjusted_vcc - @line_value + @adjustments_per_piece)
  end

  context 'importer company' do
    it "should create importer" do
      OpenChain::FenixParser.parse @entry_lambda.call
      ent = Entry.find_by_broker_reference @file_number
      imp = ent.importer
      expect(imp.name).to eq(@importer_name)
      expect(imp.fenix_customer_number).to eq(@importer_tax_id)
      expect(imp).to be_importer
    end
    it "should link to existing importer" do
      # Make sure we're not updating importer names that aren't tax ids
      imp = Factory(:company,:fenix_customer_number=>@importer_tax_id,:importer=>true, :name=>"Test")
      OpenChain::FenixParser.parse @entry_lambda.call
      ent = Entry.find_by_broker_reference @file_number
      expect(ent.importer).to eq(imp)
      expect(imp.name).to eq("Test")
    end
    it "should update an existing importer's name if the name is the tax id" do
      imp = Factory(:company,:fenix_customer_number=>@importer_tax_id,:importer=>true, :name=>@importer_tax_id)
      OpenChain::FenixParser.parse @entry_lambda.call
      ent = Entry.find_by_broker_reference @file_number
      expect(ent.importer.id).to eq(imp.id)
      expect(ent.importer.name).to eq(@importer_name)
    end
    it "should change the entry's importer id on an update if the importer changed" do
      imp = Factory(:company, fenix_customer_number: "ABC", importer: true)
      updated_imp = Factory(:company, fenix_customer_number: @importer_tax_id,importer: true)
      ent = Factory(:entry, broker_reference: @file_number, source_system: "Fenix", importer: imp)

      OpenChain::FenixParser.parse @entry_lambda.call
      ent = Entry.find_by_broker_reference @file_number
      expect(ent.importer.id).to eq(updated_imp.id)
    end
  end
  context 'multi line' do
    before :each do
      @invoices = [
        {:seq=>1,:inv_num => '12345', :b3_line_number => 25},
        {:seq=>2,:inv_num => '5555555', :b3_line_number => 26}
      ]
      @multi_line_lambda = lambda {
        data = ""
        @invoices.each_with_index do |inv, i|
          @invoice_number = inv[:inv_num]
          @b3_line_number = inv[:b3_line_number]
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
      expect(Entry.find_by_broker_reference(@file_number).entered_value).to eq(3)
    end
    it 'should total GST' do
      @invoices[0][:duty] = 2
      @invoices[0][:gst_amount] = 4
      @invoices[1][:duty] = 6
      @invoices[1][:gst_amount] = 5
      OpenChain::FenixParser.parse @multi_line_lambda.call
      ent = Entry.find_by_broker_reference(@file_number)
      expect(ent.total_gst).to eq(9)
      expect(ent.total_duty_gst).to eq(17)
    end
    it 'should save an entry with multiple invoices' do
      OpenChain::FenixParser.parse @multi_line_lambda.call
      entries = Entry.where(:broker_reference=>@file_number)
      expect(entries.entries.size).to eq(1)
      expect(entries.first.commercial_invoices.size).to eq(2)
      expect(entries.first.commercial_invoices.first.commercial_invoice_lines.first.customs_line_number).to eq 25
      expect(entries.first.commercial_invoices.second.commercial_invoice_lines.first.customs_line_number).to eq 26
      expect(entries.first.summary_line_count).to eq 26
    end
    it 'should save multiple invoice lines for the same invoice' do
      @invoices[1][:seq]=1 #make both invoices part of same sequence
      OpenChain::FenixParser.parse @multi_line_lambda.call
      entries = Entry.where(:broker_reference=>@file_number)
      expect(entries.entries.size).to eq(1)
      expect(entries.first.commercial_invoices.size).to eq(1)
      expect(entries.first.commercial_invoices.first.commercial_invoice_lines.size).to eq(2)
      expect(entries.first.commercial_invoices.first.commercial_invoice_lines.first.line_number).to eq(1)
      expect(entries.first.commercial_invoices.first.commercial_invoice_lines.last.line_number).to eq(2)
      expect(entries.first.commercial_invoices.first.commercial_invoice_lines.first.customs_line_number).to eq 25
      expect(entries.first.commercial_invoices.first.commercial_invoice_lines.second.customs_line_number).to eq 26
      expect(entries.first.summary_line_count).to eq 26
    end
    it 'should overwrite header PO if populated in description 2 field' do
      @invoices[0][:detail_po] = 'a'
      @invoices[1][:detail_po] = 'b'
      OpenChain::FenixParser.parse @multi_line_lambda.call
      ent = Entry.find_by_broker_reference @file_number
      expect(ent.commercial_invoices.first.commercial_invoice_lines.first.po_number).to eq('a')
      expect(ent.commercial_invoices.last.commercial_invoice_lines.first.po_number).to eq('b')
      expect(ent.po_numbers).to eq("a\n b")
    end
    context 'accumulate fields' do
      it 'invoice value - different invoices' do
        ['19.10','20.03'].each_with_index {|b,i| @invoices[i][:line_val]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        ent = Entry.find_by_broker_reference(@file_number)
        expect(ent.total_invoiced_value).to eq(BigDecimal('39.13'))
        invoice_vals = ent.commercial_invoices.collect {|i| i.invoice_value}
        expect(invoice_vals).to eq([BigDecimal('19.29'),BigDecimal('20.23')])
      end
      it 'invoice value - same invoices' do
        ['19.10','20.03'].each_with_index {|b,i|
          @invoices[i][:line_val]=b
          @invoices[i][:seq]=1
        }
        OpenChain::FenixParser.parse @multi_line_lambda.call
        ent = Entry.find_by_broker_reference(@file_number)
        expect(ent.total_invoiced_value).to eq(BigDecimal('39.13'))
        expect(ent.commercial_invoices.size).to eq(1)
        expect(ent.commercial_invoices.first.invoice_value).to eq(BigDecimal('39.52'))
      end
      it 'duty amount' do
        ['9.10','10.10'].each_with_index {|b,i| @invoices[i][:duty]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        expect(Entry.find_by_broker_reference(@file_number).total_duty).to eq(BigDecimal('19.20'))
      end
      it 'units' do
        ['50.12','18.15'].each_with_index {|b,i| @invoices[i][:cq]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        expect(Entry.find_by_broker_reference(@file_number).total_units).to eq(BigDecimal('68.27'))
      end
      it 'bills of lading' do
        # Disable the additional BL lines
        @additional_bols = []
        ['x','y'].each_with_index {|b,i| @invoices[i][:bol]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        expect(Entry.find_by_broker_reference(@file_number).master_bills_of_lading).to eq("x\n y")
      end
      it 'vendor names' do
        ['x','y'].each_with_index {|b,i| @invoices[i][:vend]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        expect(Entry.find_by_broker_reference(@file_number).vendor_names).to eq("x\n y")
      end
      it 'origin country codes' do
        ['CN','UIN'].each_with_index {|b,i| @invoices[i][:org]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        expect(Entry.find_by_broker_reference(@file_number).origin_country_codes).to eq("CN\n US")
      end
      it 'export country codes' do
        ['PR','UNJ'].each_with_index {|b,i| @invoices[i][:exp]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        expect(Entry.find_by_broker_reference(@file_number).export_country_codes).to eq("PR\n US")
      end
      it 'origin state codes' do
        ['CN','UIN'].each_with_index {|b,i| @invoices[i][:org]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        expect(Entry.find_by_broker_reference(@file_number).origin_state_codes).to eq("IN")
      end
      it 'export state codes' do
        ['UNV','UIN'].each_with_index {|b,i| @invoices[i][:exp]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        expect(Entry.find_by_broker_reference(@file_number).export_state_codes).to eq("NV\n IN")
      end
      it 'container numbers' do
        ['x','y'].each_with_index {|b,i| @invoices[i][:cont]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        containers = Entry.find_by_broker_reference(@file_number).container_numbers.split("\n ")
        # Make sure we're accounting for the container numbers pulled from the CON records
        expect(containers.include?('x')).to be_truthy
        expect(containers.include?('y')).to be_truthy
        @additional_container_numbers.each do |c|
          expect(containers.include?(c)).to be_truthy
        end
      end
      it "part numbers" do
        ['x','y'].each_with_index {|b,i| @invoices[i][:part_number]=b}
        OpenChain::FenixParser.parse @multi_line_lambda.call
        expect(Entry.find_by_broker_reference(@file_number).part_numbers).to eq("x\n y")
      end
      it "invoice numbers" do
        OpenChain::FenixParser.parse @multi_line_lambda.call
        expect(Entry.find_by_broker_reference(@file_number).commercial_invoice_numbers.split("\n ")).to eq([@invoices[0][:inv_num], @invoices[1][:inv_num]])
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
          expect(bols.include?(bol)).to be_truthy
        end

        expect(bols.include?("123456789012345")).to be_falsey
      end

      it 'skips entry numbers that are all zeros' do
        @barcode = '00000000000000'
        OpenChain::FenixParser.parse @multi_line_lambda.call

        expect(Entry.find_by_broker_reference(@file_number)).to be_nil
      end
    end

    context "with entry forwarding" do
      let (:forwarding_config) {
        {@importer_number => ["path/to/folder"]}
      }

      it "ftps file contents if configured to do so" do
        file_contents = nil
        ftp_options = nil
        expect_any_instance_of(OpenChain::FenixParser).to receive(:ftp_file) do |instance, file, options|
          expect(file.binmode?).to be_truthy
          file_contents = file.read
          ftp_options = options
        end
        expect_any_instance_of(OpenChain::FenixParser).to receive(:forwarding_config).and_return forwarding_config
        input = @entry_lambda.call
        OpenChain::FenixParser.parse input, key: "path/to/file.csv"

        expect(file_contents).not_to be_nil
        rows = CSV.parse file_contents
        # Just make sure the same number of rows are in the output as the input.
        expect(rows.length).to eq (input.split("\n").length)
        expect(rows.first).to eq @timestamp
        expect(ftp_options).to eq( folder: "path/to/folder", keep_local: true )
      end
    end
  end

  describe "ftp_credentials" do
    it "uses the correct ftp credentials" do
      # Just make sure it's using the ecs account one and the folder is blank
      creds = subject.ftp_credentials
      expect(creds[:username]).to eq "ecs"
      expect(creds[:folder]).to be_blank
    end
  end

  describe 'process_past_days' do
    it "should delay processing" do
      expect(OpenChain::FenixParser).to receive(:delay).exactly(3).times.and_return(OpenChain::FenixParser)
      expect(OpenChain::FenixParser).to receive(:process_day).exactly(3).times
      OpenChain::FenixParser.process_past_days 3
    end
  end
  describe 'process_day' do
    it 'should process all files from the given day' do
      d = Date.new
      expect(OpenChain::S3).to receive(:integration_keys).with(d,["www-vfitrack-net/_fenix", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_fenix"]).and_yield("a").and_yield("b")
      expect(OpenChain::S3).to receive(:get_data).with(OpenChain::S3.integration_bucket_name,"a").and_return("x")
      expect(OpenChain::S3).to receive(:get_data).with(OpenChain::S3.integration_bucket_name,"b").and_return("y")
      expect(OpenChain::FenixParser).to receive(:parse).with("x",{:bucket=>OpenChain::S3.integration_bucket_name,:key=>"a",:imaging=>false,:log=>instance_of(InboundFile)})
      expect(OpenChain::FenixParser).to receive(:parse).with("y",{:bucket=>OpenChain::S3.integration_bucket_name,:key=>"b",:imaging=>false,:log=>instance_of(InboundFile)})
      OpenChain::FenixParser.process_day d
    end
  end

  context "lvs_entries" do

    before :each do
      @parent_entry = "1234567"
      @child_entries = ["987654", "159753"]

      @dates = {
        @child_entries[0] => {
          '868' => '20131001',
          '1270' => '20131002',
          '1274' => '20131003',
          '1280' => '20131004'
        },
        @child_entries[1] => {
          '868' => '20131005',
          '1270' => '20131006',
          '1274' => '20131007',
          '1280' => '20131008'
        },
      }
      @time_zone = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    end

    def build_lvs_file
      file = ""
      @child_entries.each do |child_entry|
        @dates[child_entry].each do |activities|
          file += "LVS,#{@parent_entry},#{child_entry},#{activities[0]},#{activities[1]}\r\n"
        end
      end
      file
    end

    it "should process an lvs entry" do
      OpenChain::FenixParser.parse build_lvs_file

      entry = Entry.where(:entry_number => @child_entries[0], :source_system=>"Fenix").first
      expect(entry).not_to be_nil
      expect(entry.import_country.iso_code).to eq "CA"
      expect(entry.release_date).to eq @time_zone.parse '20131001'
      expect(entry.cadex_sent_date).to eq @time_zone.parse '20131002'
      expect(entry.cadex_accept_date).to eq @time_zone.parse '20131003'
      expect(entry.k84_receive_date).to eq Date.parse '20131004'

      entry = Entry.where(:entry_number => @child_entries[1], :source_system=>"Fenix").first
      expect(entry).not_to be_nil
      expect(entry.import_country.iso_code).to eq "CA"
      expect(entry.release_date).to eq @time_zone.parse '20131005'
      expect(entry.cadex_sent_date).to eq @time_zone.parse '20131006'
      expect(entry.cadex_accept_date).to eq @time_zone.parse '20131007'
      expect(entry.k84_receive_date).to eq Date.parse '20131008'
    end

    it "should update lvs entries" do
      # We shouldn't be updating the country - on setting it on create
      e = Factory(:entry, :entry_number => @child_entries[0], :source_system=>"Fenix")

      OpenChain::FenixParser.parse build_lvs_file

      entry = Entry.where(:entry_number => @child_entries[0], :source_system=>"Fenix").first
      expect(entry).not_to be_nil
      expect(entry.id).to eq e.id
      expect(entry.import_country).to be_nil

      expect(entry.release_date).to eq @time_zone.parse '20131001'
      expect(entry.cadex_sent_date).to eq @time_zone.parse '20131002'
      expect(entry.cadex_accept_date).to eq @time_zone.parse '20131003'
      expect(entry.k84_receive_date).to eq Date.parse '20131004'
    end
  end

  describe "parse_lvs_query_results" do
    before :each do
      @child1 = Factory(:entry, source_system: "Fenix", entry_number: "12345")
      @summary = Factory(:entry, source_system: "Fenix", entry_number: "SUMMARY", release_date: "2015-01-01 10:00", cadex_sent_date: "2015-01-01 08:00", cadex_accept_date: "2015-01-01 09:00", k84_receive_date: "2015-01-01 12:00")
    end

    it "reads a result set and updates or creates child entries with summary entry dates" do
      rs = [{"summary" => "SUMMARY", "child" => "12345"}, {"summary" => "SUMMARY", "child" => "56789"}]

      described_class.parse_lvs_query_results rs

      @child1.reload

      expect(@child1.release_date).to eq @summary.release_date
      expect(@child1.cadex_sent_date).to eq @summary.cadex_sent_date
      expect(@child1.cadex_accept_date).to eq @summary.cadex_accept_date
      expect(@child1.k84_receive_date).to eq @summary.k84_receive_date

      # Entry Type / Country are only set when created
      expect(@child1.entry_type).to be_nil
      expect(@child1.import_country).to be_nil

      # Second entry does not exist, it should have been created
      child2 = Entry.where(source_system: "Fenix", entry_number: "56789").first
      expect(child2).not_to be_nil
      expect(child2.import_country.try(:iso_code)).to eq "CA"
      expect(child2.entry_type).to eq "LV"

      expect(child2.release_date).to eq @summary.release_date
      expect(child2.cadex_sent_date).to eq @summary.cadex_sent_date
      expect(child2.cadex_accept_date).to eq @summary.cadex_accept_date
      expect(child2.k84_receive_date).to eq @summary.k84_receive_date
    end

    it "skips if the summary entry isn't found" do
      rs = [{"summary" => "NONEXIST", "child" => "12345"}, {"summary" => "NONEXIST", "child" => "56789"}]
      described_class.parse_lvs_query_results rs
      @child1.reload
      expect(@child1.release_date).to be_nil
      expect(Entry.where(source_system: "Fenix", entry_number: "56789").first).to be_nil
    end

    it "handles json instead of a results hash" do
      rs = [{"summary" => "SUMMARY", "child" => "12345"}].to_json

      described_class.parse_lvs_query_results rs

      @child1.reload

      expect(@child1.release_date).to eq @summary.release_date
      expect(@child1.cadex_sent_date).to eq @summary.cadex_sent_date
      expect(@child1.cadex_accept_date).to eq @summary.cadex_accept_date
      expect(@child1.k84_receive_date).to eq @summary.k84_receive_date
    end

    it "caches entry look ups" do
      relation = double("relation")
      expect(Entry).to receive(:where).with(entry_number: "SUMMARY", source_system:"Fenix").and_return relation
      expect(relation).to receive(:first).and_return @summary

      expect_any_instance_of(described_class).to receive(:update_lvs_dates).exactly(2).times

      rs = [{"summary" => "SUMMARY", "child" => "12345"}, {"summary" => "SUMMARY", "child" => "56789"}]
      described_class.parse_lvs_query_results rs
    end
  end

  describe OpenChain::FenixParser::HoldReleaseSetter do
    let(:date) { ActiveSupport::TimeZone["Eastern Time (US & Canada)"].local(2017,1,12)}
    let(:e) { Factory(:entry) }
    let(:setter) { described_class.new e}

    describe "set_hold_date" do
      it "assigns hold_date to the exam_ordered_date" do
        e.update_attributes! exam_ordered_date: date, hold_date: nil
        expect{setter.set_hold_date}.to change(e, :hold_date).from(nil).to(date)
      end
    end

    describe "set_hold_release_date" do
      it "assigns both hold_release_date and exam_release_date to release_date" do
        e.update_attributes! release_date: date, hold_release_date: nil, exam_release_date: nil
        setter.set_hold_release_date
        expect(e.exam_release_date).to eq date
        expect(e.hold_release_date).to eq date
      end
    end

    describe "set_on_hold" do
      it "assigns 'true' to on_hold if hold_date is populated but hold_release_date is not" do
        e.update_attributes! hold_date: date, on_hold: nil, hold_release_date: nil
        expect{setter.set_on_hold}.to change(e, :on_hold).from(nil).to true 
      end
    end
  end
end
