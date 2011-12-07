require 'spec_helper'

describe OpenChain::AllianceParser do
  before :each do
    @ref_num ='00364690' 
    @entry_number = '316000364690'
    @cust_num = "NJEAN"
    @extract_date_str = "201002190115"
    @company_number = '01'
    @division = '9988'
    @customer_name = 'cust name'
    @entry_type = '02'
    @carrier_code = 'SCAC'
    @arrival_date_str = "201002201444"
    @entry_filed_date_str = "201002142326"
    @release_date_str = '201104231921'
    @first_release_date_str = '201103301521'
    @free_date_str = '201004221201'
    @last_billed_date_str = '201005121822'
    @invoice_paid_date_str = '201101031442'
    @liquidation_date_str = '201104021522'
    @duty_due_date_str = '20110601'
    @total_packages = 88
    @total_fees = BigDecimal("999.88",2)
    @total_duty = BigDecimal("55.27",2)
    @total_duty_direct = BigDecimal("44.52",2)
    @entered_value = BigDecimal("6622.48",2)
    @customer_references = "ref1\nref2\nref3"
    @export_date_str = '201104261121'
    @merchandise_description = 'merch desc'
    @total_packages_uom = 'CTN'
    @entry_port_code = '1235'
    @transport_mode_code = '11'
    @ult_consignee_code = 'abcdef' 
    @ult_consignee_name = 'u consign nm'
    @gross_weight = 50
    @hmf = BigDecimal('55.22',2)
    @mpf = BigDecimal('271.14',2)
    @cotton_fee = BigDecimal('123.31',2)
    convert_cur = lambda {|c,width| (c * 100).to_i.to_s.rjust(width,'0')}
    @make_entry_lambda = lambda {
      sh00 = "SH0000#{@ref_num}#{@cust_num.ljust(10)}#{@extract_date_str}#{@company_number}#{@division}#{@customer_name.ljust(35)}#{@merchandise_description.ljust(70)}IDID000004701#{@entry_port_code.rjust(4,'0')}#{@transport_mode_code}#{@entry_type}#{@entry_number}#{@ult_consignee_code.ljust(10)}#{@ult_consignee_name.ljust(35)}#{@carrier_code.ljust(4)}00F792ETIHAD AIRWAYS                     ETIHAD AIRWAYS      101       #{@total_packages.to_s.rjust(12,'0')}#{@total_packages_uom.ljust(6)}#{@gross_weight.to_s.rjust(12,'0')}0000000014400WEDG047091068823N   N01No Change                          00change liquidation                 00                                   0LQ090419ESP       N05 YYYYVFEDI     "
      sh01 = "SH01#{"".ljust(45)}#{convert_cur.call(@total_duty,12)}#{"".ljust(24)}#{convert_cur.call(@total_fees,12)}#{"".ljust(260)}#{convert_cur.call(@total_duty_direct,12)}#{"".ljust(15)}#{convert_cur.call(@entered_value,13)}"
      sd_arrival = "SD0000012#{@arrival_date_str}200904061628Arr POE Arrival Date Port of Entry                                  "
      sd_entry_filed = "SD0000016#{@entry_filed_date_str}2009040616333461FILDEntry Filed (3461,3311,7523)                                "
      sd_release = "SD0000019#{@release_date_str}200904061633Release Release Date                                                "
      sd_first_release = "SD0099202#{@first_release_date_str}200904061633Ist Rel First Release date                                          "
      sd_free = "SD0000052#{@free_date_str}200904081441Free    Free Date                                                   "
      sd_last_billed = "SD0000028#{@last_billed_date_str}200904061647Bill PrtLast Billed                                                 "
      sd_invoice_paid = "SD0000032#{@invoice_paid_date_str}200905111220InvPaid Invoice Paid by Customer                                    "
      sd_liquidation = "SD0000044#{@liquidation_date_str}201002190115Liq DateLiquidation Date                                            "
      sd_duty_due = "SD0000042#{@duty_due_date_str}1606201111171606Pay Due Payment Due Date                                            "
      sd_export = "SD0000001#{@export_date_str}201111171606Pay Due Payment Due Date                                            "
      su_hmf = "SU01#{"".ljust(35)}501#{convert_cur.call(@hmf,11)}"
      su_mpf = "SU01#{"".ljust(35)}499#{convert_cur.call(@mpf,11)}"
      su_cotton = "SU01#{"".ljust(35)}056#{convert_cur.call(@cotton_fee,11)}"
      r = [sh00,sh01,sd_duty_due,sd_export,sd_arrival,sd_entry_filed,sd_release,sd_first_release,sd_free,sd_last_billed,sd_invoice_paid,sd_liquidation,su_hmf,su_mpf,su_cotton]
      unless @customer_references.blank?
        @customer_references.split("\n").each do |cr|
          r << "SR00#{cr.ljust(35)}"
        end
      end
      r.join("\n")
    }
    @inv_suffix = "01"
    @inv_invoice_date_str = "20090406"
    @inv_total = BigDecimal("12.34",2)
    @inv_b_name = 'billname'
    @inv_b_add_1 = 'b address 1'
    @inv_b_add_2 = 'b address 2'
    @inv_b_city = 'bc city'
    @inv_b_state = 'NJ'
    @inv_b_zip = '12345'
    @inv_b_country_iso = 'US'
    @country = Factory(:country,:iso_code=>'US')
    @invoice_lines = [
      {:code=>'0099',:desc=>'CHARGDESC',:amt=>BigDecimal.new("10.01",2),:v_name=>'VNAME',:v_ref=>"VREF",:type=>"D"},
      {:code=>'0021',:desc=>'CHARGDESC2',:amt=>BigDecimal.new("2.33",2),:v_name=>'VN2',:v_ref=>"VREF2",:type=>"R"},
    ]
    @make_invoice_lambda = lambda {
      ih00 = "IH00#{@inv_suffix}#{@inv_invoice_date_str}#{@cust_num.ljust(10)}#{(@inv_total*100).to_i.to_s.rjust(11,'0')}000000000000000000000000000000000000000000000000#{@inv_b_name.ljust(35)}#{@inv_b_add_1.ljust(35)}#{@inv_b_add_2.ljust(35)}#{@inv_b_city.ljust(35)}#{@inv_b_state}#{@inv_b_zip.ljust(9)}#{@inv_b_country_iso}"
      i_trailer = "IT00                                                                      000000018080000000000000000000000000"
      rows = [ih00]
      @invoice_lines.each {|h| rows << "IL00#{h[:code]}#{h[:desc].ljust(35)}#{(h[:amt]*100).to_i.to_s.rjust(11,'0')}#{h[:v_name].ljust(30)}#{h[:v_ref].ljust(15)}#{h[:type]}"}
      rows << i_trailer
      rows.join("\n")
    }
    @si_lines = [
      {:mbol=>'MAEU12345678',:it=>'123456789',:hbol=>'H325468',:sub=>'S19148kf'},
      {:mbol=>'OOCL81851511',:it=>'V58242151',:hbol=>'H35156181',:sub=>'S5555555'}
    ]
    @make_si_lambda = lambda {
      rows = []
      @si_lines.each {|h| rows << "SI00#{h[:it].ljust(12)}#{h[:mbol].ljust(16)}#{h[:hbol].ljust(12)}#{h[:sub].ljust(12)}"}
      rows.join("\n")
    }
    #array of hashes for each invoice
    @commercial_invoices = [
      {:mfid=>'12345',:invoiced_value=>BigDecimal("41911.23",2),:lines=>[
        {:export_country_code=>'CN',:origin_country_code=>'NZ',:vendor_name=>'vend 01',:units=>BigDecimal("144.214",3),:units_uom=>'PCS',:spi_1=>"AX",:spi_2=>"A",
          :po_number=>'abcdefg'},
        {:export_country_code=>'CN',:origin_country_code=>'NZ',:vendor_name=>'vend 01',:units=>BigDecimal("8",3),:units_uom=>'EA',:po_number=>'1921301'}
      ]},
      {:mfid=>'12345',:invoiced_value=>BigDecimal("41911.23",2),:lines=>[{:export_country_code=>'CN',:origin_country_code=>'NZ',:vendor_name=>'vend 01',:units=>BigDecimal("29.111",3),:units_uom=>'EA',:spi_1=>"X"}]},
      {:mfid=>'MFIfdlajf1',:invoiced_value=>BigDecimal("611.23",2),:lines=>[{:export_country_code=>'TW',:origin_country_code=>'AU',:vendor_name=>'v2',:units=>BigDecimal("2.116",3),:units_uom=>'DOZ',:po_number=>'jfdaila'}]}
    ] 
    @make_commercial_invoices_lambda = lambda {
      rows = []
      @commercial_invoices.each do |ci|
        rows << "CI00#{"".ljust(46)}#{convert_cur.call(ci[:invoiced_value],13)}#{"".ljust(33)}#{ci[:mfid].ljust(15)}"
        ci[:lines].each do |line|
          rows << "CL00#{"".ljust(30)}#{(line[:units]*1000).to_i.to_s.rjust(12,"0")}#{line[:units_uom].ljust(6)}#{"".ljust(15)}#{line[:origin_country_code]}#{"".ljust(11)}#{line[:export_country_code]} #{line[:vendor_name].ljust(35)}#{"".ljust(62)}#{line[:po_number] ? line[:po_number].ljust(35) : "".ljust(35)}"
          rows << "CT00#{"".ljust(25)}#{line[:spi_1] ? line[:spi_1].ljust(2) : "  "}#{line[:spi_2] ? line[:spi_2] : " "}"
        end
      end
      rows.join("\n")
    }
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end
  it 'should create entry' do
    file_content = "#{@make_entry_lambda.call}\n#{@make_commercial_invoices_lambda.call}"
    OpenChain::AllianceParser.parse file_content
    ent = Entry.find_by_broker_reference @ref_num
    ent.entry_number.should == @entry_number
    ent.customer_number.should == @cust_num
    ent.last_exported_from_source.should == @est.parse(@extract_date_str)
    ent.company_number.should == @company_number
    ent.division_number.should == @division
    ent.customer_name.should == @customer_name
    ent.entry_type.should == @entry_type
    ent.arrival_date.should == @est.parse(@arrival_date_str)
    ent.entry_filed_date.should == @est.parse(@entry_filed_date_str)
    ent.release_date.should == @est.parse(@release_date_str)
    ent.first_release_date.should == @est.parse(@first_release_date_str)
    ent.free_date.should == @est.parse(@free_date_str)
    ent.last_billed_date.should == @est.parse(@last_billed_date_str)
    ent.invoice_paid_date.should == @est.parse(@invoice_paid_date_str)
    ent.liquidation_date.should == @est.parse(@liquidation_date_str)
    ent.duty_due_date.strftime("%Y%m%d").should == @duty_due_date_str
    ent.export_date.strftime("%Y%m%d").should == @export_date_str[0,8]
    ent.carrier_code.should == @carrier_code
    ent.total_packages.should == @total_packages
    ent.total_packages_uom.should == @total_packages_uom
    ent.total_fees.should == @total_fees
    ent.total_duty.should == @total_duty
    ent.total_duty_direct.should == @total_duty_direct
    ent.entered_value.should == @entered_value
    ent.customer_references.should == @customer_references #make sure cust refs in sample data don't overlap with line level PO number or they'll be excluded on purpose
    ent.merchandise_description.should == @merchandise_description
    ent.transport_mode_code.should == @transport_mode_code
    ent.entry_port_code.should == @entry_port_code
    ent.ult_consignee_code.should == @ult_consignee_code
    ent.ult_consignee_name.should == @ult_consignee_name
    ent.gross_weight.should == @gross_weight
    ent.cotton_fee.should == @cotton_fee
    ent.hmf.should == @hmf
    ent.mpf.should == @mpf
    ent.mfids.split("\n").should == Set.new(@commercial_invoices.collect {|ci| ci[:mfid]}).to_a

    expected_invoiced_value = BigDecimal("0",2)
    expected_export_country_codes = Set.new
    expected_origin_country_codes = Set.new
    expected_vendor_names = Set.new
    expected_total_units_uoms = Set.new
    expected_spis = Set.new
    expected_pos = Set.new 
    expected_total_units = BigDecimal("0",2)
    
    @commercial_invoices.each do |ci| 
      expected_invoiced_value += ci[:invoiced_value]
      ci[:lines].each do |line|
        expected_export_country_codes << line[:export_country_code]
        expected_origin_country_codes << line[:origin_country_code]
        expected_vendor_names << line[:vendor_name]
        expected_total_units_uoms << line[:units_uom]
        expected_total_units += line[:units]
        expected_pos << line[:po_number] if line[:po_number]
        [:spi_1,:spi_2].each {|s| expected_spis << line[s] if line[s]}
      end
    end

    ent.total_invoiced_value.should == expected_invoiced_value
    ent.export_country_codes.split("\n").should == expected_export_country_codes.to_a
    ent.origin_country_codes.split("\n").should == expected_origin_country_codes.to_a
    ent.vendor_names.split("\n").should == expected_vendor_names.to_a
    ent.total_units.should == expected_total_units
    ent.total_units_uoms.split("\n").should == expected_total_units_uoms.to_a
    ent.po_numbers.split("\n").should == expected_pos.to_a
    ent.special_program_indicators.split("\n").should == expected_spis.to_a

    ent.time_to_process.should < 1000 
    ent.time_to_process.should > 0
  end
  context 'reference fields' do
    it 'should remove po numbers from cust ref' do
      @customer_references = "a\nb\nc"
      @commercial_invoices.first[:lines].first[:po_number] = "b"
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_commercial_invoices_lambda.call}"
      Entry.find_by_broker_reference(@ref_num).customer_references.should == "a\nc"
    end
    it 'should work with no customer references' do
      @customer_references = nil
      expected_pos = Set.new 
      @commercial_invoices.each do |ci| 
        ci[:lines].each do |line|
          expected_pos << line[:po_number] if line[:po_number]
        end
      end
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_commercial_invoices_lambda.call}"
      Entry.find_by_broker_reference(@ref_num).po_numbers.split("\n").should == expected_pos.to_a
    end
    it 'should work with no po numbers' do
      @customer_references = "a\nb\nc"
      @commercial_invoices.each do |ci| 
        ci[:lines].each do |line|
          line[:po_number] = nil 
        end
      end
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_commercial_invoices_lambda.call}"
      ent = Entry.find_by_broker_reference(@ref_num)
      ent.customer_references.should == "a\nb\nc"
      ent.po_numbers.should be_blank
    end
  end
  it 'should handle empty date' do
    @arrival_date_str = '            '
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    ent = Entry.find_by_broker_reference @ref_num
    ent.arrival_date.should be_nil
  end
  it 'should create two entries' do
    r1 = '12345678'
    r2 = '56478945'
    fc_array = []
    [r1,r2].each do |r|
      @ref_num = r
      fc_array << @make_entry_lambda.call
    end
    file_content = fc_array.join("\n")
    OpenChain::AllianceParser.parse file_content
    Entry.count.should == 2
    [r1,r2].each {|r| Entry.find_by_broker_reference(r).should_not be_nil}
  end
  it 'should update entry' do
    file_content = @make_entry_lambda.call
    OpenChain::AllianceParser.parse file_content
    ent = Entry.find_by_broker_reference @ref_num
    ent.customer_number.should == @cust_num
    @cust_num = 'ABC'
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    Entry.count.should == 1
    Entry.find(ent.id).customer_number.should == 'ABC'
  end
  it 'should not update entry if older than last update' do
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    old_cust_num = @cust_num
    @cust_num = "nochange"
    @extract_date_str = '199901011226'  #make older
    #send file w/ older date & different cust num which should be ignored
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    Entry.count.should == 1
    Entry.first.customer_number.should == old_cust_num
  end
  it 'should populate entry header tracking fields' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_si_lambda.call}"
    Entry.count.should == 1
    ent = Entry.first
    ent.master_bills_of_lading.should == (@si_lines.collect {|h| h[:mbol]}).join("\n")
    ent.house_bills_of_lading.should == (@si_lines.collect {|h| h[:hbol]}).join("\n")
    ent.sub_house_bills_of_lading.should == (@si_lines.collect {|h| h[:sub]}).join("\n")
    ent.it_numbers.should == (@si_lines.collect {|h| h[:it]}).join("\n")
  end
  it 'should replace entry header tracking fields' do
    Entry.create(:broker_reference=>@ref_num,:it_numbers=>'12345',:master_bills_of_lading=>'mbols',:house_bills_of_lading=>'bolsh',:sub_house_bills_of_lading=>'shs')
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_si_lambda.call}"
    Entry.count.should == 1
    ent = Entry.first
    ent.master_bills_of_lading.should == (@si_lines.collect {|h| h[:mbol]}).join("\n")
    ent.house_bills_of_lading.should == (@si_lines.collect {|h| h[:hbol]}).join("\n")
    ent.sub_house_bills_of_lading.should == (@si_lines.collect {|h| h[:sub]}).join("\n")
    ent.it_numbers.should == (@si_lines.collect {|h| h[:it]}).join("\n")
  end
  it 'should create invoice' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    ent.broker_invoices.should have(1).invoice
    inv = ent.broker_invoices.first
    inv.suffix.should == @inv_suffix
    inv.invoice_date.should == Date.parse(@inv_invoice_date_str)
    inv.invoice_total.should == @inv_total
    inv.customer_number.should == @cust_num
    inv.bill_to_name.should == @inv_b_name
    inv.bill_to_address_1.should == @inv_b_add_1
    inv.bill_to_address_2.should == @inv_b_add_2
    inv.bill_to_city.should == @inv_b_city
    inv.bill_to_zip.should == @inv_b_zip
    inv.bill_to_country.should == @country
  end
  it 'should update invoice' do
    # first invoice
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    ent.broker_invoices.should have(1).invoice
    inv = ent.broker_invoices.first
    inv.suffix.should == @inv_suffix
    inv.invoice_total.should == @inv_total

    #second invoice (update)
    @inv_total = BigDecimal("99.09",2)
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    ent.broker_invoices.should have(1).invoice
    inv = ent.broker_invoices.first
    inv.suffix.should == @inv_suffix
    inv.invoice_total.should == @inv_total
  end
  it 'should add invoice with different suffix' do
    entry = @make_entry_lambda.call
    inv_1 = @make_invoice_lambda.call
    @inv_suffix = '02'
    inv_2 = @make_invoice_lambda.call
    OpenChain::AllianceParser.parse [entry,inv_1,inv_2].join("\n")
    ent = Entry.first
    ent.broker_invoices.should have(2).invoices
    ent.broker_invoices.where(:suffix=>'01').should have(1).invoice
    ent.broker_invoices.where(:suffix=>'02').should have(1).invoice
  end
  it 'should create invoice lines' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    ent.broker_invoices.should have(1).invoice
    inv = ent.broker_invoices.first
    lines = inv.broker_invoice_lines
    lines.should have(@invoice_lines.size).lines
    @invoice_lines.each do |src|
      line = inv.broker_invoice_lines.where(:charge_code=>src[:code]).first
      line.charge_description.should == src[:desc]
      line.charge_amount.should == src[:amt]
      line.vendor_name.should == src[:v_name]
      line.vendor_reference.should == src[:v_ref]
      line.charge_type.should == src[:type]
    end
  end
  it 'should rebuild invoice lines on invoice update' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    @invoice_lines.each {|src| src[:desc] = "newdesc"}
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    ent.broker_invoices.should have(1).invoice
    inv = ent.broker_invoices.first
    lines = inv.broker_invoice_lines
    lines.should have(@invoice_lines.size).lines
    @invoice_lines.each do |src|
      line = inv.broker_invoice_lines.where(:charge_code=>src[:code]).first
      line.charge_description.should == src[:desc]
      line.charge_amount.should == src[:amt]
      line.vendor_name.should == src[:v_name]
      line.vendor_reference.should == src[:v_ref]
      line.charge_type.should == src[:type]
    end
  end
end
