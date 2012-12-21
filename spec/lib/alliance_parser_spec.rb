require 'spec_helper'

describe OpenChain::AllianceParser do
  before :each do
    OpenChain::AllianceImagingClient.stub(:request_images)
    @ref_num ='36469000' 
    @filer_code = '316'
    @entry_ext = '12345678'
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
    @file_logged_date_str = '201004191623'
    @first_entry_sent_str = '201006141227'
    @fda_release_str = "201203170614"
    @fda_review_str = "201203151621"
    @fda_transmit_str = "201203141421"
    @docs_rec_str = "20120414"
    @docs_rec2_str = @docs_rec_str #this will be an override tested later
    @total_packages = 88
    @total_fees = BigDecimal("999.88",2)
    @total_duty = BigDecimal("55.27",2)
    @total_duty_direct = BigDecimal("44.52",2)
    @entered_value = BigDecimal("6622.48",2)
    @customer_references = "ref1\n ref2\n ref3"
    @export_date_str = '201104261121'
    @merchandise_description = 'merch desc'
    @total_packages_uom = 'CTN'
    @entry_port_code = '1235'
    @lading_port_code = '55468'
    @unlading_port_code = '6685'
    @transport_mode_code = '11'
    @ult_consignee_code = 'abcdef' 
    @ult_consignee_name = 'u consign nm'
    @consignee_address_1 = 'ca1'
    @consignee_address_2 = 'ca2'
    @consignee_city = 'ccity'
    @consignee_state = 'NJ'
    @gross_weight = 50
    @vessel = 'vess'
    @voyage = 'voy'
    @recon = 'BBBB'
    @release_cert_message = 'ABCDEFA AF'
    @fda_message = 'FDFDFJDSFSFD'
    @hmf = BigDecimal('55.22',2)
    @mpf = BigDecimal('271.14',2)
    @cotton_fee = BigDecimal('123.31',2)
    @paperless = 'Y'
    @error_free = 'Y'
    @census_warning = 'Y'
    @paperless_cert = 'Y'
    @destination_state = 'PA'
    @liq_type_code = '01'
    @liq_type = 'LIQTYPE'
    @liq_action_code = '22'
    @liq_action = 'LIQACT'
    @liq_ext_code = '33'
    @liq_ext = 'XX'
    @liq_ext_ct = 3
    @liq_duty = 10.01
    @liq_fees = 11.15
    @liq_tax = 6.22
    @liq_ada = 12.12
    @liq_cvd = 0.10
    @daily_stmt_number = '123456'
    @daily_stmt_due_str = '20120407'
    @daily_stmt_approved_str = '20120408'
    @monthly_stmt_number = '654321'
    @monthly_stmt_due_str = '20120516'
    @monthly_stmt_received_str = '20120517'
    @monthly_stmt_paid_str = '20120519'
    @pay_type = '7'
    @comments = [{:text=>"Entry Summary queued to send",:date=>'201104211824',:user=>'BDEVITO'}]
    convert_cur = lambda {|c,width| c ? (c * 100).to_i.to_s.rjust(width,'0') : "".rjust(width,'0')}
    @make_entry_lambda = lambda {
      r = []
      r << "SH00#{@ref_num.rjust(10,"0")}#{@cust_num.ljust(10)}#{@extract_date_str}#{@company_number}#{@division}#{@customer_name.ljust(35)}#{@merchandise_description.ljust(70)}IDID#{@lading_port_code.ljust(5,'0')}#{@unlading_port_code.ljust(4,'0')}#{@entry_port_code.rjust(4,'0')}#{@transport_mode_code}#{@entry_type}#{@filer_code}0#{@entry_ext}#{@ult_consignee_code.ljust(10)}#{@ult_consignee_name.ljust(35)}#{@carrier_code.ljust(4)}00F792ETIHAD AIRWAYS                     #{@vessel.ljust(20)}#{@voyage.ljust(10)}#{@total_packages.to_s.rjust(12,'0')}#{@total_packages_uom.ljust(6)}#{@gross_weight.to_s.rjust(12,'0')}0000000014400WEDG#{@daily_stmt_number.ljust(11)}#{@pay_type}N   N#{@liq_type_code.ljust(2)}#{@liq_type.ljust(35)}#{@liq_action_code.ljust(2)}#{@liq_action.ljust(35)}#{@liq_ext_code.ljust(2)}#{@liq_ext.ljust(35)}#{@liq_ext_ct}LQ090419ESP       N05#{@census_warning}#{@error_free}#{@paperless_cert}#{@paperless}YVFEDI     "
      r << "SH01#{@release_cert_message.ljust(33)}#{"".ljust(12)}#{convert_cur.call(@total_duty,12)}#{convert_cur.call(@liq_duty,12)}#{"".ljust(12)}#{convert_cur.call(@total_fees,12)}#{convert_cur.call(@liq_fees,12)}#{"".ljust(24)}#{convert_cur.call(@liq_tax,12)}#{"".ljust(24)}#{convert_cur.call(@liq_ada,12)}#{"".ljust(24)}#{convert_cur.call(@liq_cvd,12)}#{@fda_message.ljust(33)}#{"".ljust(107)}#{convert_cur.call(@total_duty_direct,12)}#{"".ljust(15)}#{convert_cur.call(@entered_value,13)}#{@recon}#{"".ljust(12)}#{@monthly_stmt_number.ljust(11)}#{"".ljust(13)}#{"".ljust(2)}#{@monthly_stmt_due_str}"
      r << "SH03#{"".ljust(285)}#{@consignee_address_1.ljust(35)}#{@consignee_address_2.ljust(35)}#{@consignee_city.ljust(35)}#{@consignee_state.ljust(2)}"
      r << "SH04DAS DISTRIBUTORS INC               DAS DISTRIBUTORS INC               724 LAWN RD                                                           PALMYRA                     PA17078    20110808#{@destination_state}                XQPIOTRA1932TIL            20110808   Vandegrift Forwarding Co. Inc.     0000000550900000000000000000000000000                                                                                                                                                                                    "
      r << "SD0000012#{@arrival_date_str}200904061628Arr POE Arrival Date Port of Entry                                  "
      r << "SD0000016#{@entry_filed_date_str}2009040616333461FILDEntry Filed (3461,3311,7523)                                "
      r << "SD0000019#{@release_date_str}200904061633Release Release Date                                                "
      r << "SD0099202#{@first_release_date_str}200904061633Ist Rel First Release date                                          "
      r << "SD0000052#{@free_date_str}200904081441Free    Free Date                                                   "
      r << "SD0000028#{@last_billed_date_str}200904061647Bill PrtLast Billed                                                 "
      r << "SD0000032#{@invoice_paid_date_str}200905111220InvPaid Invoice Paid by Customer                                    "
      r << "SD0000044#{@liquidation_date_str}201002190115Liq DateLiquidation Date                                            "
      r << "SD0000042#{@duty_due_date_str}1606201111171606Pay Due Payment Due Date                                            "
      r << "SD0000001#{@export_date_str}201111171606Pay Due Payment Due Date                                            "
      r << "SD0000004#{@file_logged_date_str}201112211325Logged  File Logged or First Entry into System for Shipment     "
      r << "SD0000020#{@fda_release_str}201203230637F&D Rel Food & Drug Release                                         "
      r << "SD0093002#{@fda_review_str}201203181105FDA Rev FDA Review                                                  "
      r << "SD0000108#{@fda_transmit_str}201203161906FDA Cus FDA to Customs                                              "
      r << "SD0099212#{@first_entry_sent_str}"
      r << "SD0000003#{@docs_rec_str}1826                                                                            "
      r << "SD0000098#{@docs_rec2_str}1826                                                                            "
      r << "SD0000048#{@daily_stmt_due_str}1826                                                                            "
      r << "SD0000121#{@daily_stmt_approved_str}1826                                                                            "
      r << "SD0099310#{@monthly_stmt_received_str}1826                                                                            "
      r << "SD0099311#{@monthly_stmt_paid_str}1826                                                                            "
      r << "SU01#{"".ljust(35)}501#{convert_cur.call(@hmf,11)}"
      r << "SU01#{"".ljust(35)}499#{convert_cur.call(@mpf,11)}"
      r << "SU01#{"".ljust(35)}056#{convert_cur.call(@cotton_fee,11)}"
      unless @comments.blank?
        @comments.each do |c|
          r << "SN00#{c[:text].ljust(60)}#{c[:date]}   #{c[:user].ljust(12)}"
        end
      end
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
      {:mbol=>'MAEU12345678',:it=>'123456789',:hbol=>'H325468',:sub=>'S19148kf',:fit=>'20120603'},
      {:mbol=>'OOCL81851511',:it=>'V58242151',:hbol=>'H35156181',:sub=>'S5555555',:fit=>'20120604'}
    ]
    @make_si_lambda = lambda {
      rows = []
      @si_lines.each {|h| rows << "SI00#{h[:it].ljust(12)}#{h[:mbol].ljust(16)}#{h[:hbol].ljust(12)}#{h[:sub].ljust(12)}#{"".ljust(42)}#{h[:fit]}"}
      rows.join("\n")
    }
    #array of hashes for each invoice
    @commercial_invoices = [
      {:invoice_number=>'19319111',:mfid=>'12345',:invoiced_value=>BigDecimal("41911.23",2),
        :currency=>"USD",:exchange_rate=>BigDecimal("12.345678",6),:invoice_value_foreign=>BigDecimal("123.14",2),
        :country_origin_code=>"CN",:gross_weight=>"1234",:total_charges=>BigDecimal("5546.21"),:invoice_date=>"20111203",
        :lines=>[
        {:export_country_code=>'CN',:origin_country_code=>'NZ',:vendor_name=>'vend 01',:units=>BigDecimal("144.214",3),:units_uom=>'PCS',
          :po_number=>'abcdefg',:part_number=>'1291010', :department=>"123456",
          :mid=>'faljdsiadfl',:charges=>BigDecimal('120301.20'),:related_parties=>true,:volume=>BigDecimal('12391.21',2),:computed_value=>BigDecimal('123.45',2),
          :value=>BigDecimal('3219.23',2),:computed_adjustments=>BigDecimal('3010.32',2),:computed_net_value=>BigDecimal('301.21',2),
          :related_parties => true, :mpf=>BigDecimal('27.01',2), :hmf=>BigDecimal('23.12',2), :prorated_mpf=>BigDecimal('50.26'), :cotton_fee=>BigDecimal('15.22',2),
          :tariff=>[{
            :duty_total=>BigDecimal("21.10",2),:entered_value=>BigDecimal('19311.12',2),:spi_primary=>'A',:spi_secondary=>'B',:hts_code=>'6504212121',
            :class_q_1=>BigDecimal('10.04',2),:class_uom_1=>'ABC', 
            :class_q_2=>BigDecimal('11.04',2),:class_uom_2=>'ABC', 
            :class_q_3=>BigDecimal('12.04',2),:class_uom_3=>'ABC', 
            :gross_weight=>"551",:tariff_description=>"ABC 123 DEF"
          },
          {
            :duty_total=>BigDecimal("16.10",2),:entered_value=>BigDecimal('190311.12',2),:spi_primary=>'C',:spi_secondary=>'D',:hts_code=>'2702121210',
            :class_q_1=>BigDecimal('14.04',2),:class_uom_1=>'ABC', 
            :class_q_2=>BigDecimal('15.04',2),:class_uom_2=>'ABC', 
            :class_q_3=>BigDecimal('16.04',2),:class_uom_3=>'ABC', 
            :gross_weight=>"559",:tariff_description=>"BDAFDADdafda"
          }]
          },
        {:part_number=>'101301',:export_country_code=>'CN',:origin_country_code=>'NZ',:vendor_name=>'vend 01',:units=>BigDecimal("8",3),:units_uom=>'EA',:po_number=>'1921301'}
      ]},
      {:invoice_number=>'491919fadf',:mfid=>'12345',:invoiced_value=>BigDecimal("41911.23",2),
        :currency=>"USD",:exchange_rate=>BigDecimal("12.345678",6),:invoice_value_foreign=>BigDecimal("123.14",2),
        :country_origin_code=>"CN",:gross_weight=>"1234",:total_charges=>BigDecimal("5546.21"),:invoice_date=>"20111203",
        :lines=>[{:export_country_code=>'CN',:origin_country_code=>'NZ',:vendor_name=>'vend 01',:units=>BigDecimal("29.111",3),:units_uom=>'EA',:spi_1=>"X",:part_number=>'123918',:mpf=>BigDecimal('100.00',2)}
        ]},
      {:invoice_number=>'ff30101ffz',:mfid=>'MFIfdlajf1',:invoiced_value=>BigDecimal("611.23",2),
        :currency=>"USD",:exchange_rate=>BigDecimal("12.345678",6),:invoice_value_foreign=>BigDecimal("123.14",2),
        :country_origin_code=>"CN",:gross_weight=>"1234",:total_charges=>BigDecimal("5546.21"),:invoice_date=>"20111203",
        :lines=>[{:export_country_code=>'TW',:origin_country_code=>'AU',:vendor_name=>'v2',:units=>BigDecimal("2.116",3),:units_uom=>'DOZ',:po_number=>'jfdaila',:part_number=>'fjasjds'}
        ]}
    ] 
    @make_commercial_invoices_lambda = lambda {
      rows = []
      @commercial_invoices.each do |ci|
        ci00 = "CI00#{ci[:invoice_number].ljust(22)}#{ci[:currency].ljust(3)}#{(ci[:exchange_rate] * 1000000).to_i.to_s.rjust(8,'0')}"
        ci00 << "#{convert_cur.call(ci[:invoice_value_foreign],13)}#{convert_cur.call(ci[:invoiced_value],13)}#{ci[:country_origin_code].ljust(2)}"
        ci00 << "#{ci[:gross_weight].rjust(12)}#{convert_cur.call(ci[:total_charges],11)}#{ci[:invoice_date]}#{ci[:mfid].ljust(15)}"
        rows << ci00
        ci[:lines].each do |line|
          [:mid,:po_number,:department].each {|k| line[k]='' unless line[k]}
          rows << "CL00#{line[:part_number].ljust(30)}#{(line[:units]*1000).to_i.to_s.rjust(12,"0")}#{line[:units_uom].ljust(6)}#{line[:mid].ljust(15)}#{line[:origin_country_code]}#{"".ljust(11)}#{line[:export_country_code]}#{line[:related_parties] ? 'Y' : 'N'}#{line[:vendor_name].ljust(35)}#{convert_cur.call(line[:volume],11)}#{"".ljust(18)}#{line[:department].ljust(6)}#{"".ljust(27)}#{line[:po_number].ljust(35)}#{"".ljust(45)}#{convert_cur.call(line[:computed_value],13)}#{convert_cur.call(line[:value],13)}#{"".ljust(13,"0")}#{convert_cur.call(line[:computed_adjustments],13)}#{convert_cur.call(line[:computed_net_value],13)}#{"".ljust(8)}"
          if line[:tariff]
            line[:tariff].each do |t|
              t_row = "CT00#{convert_cur.call(t[:duty_total],12)}#{convert_cur.call(t[:entered_value],13)}#{t[:spi_primary].ljust(2)}#{t[:spi_secondary].ljust(1)}#{t[:hts_code].ljust(10)}"
              (1..3).each do |i|
                t_row << "#{convert_cur.call(t["class_q_#{i}".to_sym],12)}#{t["class_uom_#{i}".to_sym].ljust(6)}"
              end
              t_row << "#{t[:tariff_description].ljust(35)}#{t[:gross_weight].rjust(12,'0')}"
              rows << t_row
            end
          end
          rows << "CF00499#{convert_cur.call(line[:mpf] ? line[:mpf] : 0,11)}#{"".ljust(11)}#{line[:prorated_mpf] ? convert_cur.call(line[:prorated_mpf],11) : "00000000000"}"
          rows << "CF00501#{convert_cur.call(line[:hmf],11)}" if line[:hmf]
          rows << "CF00056#{convert_cur.call(line[:cotton_fee],11)}" if line[:cotton_fee]

        end
      end
      rows.join("\n")
    }
    @containers = [
      {:cnum=>'153153',:csize=>'abcdef',:cdesc=>"HC",:fcl_lcl=>'F'},
      {:cnum=>'afii1911010',:csize=>'123949',:cdesc=>"DRY VAN",:fcl_lcl=>'L'}
    ]
    @make_containers_lambda = lambda {
      rows = []
      @containers.each do |c|
        rows << "SC00#{c[:cnum].ljust(15)}#{"".ljust(40)}#{c[:csize].ljust(7)}#{"".ljust(205)}#{c[:fcl_lcl].ljust(1)}#{"".ljust(11)}#{c[:cdesc].ljust(40)}"
      end
      rows.join("\n")
    }
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    @split_string = "\n "
  end
  it 'should set 7501 print dates' do
    first_7501 = '201104211627'
    last_7501 = '201104221217'
    @comments << {:text=>"Document Image created for F7501F   7501 Form.              ",:date=>first_7501,:user=>'BDEVITO'}
    @comments << {:text=>"Document Image created for F7501F   7501 Form.              ",:date=>last_7501,:user=>'BDEVITO'}
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    ent.first_7501_print.should == @est.parse(first_7501)
    ent.last_7501_print.should == @est.parse(last_7501)
  end
  it 'should aggregate containers' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    expected_containers = @containers.collect {|c| c[:cnum]}
    expected_sizes = @containers.collect {|c| "#{c[:csize]}-#{c[:cdesc]}"}
    ent.container_numbers.split(@split_string).should == expected_containers
    ent.container_sizes.split(@split_string).should == expected_sizes
  end
  it 'should set fcl_lcl to mixed if different flags on different containers' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    ent.fcl_lcl.should == 'Mixed'
  end
  it 'should set fcl_lcl to lcl if "L" on all containers' do
    @containers.each {|c| c[:fcl_lcl] = "L"}
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    ent.fcl_lcl.should == 'LCL'
  end
  it 'should set fcl_lcl to fcl if "F" on all containers' do
    @containers.each {|c| c[:fcl_lcl] = "F"}
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    ent.fcl_lcl.should == 'FCL'
  end
  it 'should set fcl_lcl to FCL even if only one container has value' do
    @containers.each {|c| c[:fcl_lcl] = ""}
    @containers.first[:fcl_lcl] = "F"
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    ent.fcl_lcl.should == 'FCL'
  end
  it 'should set fcl_lcl to nil if no values' do
    @containers.each {|c| c[:fcl_lcl] = ""}
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    ent.fcl_lcl.should be_nil
  end

  it 'should match importer id if customer matches' do
    company = Factory(:company,:importer=>true,:alliance_customer_number=>@cust_num)
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    ent = Entry.find_by_broker_reference @ref_num
    ent.importer.should == company
  end
  it 'should create importer if customer number does not match' do
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    ent = Entry.find_by_broker_reference @ref_num
    company = Company.find_by_alliance_customer_number @cust_num
    company.should be_importer
    company.name.should == @customer_name
    ent.importer.should == company
  end
  
  it "should write bucket_name & key" do
    OpenChain::AllianceParser.parse @make_entry_lambda.call, {:bucket=>'a',:key=>'b'}
    ent = Entry.find_by_broker_reference @ref_num
    ent.last_file_bucket.should == 'a'
    ent.last_file_path.should == 'b'
  end

  it 'should create entry' do
    file_content = "#{@make_entry_lambda.call}\n#{@make_commercial_invoices_lambda.call}"
    OpenChain::AllianceParser.parse file_content
    ent = Entry.find_by_broker_reference @ref_num
    ent.import_country.should == Country.find_by_iso_code('US')
    ent.source_system.should == 'Alliance'
    ent.entry_number.should == "#{@filer_code}#{@entry_ext}"
    ent.customer_number.should == @cust_num
    ent.last_exported_from_source.should == @est.parse(@extract_date_str)
    ent.company_number.should == @company_number
    ent.division_number.should == @division
    ent.customer_name.should == @customer_name
    ent.entry_type.should == @entry_type
    ent.arrival_date.should == @est.parse(@arrival_date_str)
    ent.entry_filed_date.should == @est.parse(@entry_filed_date_str)
    ent.release_date.should == @est.parse(@release_date_str)
    ent.file_logged_date.should == @est.parse(@file_logged_date_str)
    ent.first_release_date.should == @est.parse(@first_release_date_str)
    ent.free_date.should == @est.parse(@free_date_str)
    ent.last_billed_date.should == @est.parse(@last_billed_date_str)
    ent.invoice_paid_date.should == @est.parse(@invoice_paid_date_str)
    ent.liquidation_date.should == @est.parse(@liquidation_date_str)
    ent.fda_release_date.should == @est.parse(@fda_release_str)
    ent.fda_review_date.should == @est.parse(@fda_review_str)
    ent.fda_transmit_date.should == @est.parse(@fda_transmit_str)
    ent.first_entry_sent_date.should == @est.parse(@first_entry_sent_str)
    ent.docs_received_date.strftime("%Y%m%d").should == @docs_rec_str
    ent.release_cert_message.should == @release_cert_message
    ent.fda_message == @fda_message
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
    ent.lading_port_code.should == @lading_port_code
    ent.unlading_port_code.should == @unlading_port_code
    ent.ult_consignee_code.should == @ult_consignee_code
    ent.ult_consignee_name.should == @ult_consignee_name
    ent.consignee_address_1 == @consignee_address_1
    ent.consignee_address_2 == @consignee_address_2
    ent.consignee_city == @consignee_city
    ent.consignee_state == @consignee_state
    ent.gross_weight.should == @gross_weight
    ent.cotton_fee.should == @cotton_fee
    ent.hmf.should == @hmf
    ent.mpf.should == @mpf
    ent.vessel.should == @vessel
    ent.voyage.should == @voyage
    ent.should be_paperless_release
    ent.should be_census_warning
    ent.should be_error_free_release
    ent.should be_paperless_certification
    ent.destination_state.should == @destination_state
    ent.liquidation_type_code.should == @liq_type_code
    ent.liquidation_type.should == @liq_type
    ent.liquidation_action_code.should == @liq_action_code
    ent.liquidation_action_description.should == @liq_action
    ent.liquidation_extension_code.should == @liq_ext_code
    ent.liquidation_extension_description.should == @liq_ext
    ent.liquidation_extension_count.should == @liq_ext_ct
    ent.liquidation_duty.should == @liq_duty
    ent.liquidation_fees.should == @liq_fees
    ent.liquidation_tax.should == @liq_tax
    ent.liquidation_ada.should == @liq_ada
    ent.liquidation_cvd.should == @liq_cvd
    ent.liquidation_total.should == (@liq_duty+@liq_fees+@liq_tax+@liq_ada+@liq_cvd)
    ent.daily_statement_number.should == @daily_stmt_number
    ent.daily_statement_due_date.strftime("%Y%m%d").should == @daily_stmt_due_str
    ent.daily_statement_approved_date.strftime("%Y%m%d").should == @daily_stmt_approved_str
    ent.monthly_statement_due_date.strftime("%Y%m%d").should == @monthly_stmt_due_str
    ent.monthly_statement_received_date.strftime("%Y%m%d").should == @monthly_stmt_received_str
    ent.monthly_statement_paid_date.strftime("%Y%m%d").should == @monthly_stmt_paid_str
    ent.monthly_statement_number.should == @monthly_stmt_number

    ent.mfids.split(@split_string).should == Set.new(@commercial_invoices.collect {|ci| ci[:mfid]}).to_a

    expected_invoiced_value = BigDecimal("0",2)
    expected_export_country_codes = Set.new
    expected_origin_country_codes = Set.new
    expected_vendor_names = Set.new
    expected_total_units_uoms = Set.new
    expected_spis = Set.new
    expected_pos = Set.new 
    expected_total_units = BigDecimal("0",2)
    
    @commercial_invoices.each do |ci| 
      invoices = ent.commercial_invoices.where(:invoice_number=>ci[:invoice_number])
      invoices.should have(1).item
      inv = invoices.first
      expected_invoiced_value += ci[:invoiced_value]
      ci[:lines].each do |line|
        expected_export_country_codes << line[:export_country_code]
        expected_origin_country_codes << line[:origin_country_code]
        expected_vendor_names << line[:vendor_name]
        expected_total_units_uoms << line[:units_uom]
        expected_total_units += line[:units]
        expected_pos << line[:po_number] unless line[:po_number].blank?

        ci_line = inv.commercial_invoice_lines.where(:part_number=>line[:part_number]).first
        ci_line.mid.should == line[:mid]
        ci_line.po_number.should == line[:po_number]
        ci_line.quantity.should == line[:units]
        ci_line.unit_of_measure.should == line[:units_uom]
        ci_line.value.should == line[:value] unless line[:value].nil?
        ci_line.mid.should == line[:mid]
        ci_line.country_origin_code.should == line[:origin_country_code]
        ci_line.charges.should == line[:total_charges]
        ci_line.country_export_code.should == line[:export_country_code]
        ci_line.related_parties?.should == (line[:related_parties] ? line[:related_parties] : false)
        ci_line.vendor_name.should == line[:vendor_name]
        ci_line.volume.should == line[:volume] if line[:volume]
        ci_line.computed_value.should == line[:computed_value] if line[:computed_value]
        ci_line.computed_adjustments.should == line[:computed_adjustments] if line[:computed_adjustments]
        ci_line.computed_net_value.should == line[:computed_net_value] if line[:computed_net_value]
        ci_line.mpf.should == (line[:mpf] ? line[:mpf] : 0)
        ci_line.hmf.should == line[:hmf]
        if line[:prorated_mpf]
          ci_line.prorated_mpf.should == line[:prorated_mpf]
        else
          ci_line.prorated_mpf.should == (line[:mpf] ? line[:mpf] : 0)
        end
        ci_line.department.should == line[:department]
        ci_line.cotton_fee.should == line[:cotton_fee]
        (ci_line.unit_price*100).to_i.should == ( (ci_line.value / ci_line.quantity) * 100 ).to_i if ci_line.unit_price && ci_line.quantity
        if line[:tariff]
          line[:tariff].each do |t_line|
            found = ci_line.commercial_invoice_tariffs.where(:hts_code=>t_line[:hts_code])
            found.should have(1).record
            t = found.first
            t.duty_amount.should == t_line[:duty_total]
            t.entered_value.should == t_line[:entered_value]
            t.duty_rate.should == ( t_line[:duty_total]/t_line[:entered_value] ).round(3)
            t.spi_primary.should == t_line[:spi_primary]
            t.spi_secondary.should == t_line[:spi_secondary]
            t.hts_code.should == t_line[:hts_code]
            t.classification_qty_1.should == t_line[:class_q_1]
            t.classification_qty_2.should == t_line[:class_q_2]
            t.classification_qty_3.should == t_line[:class_q_3]
            t.classification_uom_1.should == t_line[:class_uom_1]
            t.classification_uom_2.should == t_line[:class_uom_2]
            t.classification_uom_3.should == t_line[:class_uom_3]
            t.tariff_description.should == t_line[:tariff_description]
            t.gross_weight.to_s.should == t_line[:gross_weight]
            [:spi_primary,:spi_secondary].each {|k| expected_spis << t_line[k] unless t_line[k].blank?}
          end
        end
      end
      inv.currency.should == ci[:currency]
      inv.exchange_rate.should == ci[:exchange_rate]
      inv.invoice_value_foreign.should == ci[:invoice_value_foreign]
      inv.invoice_value.should == ci[:invoiced_value]
      inv.country_origin_code.should == ci[:country_origin_code]
      inv.total_charges.should == ci[:total_charges]
      inv.gross_weight.should == ci[:gross_weight].to_i
      inv.invoice_date.strftime("%Y%m%d").should == ci[:invoice_date]
      inv.mfid.should == ci[:mfid]
    end

    ent.total_invoiced_value.should == expected_invoiced_value
    ent.export_country_codes.split(@split_string).should == expected_export_country_codes.to_a
    ent.origin_country_codes.split(@split_string).should == expected_origin_country_codes.to_a
    ent.vendor_names.split(@split_string).should == expected_vendor_names.to_a
    ent.total_units.should == expected_total_units
    ent.total_units_uoms.split(@split_string).should == expected_total_units_uoms.to_a
    ent.po_numbers.split(@split_string).should == expected_pos.to_a
    ent.special_program_indicators.split(@split_string).should == expected_spis.to_a

    ent.time_to_process.should < 1000 
    ent.time_to_process.should > 0
  end

  it "should write a comment" do
    @comments.size.should == 1
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    comments = Entry.find_by_broker_reference(@ref_num).entry_comments
    comments.should have(1).comment
    comm = comments.first
    comm.username.should == @comments.first[:user]
    comm.body.should == @comments.first[:text]
    comm.generated_at.should == @est.parse(@comments.first[:date])
  end

  it 'code 00098 should override 00003 if it comes second in file' do
    @docs_rec2_str = "20120613"
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    Entry.find_by_broker_reference(@ref_num).docs_received_date.strftime("%Y%m%d").should == @docs_rec2_str
  end

  it 'should set paperless release to false if empty' do
    @paperless = ' '
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    Entry.find_by_broker_reference(@ref_num).paperless_release.should == false
  end

  it 'should set census warning to false if empty' do
    @census_warning = ' '
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    Entry.find_by_broker_reference(@ref_num).census_warning.should == false
  end

  it 'should set error_free_release to false if empty' do
    @error_free = ' '
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    Entry.find_by_broker_reference(@ref_num).error_free_release.should == false
  end

  it 'should set paperless_certification to false if empty' do
    @paperless_cert = ' '
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    Entry.find_by_broker_reference(@ref_num).paperless_certification.should == false
  end

  it 'should only update entries with Alliance as source' do
    old_ent = Factory(:entry,:broker_reference=>@ref_num) #doesn't have matching source system
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    entries = Entry.where(:broker_reference=>@ref_num)
    entries.should have(2).items
  end

  it 'should not duplicate commercial invoices when reprocessing' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_commercial_invoices_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    ent.commercial_invoices.should have(@commercial_invoices.size).invoices
    #do it twice
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_commercial_invoices_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    ent.commercial_invoices.should have(@commercial_invoices.size).invoices
  end

  context 'recon flags' do
    it 'should expand nafta' do
      @recon = 'BNNN'
      OpenChain::AllianceParser.parse @make_entry_lambda.call
      Entry.find_by_broker_reference(@ref_num).recon_flags.should == "NAFTA"
    end
    it 'should expand value' do
      @recon = 'NBNN'
      OpenChain::AllianceParser.parse @make_entry_lambda.call
      Entry.find_by_broker_reference(@ref_num).recon_flags.should == "VALUE"
    end
    it 'should expand class' do
      @recon = 'NNBN'
      OpenChain::AllianceParser.parse @make_entry_lambda.call
      Entry.find_by_broker_reference(@ref_num).recon_flags.should == "CLASS"
    end
    it 'should expand 9802' do
      @recon = 'NNNB'
      OpenChain::AllianceParser.parse @make_entry_lambda.call
      Entry.find_by_broker_reference(@ref_num).recon_flags.should == "9802"
    end
    it 'should combine flags' do
      @recon = 'BBBB'
      OpenChain::AllianceParser.parse @make_entry_lambda.call
      Entry.find_by_broker_reference(@ref_num).recon_flags.should == "NAFTA\n VALUE\n CLASS\n 9802"
    end
  end

  it 'should make all zero port codes nil' do
    @lading_port_code = '00000'
    @unlading_port_code = '0000'
    @entry_port_code = '0000'
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    ent = Entry.find_by_broker_reference @ref_num
    ent.lading_port_code.should be_nil
    ent.unlading_port_code.should be_nil
    ent.entry_port_code.should be_nil
  end
  context 'reference fields' do
    it 'should remove po numbers from cust ref' do
      @customer_references = "a\nb\nc"
      @commercial_invoices.first[:lines].first[:po_number] = "b"
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_commercial_invoices_lambda.call}"
      Entry.find_by_broker_reference(@ref_num).customer_references.should == "a\n c"
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
      Entry.find_by_broker_reference(@ref_num).po_numbers.split(@split_string).should == expected_pos.to_a
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
      ent.customer_references.should == "a\n b\n c"
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
    ent.master_bills_of_lading.should == (@si_lines.collect {|h| h[:mbol]}).join(@split_string)
    ent.house_bills_of_lading.should == (@si_lines.collect {|h| h[:hbol]}).join(@split_string)
    ent.sub_house_bills_of_lading.should == (@si_lines.collect {|h| h[:sub]}).join(@split_string)
    ent.it_numbers.should == (@si_lines.collect {|h| h[:it]}).join(@split_string)
    ent.first_it_date.strftime("%Y%m%d").should == '20120603'
  end
  it 'should replace entry header tracking fields' do
    Entry.create(:broker_reference=>@ref_num,:it_numbers=>'12345',:master_bills_of_lading=>'mbols',:house_bills_of_lading=>'bolsh',:sub_house_bills_of_lading=>'shs',:source_system=>OpenChain::AllianceParser::SOURCE_CODE)
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_si_lambda.call}"
    Entry.count.should == 1
    ent = Entry.first
    ent.master_bills_of_lading.should == (@si_lines.collect {|h| h[:mbol]}).join(@split_string)
    ent.house_bills_of_lading.should == (@si_lines.collect {|h| h[:hbol]}).join(@split_string)
    ent.sub_house_bills_of_lading.should == (@si_lines.collect {|h| h[:sub]}).join(@split_string)
    ent.it_numbers.should == (@si_lines.collect {|h| h[:it]}).join(@split_string)
  end
  it 'should create invoice' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    ent.broker_invoices.should have(1).invoice
    inv = ent.broker_invoices.first
    inv.currency.should == "USD" #default
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
  it 'should include all charge codes in entry header charge codes field' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    codes_expected = @invoice_lines.collect {|src| src[:code]}
    Entry.first.charge_codes.lines.collect {|x| x.strip}.should == codes_expected
  end

  it 'should add invoice with different suffix' do
    @inv_total = BigDecimal("10.00")
    entry = @make_entry_lambda.call
    inv_1 = @make_invoice_lambda.call
    @inv_suffix = '02'
    @inv_total = BigDecimal("20.00")
    inv_2 = @make_invoice_lambda.call
    OpenChain::AllianceParser.parse [entry,inv_1,inv_2].join("\n")
    ent = Entry.first
    ent.broker_invoices.should have(2).invoices
    ent.broker_invoices.where(:suffix=>'01').should have(1).invoice
    ent.broker_invoices.where(:suffix=>'02').should have(1).invoice
    ent.broker_invoice_total.should == BigDecimal("30.00")
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

  describe 'process_past_days' do
    it "should delay processing" do
      OpenChain::AllianceParser.should_receive(:delay).exactly(3).times.and_return(OpenChain::AllianceParser)
      OpenChain::AllianceParser.should_receive(:process_day).exactly(3).times
      OpenChain::AllianceParser.process_past_days 3
    end
  end
  describe 'process_day' do
    it 'should process all files from the given day' do
      d = Date.new
      OpenChain::S3.should_receive(:integration_keys).with(d,"/opt/wftpserver/ftproot/www-vfitrack-net/_alliance").and_yield("a").and_yield("b")
      OpenChain::S3.should_receive(:get_data).with(OpenChain::S3.integration_bucket_name,"a").and_return("x")
      OpenChain::S3.should_receive(:get_data).with(OpenChain::S3.integration_bucket_name,"b").and_return("y")
      OpenChain::AllianceParser.should_receive(:parse).with("x",{:bucket=>OpenChain::S3.integration_bucket_name,:key=>"a",:imaging=>false})
      OpenChain::AllianceParser.should_receive(:parse).with("y",{:bucket=>OpenChain::S3.integration_bucket_name,:key=>"b",:imaging=>false})
      OpenChain::AllianceParser.process_day d
    end
  end
end
