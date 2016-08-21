require 'spec_helper'

describe OpenChain::AllianceParser do
  before :each do
    allow(OpenChain::AllianceImagingClient).to receive(:request_images)
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
    @delivery_order_pickup_str = "201308071318"
    @freight_pickup_str = "201308081318"
    @available_date_str = "201308091318"
    @worksheet_date_str = "201308101318"
    @docs_rec_str = "20120414"
    @docs_rec2_str = @docs_rec_str #this will be an override tested later
    @eta_date_str = "201305291340"
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
    
    @bond_type = '8'
    @location_of_goods = "LOCG"
    @make_entry_lambda = lambda {
      r = []
      r << "SH00#{@ref_num.rjust(10,"0")}#{@cust_num.ljust(10)}#{@extract_date_str}#{@company_number}#{@division}#{@customer_name.ljust(35)}#{@merchandise_description.ljust(70)}IDID#{@lading_port_code.ljust(5,'0')}#{@unlading_port_code.ljust(4,'0')}#{@entry_port_code.rjust(4,'0')}#{@transport_mode_code}#{@entry_type}#{@filer_code}0#{@entry_ext}#{@ult_consignee_code.ljust(10)}#{@ult_consignee_name.ljust(35)}#{@carrier_code.ljust(4)}00#{@location_of_goods}ETIHAD AIRWAYS                     #{@vessel.ljust(20)}#{@voyage.ljust(10)}#{@total_packages.to_s.rjust(12,'0')}#{@total_packages_uom.ljust(6)}#{@gross_weight.to_s.rjust(12,'0')}0000000014400WEDG#{@daily_stmt_number.ljust(11)}#{@pay_type}N   N#{@liq_type_code.ljust(2)}#{@liq_type.ljust(35)}#{@liq_action_code.ljust(2)}#{@liq_action.ljust(35)}#{@liq_ext_code.ljust(2)}#{@liq_ext.ljust(35)}#{@liq_ext_ct}LQ090419ESP       N05#{@census_warning}#{@error_free}#{@paperless_cert}#{@paperless}YVFEDI     "
      r << "SH01#{@release_cert_message.ljust(33)}#{"".ljust(12)}#{convert_cur.call(@total_duty,12)}#{convert_cur.call(@liq_duty,12)}#{"".ljust(12)}#{convert_cur.call(@total_fees,12)}#{convert_cur.call(@liq_fees,12)}#{"".ljust(24)}#{convert_cur.call(@liq_tax,12)}#{"".ljust(24)}#{convert_cur.call(@liq_ada,12)}#{"".ljust(24)}#{convert_cur.call(@liq_cvd,12)}#{@fda_message.ljust(33)}#{"".ljust(107)}#{convert_cur.call(@total_duty_direct,12)}#{"".ljust(15)}#{convert_cur.call(@entered_value,13)}#{@recon}#{"".ljust(12)}#{@monthly_stmt_number.ljust(11)}#{"".ljust(13)}#{"".ljust(2)}#{@monthly_stmt_due_str}000000000000000000000000                    #{@bond_type}"
      r << "SH03#{"".ljust(285)}#{@consignee_address_1.ljust(35)}#{@consignee_address_2.ljust(35)}#{@consignee_city.ljust(35)}#{@consignee_state.ljust(2)}"
      r << "SH04DAS DISTRIBUTORS INC               DAS DISTRIBUTORS INC               724 LAWN RD                                                           PALMYRA                     PA17078    20110808#{@destination_state}                XQPIOTRA1932TIL            20110808   Vandegrift Forwarding Co. Inc.     0000000550900000000000000000000000000                                                                                                                                                                                    "
      r << "SD0000012#{@arrival_date_str}200904061628Arr POE Arrival Date Port of Entry                                  "
      r << "SD0000016#{@entry_filed_date_str}2009040616333461FILDEntry Filed (3461,3311,7523)                                "
      r << "SD0000019#{@release_date_str}200904061633Release Release Date                                                " unless @release_date_str.blank?
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
      r << "SD0000011#{@eta_date_str}                                                                                "
      r << "SD0000025#{@delivery_order_pickup_str}                                                                                "
      r << "SD0000026#{@freight_pickup_str}                                                                              "
      r << "SD0002222#{@worksheet_date_str}                                                                              "
      r << "SD0002223#{@available_date_str}                                                                              "
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
      {:invoice_number=>'19319111',:mfid=>'12345',:invoiced_value=>BigDecimal("1520.25",2),
        :currency=>"USD",:exchange_rate=>BigDecimal("12.345678",6),:invoice_value_foreign=>BigDecimal("123.14",2),
        :country_origin_code=>"CN",:gross_weight=>"1234",:total_charges=>BigDecimal("5546.21"),:invoice_date=>"20111203",
        :total_quantity=>"000000000012", :total_quantity_uom=>"CTNS",
        :lines=>[
        {:export_country_code=>'CN',:origin_country_code=>'NZ',:vendor_name=>'vend 01',:units=>BigDecimal("144.214",3),:units_uom=>'PCS',
          :po_number=>'abcdefg',:part_number=>'1291010', :department=>"123456",
          :mid=>'faljdsiadfl',:charges=>BigDecimal('120301.20'),:related_parties=>true,:volume=>BigDecimal('12391.21',2),:computed_value=>BigDecimal('123.45',2),
          :value=>BigDecimal('3219.23',2),:computed_adjustments=>BigDecimal('3010.32',2),:computed_net_value=>BigDecimal('301.21',2),
          :mpf=>BigDecimal('27.01',2), :hmf=>BigDecimal('23.12',2), :prorated_mpf=>BigDecimal('50.26'), :cotton_fee=>BigDecimal('15.22',2),
          :line_number => '00010', :contract_amount => BigDecimal('99.99', 2), :store_name => "Store1",
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
          }],
          :add=>{:case_number => 'A23456789', :bond=> "Y", :amount=>BigDecimal('12345678.90'), :percent=>BigDecimal('123.45'), :value=>BigDecimal('98765432.10')},
          :cvd=>{:case_number => 'C12345678', :bond=> "N", :amount=>BigDecimal('12345678.90'), :percent=>BigDecimal('123.45'), :value=>BigDecimal('98765432.10')}
          },
        {:part_number=>'101301',:export_country_code=>'CN',:origin_country_code=>'NZ',:vendor_name=>'vend 01',:units=>BigDecimal("8",3),:units_uom=>'EA',:po_number=>'1921301', :product_line=>"PLINE", :store_name => "Store2"}
      ]},
      {:invoice_number=>'491919fadf',:mfid=>'12345',:invoiced_value=>BigDecimal("1520.25",2),
        :currency=>"USD",:exchange_rate=>BigDecimal("12.345678",6),:invoice_value_foreign=>BigDecimal("123.14",2),
        :country_origin_code=>"CN",:gross_weight=>"1234",:total_charges=>BigDecimal("5546.21"),:invoice_date=>"20111203",
        :total_quantity=>"000000000001", :total_quantity_uom=>"BINDLE",
        :lines=>[{:export_country_code=>'CN',:origin_country_code=>'NZ',:vendor_name=>'vend 01',:units=>BigDecimal("29.111",3),:units_uom=>'EA',:spi_1=>"X",:part_number=>'123918',:mpf=>BigDecimal('100.00',2), :contract_amount => BigDecimal('0')}
        ]},
      {:invoice_number=>'ff30101ffz',:mfid=>'MFIfdlajf1',:invoiced_value=>BigDecimal("1520.25",2),
        :currency=>"USD",:exchange_rate=>BigDecimal("12.345678",6),:invoice_value_foreign=>BigDecimal("123.14",2),
        :country_origin_code=>"CN",:gross_weight=>"1234",:total_charges=>BigDecimal("5546.21"),:invoice_date=>"20111203",
        :total_quantity=>"000000000099", :total_quantity_uom=>"BOTTLE",
        :lines=>[{:export_country_code=>'TW',:origin_country_code=>'AU',:vendor_name=>'v2',:units=>BigDecimal("2.116",3),:units_uom=>'DOZ',:po_number=>'jfdaila',:part_number=>'fjasjds', :contract_amount =>""}
        ]}
    ] 
    @make_commercial_invoices_lambda = lambda {
      rows = []
      @commercial_invoices.each do |ci|
        ci00 = "CI00#{ci[:invoice_number].ljust(22)}#{ci[:currency].ljust(3)}#{(ci[:exchange_rate] * 1000000).to_i.to_s.rjust(8,'0')}"
        ci00 << "#{convert_cur.call(ci[:invoice_value_foreign],13)}#{convert_cur.call(ci[:invoiced_value],13)}#{ci[:country_origin_code].ljust(2)}"
        ci00 << "#{ci[:gross_weight].rjust(12)}#{convert_cur.call(ci[:total_charges],11)}#{ci[:invoice_date]}#{ci[:mfid].ljust(15)}"
        rows << ci00
        rows << "CI01#{ci[:total_quantity].rjust(12, '0')}#{ci[:total_quantity_uom].ljust(6)}"
        ci[:lines].each do |line|
          [:mid,:po_number,:department].each {|k| line[k]='' unless line[k]}
          # Note: Contract Amount specifically is not using the convert_cur lambda because the test files for this value DID have decimal points in the values.
          rows << "CL00#{line[:part_number].ljust(30)}#{(line[:units]*1000).to_i.to_s.rjust(12,"0")}#{line[:units_uom].ljust(6)}#{line[:mid].ljust(15)}#{line[:origin_country_code]}#{"".ljust(11)}#{line[:export_country_code]}#{line[:related_parties] ? 'Y' : 'N'}#{line[:vendor_name].ljust(35)}#{convert_cur.call(line[:volume],11)}#{"".ljust(6)}#{line[:contract_amount].to_s.ljust(10)}#{"".ljust(2)}#{line[:department].ljust(6)}#{"".ljust(27)}#{line[:po_number].ljust(35)}#{line[:store_name].to_s.ljust(15)}#{line[:product_line].to_s.rjust(30)}#{convert_cur.call(line[:computed_value],13)}#{convert_cur.call(line[:value],13)}#{"".ljust(13,"0")}#{convert_cur.call(line[:computed_adjustments],13)}#{convert_cur.call(line[:computed_net_value],13)}#{"".ljust(8)}"
          rows << "CL01#{"".ljust(426)}#{line[:line_number]}"
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
          
          cvd_add_line = lambda {|type, v| "CP00#{type}A#{v[:case_number].ljust(9)}#{convert_cur.call(v[:value],10)}#{convert_cur.call(v[:percent],5)}#{v[:bond]}0#{convert_cur.call(v[:amount],10)}"}
          rows << cvd_add_line.call("ADA", line[:add]) if line[:add]
          rows << cvd_add_line.call("CVD", line[:cvd]) if line[:cvd]

          rows << "CF00499#{convert_cur.call(line[:mpf] ? line[:mpf] : 0,11)}#{"".ljust(11)}#{line[:prorated_mpf] ? convert_cur.call(line[:prorated_mpf],11) : "00000000000"}"
          rows << "CF00501#{convert_cur.call(line[:hmf],11)}" if line[:hmf]
          rows << "CF00056#{convert_cur.call(line[:cotton_fee],11)}" if line[:cotton_fee]

        end
      end
      rows.join("\n")
    }
    @containers = [
      {:cnum=>'153153',:csize=>'abcdef',:cdesc=>"HC",:fcl_lcl=>'F',:weight=>12,:quantity=>5,:uom=>'EA',:gdesc=>'WEARING APPAREL',:teus=>1,:seal=>'12345'},
      {:cnum=>'afii1911010',:csize=>'123949',:cdesc=>"DRY VAN",:fcl_lcl=>'L',:weight=>3,:quantity=>6,:uom=>'PRS',:gdesc=>'WEARING APPAREL',:teus=>2,:seal=>'SEAL1'}
    ]
    @make_containers_lambda = lambda {
      rows = []
      @containers.each do |c|
        rows << "SC00#{c[:cnum].ljust(15)}#{c[:gdesc].ljust(40)}#{c[:csize].ljust(7)}#{c[:weight].to_s.rjust(12,'0')}#{c[:quantity].to_s.rjust(12,'0')}#{c[:uom].ljust(6)}#{"".ljust(145)}#{c[:seal].ljust(15)}#{''.ljust(15)}#{c[:fcl_lcl].ljust(1)}#{"".ljust(11)}#{c[:cdesc].ljust(40)}#{c[:teus].to_s.rjust(4,'0')}"
      end
      rows.join("\n")
    }
    @est = ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
    @split_string = "\n "

    # Because there's no public concept of unstubbing in rspec, this stub is primarily a hack to avoid 
    # introducing a new context around the existing classes to be able to stub this call for those, 
    # and then a secondary context to allow us to make and expectation on the call the verify it's called.
    # Any test that wants to verify broadcast event was called should just check the @event_type variable.
    allow_any_instance_of(Entry).to receive(:broadcast_event) do |instance, event_type|
      @event_type = event_type
    end
  end
  it 'should clear dates that have previously been written but are not retransmitted' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    expect(ent.release_date).not_to be_nil #this one won't be in the file the 2nd time
    expect(ent.first_release_date).not_to be_nil #this one will be reprocesed
    ent.update_attributes(:last_exported_from_source=>nil)

    @release_date_str = nil
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    expect(ent.release_date).to be_nil
    expect(ent.first_release_date).not_to be_nil 
  end
  it 'should set 7501 print dates' do
    first_7501 = '201104211627'
    last_7501 = '201104221217'
    @comments << {:text=>"Document Image created for F7501F   7501 Form.              ",:date=>first_7501,:user=>'BDEVITO'}
    @comments << {:text=>"Document Image created for F7501F   7501 Form.              ",:date=>last_7501,:user=>'BDEVITO'}
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    expect(ent.first_7501_print).to eq(@est.parse(first_7501))
    expect(ent.last_7501_print).to eq(@est.parse(last_7501))
  end
  context "containers" do
    it 'should aggregate containers at header' do
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
      ent = Entry.find_by_broker_reference @ref_num
      expected_containers = @containers.collect {|c| c[:cnum]}
      expected_sizes = @containers.collect {|c| "#{c[:csize]}-#{c[:cdesc]}"}
      expect(ent.container_numbers.split(@split_string)).to eq(expected_containers)
      expect(ent.container_sizes.split(@split_string)).to eq(expected_sizes)
    end
    it 'should set fcl_lcl to mixed if different flags on different containers' do
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
      ent = Entry.find_by_broker_reference @ref_num
      expect(ent.fcl_lcl).to eq('Mixed')
    end
    it 'should set fcl_lcl to lcl if "L" on all containers' do
      @containers.each {|c| c[:fcl_lcl] = "L"}
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
      ent = Entry.find_by_broker_reference @ref_num
      expect(ent.fcl_lcl).to eq('LCL')
    end
    it 'should set fcl_lcl to fcl if "F" on all containers' do
      @containers.each {|c| c[:fcl_lcl] = "F"}
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
      ent = Entry.find_by_broker_reference @ref_num
      expect(ent.fcl_lcl).to eq('FCL')
    end
    it 'should set fcl_lcl to FCL even if only one container has value' do
      @containers.each {|c| c[:fcl_lcl] = ""}
      @containers.first[:fcl_lcl] = "F"
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
      ent = Entry.find_by_broker_reference @ref_num
      expect(ent.fcl_lcl).to eq('FCL')
    end
    it 'should set fcl_lcl to nil if no values' do
      @containers.each {|c| c[:fcl_lcl] = ""}
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
      ent = Entry.find_by_broker_reference @ref_num
      expect(ent.fcl_lcl).to be_nil
    end
    it "should create container records" do
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
      ent = Entry.find_by_broker_reference @ref_num
      conts = ent.containers
      expect(conts.count).to eq @containers.size
      expect(conts.collect {|c| c.container_number}).to eq @containers.collect {|c| c[:cnum]}
      expect(conts.collect {|c| c.container_size}).to eq @containers.collect {|c| c[:csize]}
      expect(conts.collect {|c| c.size_description}).to eq @containers.collect {|c| c[:cdesc]}
      expect(conts.collect {|c| c.weight}).to eq @containers.collect {|c| c[:weight]}
      expect(conts.collect {|c| c.quantity}).to eq @containers.collect {|c| c[:quantity]}
      expect(conts.collect {|c| c.uom}).to eq @containers.collect {|c| c[:uom]}
      expect(conts.collect {|c| c.goods_description}).to eq @containers.collect {|c| c[:gdesc]}
      expect(conts.collect {|c| c.teus}).to eq @containers.collect {|c| c[:teus]}
      expect(conts.collect {|c| c.fcl_lcl}).to eq @containers.collect {|c| c[:fcl_lcl]}
      expect(conts.collect {|c| c.seal_number}).to eq @containers.collect {|c| c[:seal]}
    end
    it "should not create duplicate container records" do
      2.times {OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"}
      ent = Entry.find_by_broker_reference @ref_num
      conts = ent.containers
      expect(conts.count).to eq @containers.size

    end
    it "should clear removed container" do
      bad_cnum = @containers.first[:cnum]
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
      expect(Entry.first.containers.find_by_container_number(bad_cnum)).to_not be_nil 
      @containers.first[:cnum] = 'newcnum'
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_containers_lambda.call}"
      expect(Entry.first.containers.find_by_container_number(bad_cnum)).to be_nil
    end
  end

  it 'should match importer id if customer matches' do
    company = Factory(:company,:importer=>true,:alliance_customer_number=>@cust_num)
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    ent = Entry.find_by_broker_reference @ref_num
    expect(ent.importer).to eq(company)
  end
  it 'should create importer if customer number does not match' do
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    ent = Entry.find_by_broker_reference @ref_num
    company = Company.find_by_alliance_customer_number @cust_num
    expect(company).to be_importer
    expect(company.name).to eq(@customer_name)
    expect(ent.importer).to eq(company)
  end
  
  it "should write bucket_name & key" do
    OpenChain::AllianceParser.parse @make_entry_lambda.call, {:bucket=>'a',:key=>'b'}
    ent = Entry.find_by_broker_reference @ref_num
    expect(ent.last_file_bucket).to eq('a')
    expect(ent.last_file_path).to eq('b')
  end

  it 'should create entry' do
    expect(Lock).to receive(:acquire).with(Lock::ALLIANCE_PARSER, times: 3).and_yield
    expect(Lock).to receive(:with_lock_retry).with(instance_of(Entry)).and_yield
    sql_proxy = double("OpenChain::KewillSqlProxyClient")
    expect(OpenChain::KewillSqlProxyClient).to receive(:delay).and_return sql_proxy
    expect(sql_proxy).to receive(:request_alliance_entry_details).with @ref_num, @est.parse(@extract_date_str)

    file_content = "#{@make_entry_lambda.call}\n#{@make_commercial_invoices_lambda.call}"
    OpenChain::AllianceParser.parse file_content
    ent = Entry.find_by_broker_reference @ref_num
    expect(ent.import_country).to eq(Country.find_by_iso_code('US'))
    expect(ent.source_system).to eq('Alliance')
    expect(ent.entry_number).to eq("#{@filer_code}#{@entry_ext}")
    expect(ent.customer_number).to eq(@cust_num)
    expect(ent.last_exported_from_source).to eq(@est.parse(@extract_date_str))
    expect(ent.company_number).to eq(@company_number)
    expect(ent.division_number).to eq(@division)
    expect(ent.customer_name).to eq(@customer_name)
    expect(ent.entry_type).to eq(@entry_type)
    expect(ent.arrival_date).to eq(@est.parse(@arrival_date_str))
    expect(ent.entry_filed_date).to eq(@est.parse(@entry_filed_date_str))
    expect(ent.release_date).to eq(@est.parse(@release_date_str))
    expect(ent.file_logged_date).to eq(@est.parse(@file_logged_date_str))
    expect(ent.first_release_date).to eq(@est.parse(@first_release_date_str))
    expect(ent.free_date).to eq(@est.parse(@free_date_str))
    expect(ent.last_billed_date).to eq(@est.parse(@last_billed_date_str))
    expect(ent.invoice_paid_date).to eq(@est.parse(@invoice_paid_date_str))
    expect(ent.liquidation_date).to eq(@est.parse(@liquidation_date_str))
    expect(ent.fda_release_date).to eq(@est.parse(@fda_release_str))
    expect(ent.fda_review_date).to eq(@est.parse(@fda_review_str))
    expect(ent.fda_transmit_date).to eq(@est.parse(@fda_transmit_str))
    expect(ent.first_entry_sent_date).to eq(@est.parse(@first_entry_sent_str))
    expect(ent.docs_received_date.strftime("%Y%m%d")).to eq(@docs_rec_str)
    expect(ent.release_cert_message).to eq(@release_cert_message)
    ent.fda_message == @fda_message
    expect(ent.duty_due_date.strftime("%Y%m%d")).to eq(@duty_due_date_str)
    expect(ent.export_date.strftime("%Y%m%d")).to eq(@export_date_str[0,8])
    expect(ent.carrier_code).to eq(@carrier_code)
    expect(ent.total_packages).to eq(@total_packages)
    expect(ent.total_packages_uom).to eq(@total_packages_uom)
    expect(ent.total_fees).to eq(@total_fees)
    expect(ent.total_duty).to eq(@total_duty)
    expect(ent.total_duty_direct).to eq(@total_duty_direct)
    expect(ent.entered_value).to eq(@entered_value)
    expect(ent.customer_references).to eq(@customer_references) #make sure cust refs in sample data don't overlap with line level PO number or they'll be excluded on purpose
    expect(ent.merchandise_description).to eq(@merchandise_description)
    expect(ent.transport_mode_code).to eq(@transport_mode_code)
    expect(ent.entry_port_code).to eq(@entry_port_code)
    expect(ent.lading_port_code).to eq(@lading_port_code)
    expect(ent.unlading_port_code).to eq(@unlading_port_code)
    expect(ent.ult_consignee_code).to eq(@ult_consignee_code)
    expect(ent.ult_consignee_name).to eq(@ult_consignee_name)
    ent.consignee_address_1 == @consignee_address_1
    ent.consignee_address_2 == @consignee_address_2
    ent.consignee_city == @consignee_city
    ent.consignee_state == @consignee_state
    expect(ent.gross_weight).to eq(@gross_weight)
    expect(ent.cotton_fee).to eq(@cotton_fee)
    expect(ent.hmf).to eq(@hmf)
    expect(ent.mpf).to eq(@mpf)
    expect(ent.vessel).to eq(@vessel)
    expect(ent.voyage).to eq(@voyage)
    expect(ent).to be_paperless_release
    expect(ent).to be_census_warning
    expect(ent).to be_error_free_release
    expect(ent).to be_paperless_certification
    expect(ent.destination_state).to eq(@destination_state)
    expect(ent.liquidation_type_code).to eq(@liq_type_code)
    expect(ent.liquidation_type).to eq(@liq_type)
    expect(ent.liquidation_action_code).to eq(@liq_action_code)
    expect(ent.liquidation_action_description).to eq(@liq_action)
    expect(ent.liquidation_extension_code).to eq(@liq_ext_code)
    expect(ent.liquidation_extension_description).to eq(@liq_ext)
    expect(ent.liquidation_extension_count).to eq(@liq_ext_ct)
    expect(ent.liquidation_duty).to eq(@liq_duty)
    expect(ent.liquidation_fees).to eq(@liq_fees)
    expect(ent.liquidation_tax).to eq(@liq_tax)
    expect(ent.liquidation_ada).to eq(@liq_ada)
    expect(ent.liquidation_cvd).to eq(@liq_cvd)
    expect(ent.liquidation_total).to eq(@liq_duty+@liq_fees+@liq_tax+@liq_ada+@liq_cvd)
    expect(ent.daily_statement_number).to eq(@daily_stmt_number)
    expect(ent.daily_statement_due_date.strftime("%Y%m%d")).to eq(@daily_stmt_due_str)
    expect(ent.daily_statement_approved_date.strftime("%Y%m%d")).to eq(@daily_stmt_approved_str)
    expect(ent.monthly_statement_due_date.strftime("%Y%m%d")).to eq(@monthly_stmt_due_str)
    expect(ent.monthly_statement_received_date.strftime("%Y%m%d")).to eq(@monthly_stmt_received_str)
    expect(ent.monthly_statement_paid_date.strftime("%Y%m%d")).to eq(@monthly_stmt_paid_str)
    expect(ent.monthly_statement_number).to eq(@monthly_stmt_number)
    expect(ent.eta_date.strftime("%Y%m%d")).to eq(@eta_date_str[0, 8])
    expect(ent.freight_pickup_date).to eq(@est.parse(@freight_pickup_str))
    expect(ent.delivery_order_pickup_date).to eq(@est.parse(@delivery_order_pickup_str))
    expect(ent.worksheet_date).to eq(@est.parse(@worksheet_date_str))
    expect(ent.available_date).to eq(@est.parse(@available_date_str))
    expect(ent.store_names).to eq "Store1\n Store2"

    expect(ent.mfids.split(@split_string)).to eq(Set.new(@commercial_invoices.collect {|ci| ci[:mfid]}).to_a)
    expect(ent.location_of_goods).to eq @location_of_goods
    expect(ent.bond_type).to eq @bond_type

    expected_invoiced_value = BigDecimal("0",2)
    expected_export_country_codes = Set.new
    expected_origin_country_codes = Set.new
    expected_vendor_names = Set.new
    expected_total_units_uoms = Set.new
    expected_spis = Set.new
    expected_pos = Set.new 
    expected_parts = Set.new
    expected_total_units = BigDecimal("0",2)
    expected_inv_numbers = Set.new
    expected_departments = Set.new
    
    total_cvd = 0
    total_add = 0

    @commercial_invoices.each do |ci| 
      invoices = ent.commercial_invoices.where(:invoice_number=>ci[:invoice_number])
      expect(invoices.size).to eq(1)
      inv = invoices.first
      expected_invoiced_value += ci[:invoiced_value]
      expected_inv_numbers << ci[:invoice_number]
      ci[:lines].each do |line|
        expected_export_country_codes << line[:export_country_code]
        expected_origin_country_codes << line[:origin_country_code]
        expected_vendor_names << line[:vendor_name]
        expected_total_units_uoms << line[:units_uom]
        expected_total_units += line[:units]
        expected_pos << line[:po_number] unless line[:po_number].blank?
        expected_parts << line[:part_number] unless line[:part_number].blank?
        expected_departments << line[:department] unless line[:department].blank?

        ci_line = inv.commercial_invoice_lines.where(:part_number=>line[:part_number]).first
        expect(ci_line.mid).to eq(line[:mid])
        expect(ci_line.po_number).to eq(line[:po_number])
        expect(ci_line.quantity).to eq(line[:units])
        expect(ci_line.unit_of_measure).to eq(line[:units_uom])
        expect(ci_line.value).to eq(line[:value]) unless line[:value].nil?
        expect(ci_line.mid).to eq(line[:mid])
        expect(ci_line.country_origin_code).to eq(line[:origin_country_code])
        expect(ci_line.charges).to eq(line[:total_charges])
        expect(ci_line.country_export_code).to eq(line[:export_country_code])
        expect(ci_line.related_parties?).to eq(line[:related_parties] ? line[:related_parties] : false)
        expect(ci_line.vendor_name).to eq(line[:vendor_name])
        expect(ci_line.volume).to eq(line[:volume]) if line[:volume]
        expect(ci_line.computed_value).to eq(line[:computed_value]) if line[:computed_value]
        expect(ci_line.computed_adjustments).to eq(line[:computed_adjustments]) if line[:computed_adjustments]
        expect(ci_line.computed_net_value).to eq(line[:computed_net_value]) if line[:computed_net_value]
        expect(ci_line.mpf).to eq(line[:mpf] ? line[:mpf] : 0)
        expect(ci_line.hmf).to eq(line[:hmf])
        if line[:prorated_mpf]
          expect(ci_line.prorated_mpf).to eq(line[:prorated_mpf])
        else
          expect(ci_line.prorated_mpf).to eq(line[:mpf] ? line[:mpf] : 0)
        end
        expect(ci_line.department).to eq(line[:department])
        expect(ci_line.cotton_fee).to eq(line[:cotton_fee])
        expect((ci_line.unit_price*100).to_i).to eq(( (ci_line.value / ci_line.quantity) * 100 ).to_i) if ci_line.unit_price && ci_line.quantity
        expect(ci_line.line_number).to eq(line[:line_number].to_i / 10)
        if line[:contract_amount].blank?
          expect(ci_line.contract_amount).to eq(BigDecimal('0'))
        else
          expect(ci_line.contract_amount).to eq(line[:contract_amount])
        end

        expect(ci_line.product_line).to eq line[:product_line].to_s
        expect(ci_line.store_name).to eq line[:store_name].to_s

        if line[:tariff]
          line[:tariff].each do |t_line|
            found = ci_line.commercial_invoice_tariffs.where(:hts_code=>t_line[:hts_code])
            expect(found.record.size).to eq(1)
            t = found.first
            expect(t.duty_amount).to eq(t_line[:duty_total])
            expect(t.entered_value).to eq(t_line[:entered_value])
            expect(t.duty_rate).to eq(( t_line[:duty_total]/t_line[:entered_value] ).round(3))
            expect(t.spi_primary).to eq(t_line[:spi_primary])
            expect(t.spi_secondary).to eq(t_line[:spi_secondary])
            expect(t.hts_code).to eq(t_line[:hts_code])
            expect(t.classification_qty_1).to eq(t_line[:class_q_1])
            expect(t.classification_qty_2).to eq(t_line[:class_q_2])
            expect(t.classification_qty_3).to eq(t_line[:class_q_3])
            expect(t.classification_uom_1).to eq(t_line[:class_uom_1])
            expect(t.classification_uom_2).to eq(t_line[:class_uom_2])
            expect(t.classification_uom_3).to eq(t_line[:class_uom_3])
            expect(t.tariff_description).to eq(t_line[:tariff_description])
            expect(t.gross_weight.to_s).to eq(t_line[:gross_weight])
            [:spi_primary,:spi_secondary].each {|k| expected_spis << t_line[k] unless t_line[k].blank?}
          end
        end

        if line[:add]
          add = line[:add]
          
          expect(ci_line.add_case_number).to eq(add[:case_number])
          expect(ci_line.add_bond).to eq(add[:bond] == "Y")
          expect(ci_line.add_duty_amount).to eq(add[:amount])
          total_add += add[:amount]
          expect(ci_line.add_case_value).to eq(add[:value])
          expect(ci_line.add_case_percent).to eq(add[:percent])
        end

        if line[:cvd]
          cvd = line[:cvd]
          
          expect(ci_line.cvd_case_number).to eq(cvd[:case_number])
          expect(ci_line.cvd_bond).to eq(cvd[:bond] == "Y")
          expect(ci_line.cvd_duty_amount).to eq(cvd[:amount])
          total_cvd += cvd[:amount]
          expect(ci_line.cvd_case_value).to eq(cvd[:value])
          expect(ci_line.cvd_case_percent).to eq(cvd[:percent])
        end

      end
      expect(inv.currency).to eq(ci[:currency])
      expect(inv.exchange_rate).to eq(ci[:exchange_rate])
      expect(inv.invoice_value_foreign).to eq(ci[:invoice_value_foreign])
      expect(inv.invoice_value).to eq(ci[:invoiced_value])
      expect(inv.country_origin_code).to eq(ci[:country_origin_code])
      expect(inv.total_charges).to eq(ci[:total_charges])
      expect(inv.gross_weight).to eq(ci[:gross_weight].to_i)
      expect(inv.invoice_date.strftime("%Y%m%d")).to eq(ci[:invoice_date])
      expect(inv.mfid).to eq(ci[:mfid])
      expect(inv.total_quantity).to eq(BigDecimal.new(ci[:total_quantity]))
      expect(inv.total_quantity_uom).to eq(ci[:total_quantity_uom])
    end

    expect(ent.total_invoiced_value).to eq(expected_invoiced_value)
    expect(ent.export_country_codes.split(@split_string)).to eq(expected_export_country_codes.to_a)
    expect(ent.origin_country_codes.split(@split_string)).to eq(expected_origin_country_codes.to_a)
    expect(ent.vendor_names.split(@split_string)).to eq(expected_vendor_names.to_a)
    expect(ent.total_units).to eq(expected_total_units)
    expect(ent.total_units_uoms.split(@split_string)).to eq(expected_total_units_uoms.to_a)
    expect(ent.po_numbers.split(@split_string)).to eq(expected_pos.to_a)
    expect(ent.part_numbers.split(@split_string)).to eq(expected_parts.to_a)
    expect(ent.special_program_indicators.split(@split_string)).to eq(expected_spis.to_a)
    expect(ent.commercial_invoice_numbers.split(@split_string)).to eq(expected_inv_numbers.to_a)
    expect(ent.departments.split(@split_string)).to eq(expected_departments.to_a)
    expect(ent.total_cvd).to eq(total_cvd) 
    expect(ent.total_add).to eq(total_add)

    expect(ent.time_to_process).to be < 1000 
    expect(ent.time_to_process).to be > 0

    expect(@event_type).to eq(:save)
  end

  it "should write a comment" do
    expect(@comments.size).to eq(1)
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    comments = Entry.find_by_broker_reference(@ref_num).entry_comments
    expect(comments.size).to eq(1)
    comm = comments.first
    expect(comm.username).to eq(@comments.first[:user])
    expect(comm.body).to eq(@comments.first[:text])
    expect(comm.generated_at).to eq(@est.parse(@comments.first[:date]))
  end

  it 'code 00098 should override 00003 if it comes second in file' do
    @docs_rec2_str = "20120613"
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    expect(Entry.find_by_broker_reference(@ref_num).docs_received_date.strftime("%Y%m%d")).to eq(@docs_rec2_str)
  end

  it 'should set paperless release to false if empty' do
    @paperless = ' '
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    expect(Entry.find_by_broker_reference(@ref_num).paperless_release).to eq(false)
  end

  it 'should set census warning to false if empty' do
    @census_warning = ' '
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    expect(Entry.find_by_broker_reference(@ref_num).census_warning).to eq(false)
  end

  it 'should set error_free_release to false if empty' do
    @error_free = ' '
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    expect(Entry.find_by_broker_reference(@ref_num).error_free_release).to eq(false)
  end

  it 'should set paperless_certification to false if empty' do
    @paperless_cert = ' '
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    expect(Entry.find_by_broker_reference(@ref_num).paperless_certification).to eq(false)
  end

  it 'should only update entries with Alliance as source' do
    old_ent = Factory(:entry,:broker_reference=>@ref_num) #doesn't have matching source system
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    entries = Entry.where(:broker_reference=>@ref_num)
    expect(entries.size).to eq(2)
  end

  it 'should not duplicate commercial invoices when reprocessing' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_commercial_invoices_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    expect(ent.commercial_invoices.size).to eq(@commercial_invoices.size)
    #do it twice
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_commercial_invoices_lambda.call}"
    ent = Entry.find_by_broker_reference @ref_num
    expect(ent.commercial_invoices.size).to eq(@commercial_invoices.size)
  end

  context 'recon flags' do
    it 'should expand nafta' do
      @recon = 'BNNN'
      OpenChain::AllianceParser.parse @make_entry_lambda.call
      expect(Entry.find_by_broker_reference(@ref_num).recon_flags).to eq("NAFTA")
    end
    it 'should expand value' do
      @recon = 'NBNN'
      OpenChain::AllianceParser.parse @make_entry_lambda.call
      expect(Entry.find_by_broker_reference(@ref_num).recon_flags).to eq("VALUE")
    end
    it 'should expand class' do
      @recon = 'NNBN'
      OpenChain::AllianceParser.parse @make_entry_lambda.call
      expect(Entry.find_by_broker_reference(@ref_num).recon_flags).to eq("CLASS")
    end
    it 'should expand 9802' do
      @recon = 'NNNB'
      OpenChain::AllianceParser.parse @make_entry_lambda.call
      expect(Entry.find_by_broker_reference(@ref_num).recon_flags).to eq("9802")
    end
    it 'should combine flags' do
      @recon = 'BBBB'
      OpenChain::AllianceParser.parse @make_entry_lambda.call
      expect(Entry.find_by_broker_reference(@ref_num).recon_flags).to eq("NAFTA\n VALUE\n CLASS\n 9802")
    end
  end

  it 'should make all zero port codes nil' do
    @lading_port_code = '00000'
    @unlading_port_code = '0000'
    @entry_port_code = '0000'
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    ent = Entry.find_by_broker_reference @ref_num
    expect(ent.lading_port_code).to be_nil
    expect(ent.unlading_port_code).to be_nil
    expect(ent.entry_port_code).to be_nil
  end
  context 'reference fields' do
    it 'should remove po numbers from cust ref' do
      @customer_references = "a\nb\nc"
      @commercial_invoices.first[:lines].first[:po_number] = "b"
      OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_commercial_invoices_lambda.call}"
      expect(Entry.find_by_broker_reference(@ref_num).customer_references).to eq("a\n c")
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
      expect(Entry.find_by_broker_reference(@ref_num).po_numbers.split(@split_string)).to eq(expected_pos.to_a)
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
      expect(ent.customer_references).to eq("a\n b\n c")
      expect(ent.po_numbers).to be_blank
    end
  end
  it 'should handle empty date' do
    @arrival_date_str = '            '
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    ent = Entry.find_by_broker_reference @ref_num
    expect(ent.arrival_date).to be_nil
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
    expect(Entry.count).to eq(2)
    [r1,r2].each {|r| expect(Entry.find_by_broker_reference(r)).not_to be_nil}
  end
  it 'should update entry' do
    file_content = @make_entry_lambda.call
    OpenChain::AllianceParser.parse file_content
    ent = Entry.find_by_broker_reference @ref_num
    expect(ent.customer_number).to eq(@cust_num)
    @cust_num = 'ABC'
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    expect(Entry.count).to eq(1)
    expect(Entry.find(ent.id).customer_number).to eq('ABC')
    expect(@event_type).to eq(:save)
  end
  it 'should not update entry if older than last update' do
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    old_cust_num = @cust_num
    @cust_num = "nochange"
    @extract_date_str = '199901011226'  #make older
    @event_type = nil
    #send file w/ older date & different cust num which should be ignored
    OpenChain::AllianceParser.parse @make_entry_lambda.call
    expect(Entry.count).to eq(1)
    expect(Entry.first.customer_number).to eq(old_cust_num)
    # If we didn't update the entry, an event shouldn't have been broadcast
    expect(@event_type).to be_nil
  end
  it 'should populate entry header tracking fields' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_si_lambda.call}"
    expect(Entry.count).to eq(1)
    ent = Entry.first
    expect(ent.master_bills_of_lading).to eq((@si_lines.collect {|h| h[:mbol]}).join(@split_string))
    expect(ent.house_bills_of_lading).to eq((@si_lines.collect {|h| h[:hbol]}).join(@split_string))
    expect(ent.sub_house_bills_of_lading).to eq((@si_lines.collect {|h| h[:sub]}).join(@split_string))
    expect(ent.it_numbers).to eq((@si_lines.collect {|h| h[:it]}).join(@split_string))
    expect(ent.first_it_date.strftime("%Y%m%d")).to eq('20120603')
  end
  it 'should replace entry header tracking fields' do
    Entry.create(:broker_reference=>@ref_num,:it_numbers=>'12345',:master_bills_of_lading=>'mbols',:house_bills_of_lading=>'bolsh',:sub_house_bills_of_lading=>'shs',:source_system=>OpenChain::AllianceParser::SOURCE_CODE)
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_si_lambda.call}"
    expect(Entry.count).to eq(1)
    ent = Entry.first
    expect(ent.master_bills_of_lading).to eq((@si_lines.collect {|h| h[:mbol]}).join(@split_string))
    expect(ent.house_bills_of_lading).to eq((@si_lines.collect {|h| h[:hbol]}).join(@split_string))
    expect(ent.sub_house_bills_of_lading).to eq((@si_lines.collect {|h| h[:sub]}).join(@split_string))
    expect(ent.it_numbers).to eq((@si_lines.collect {|h| h[:it]}).join(@split_string))
  end
  it 'should create invoice' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    expect(ent.broker_invoices.size).to eq(1)
    inv = ent.broker_invoices.first
    expect(inv.invoice_number).to eq("#{ent.broker_reference}#{@inv_suffix}")
    expect(inv.source_system).to eq('Alliance')
    expect(inv.broker_reference).to eq(ent.broker_reference)
    expect(inv.currency).to eq("USD") #default
    expect(inv.suffix).to eq(@inv_suffix)
    expect(inv.invoice_date).to eq(Date.parse(@inv_invoice_date_str))
    expect(inv.invoice_total).to eq(@inv_total)
    expect(inv.customer_number).to eq(@cust_num)
    expect(inv.bill_to_name).to eq(@inv_b_name)
    expect(inv.bill_to_address_1).to eq(@inv_b_add_1)
    expect(inv.bill_to_address_2).to eq(@inv_b_add_2)
    expect(inv.bill_to_city).to eq(@inv_b_city)
    expect(inv.bill_to_zip).to eq(@inv_b_zip)
    expect(inv.bill_to_country).to eq(@country)
  end
  it 'should update invoice' do
    # first invoice
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    expect(ent.broker_invoices.size).to eq(1)
    inv = ent.broker_invoices.first
    expect(inv.suffix).to eq(@inv_suffix)
    expect(inv.invoice_total).to eq(@inv_total)

    #second invoice (update)
    @inv_total = BigDecimal("99.09",2)
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    expect(ent.broker_invoices.size).to eq(1)
    inv = ent.broker_invoices.first
    expect(inv.suffix).to eq(@inv_suffix)
    expect(inv.invoice_total).to eq(@inv_total)
  end
  it 'should include all charge codes in entry header charge codes field' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    codes_expected = @invoice_lines.collect {|src| src[:code]}
    expect(Entry.first.charge_codes.lines.collect {|x| x.strip}).to eq(codes_expected)
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
    expect(ent.broker_invoices.size).to eq(2)
    expect(ent.broker_invoices.where(:suffix=>'01').size).to eq(1)
    expect(ent.broker_invoices.where(:suffix=>'02').size).to eq(1)
    expect(ent.broker_invoice_total).to eq(BigDecimal("30.00"))
  end
  it 'should create invoice lines' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    expect(ent.broker_invoices.size).to eq(1)
    inv = ent.broker_invoices.first
    lines = inv.broker_invoice_lines
    expect(lines.size).to eq(@invoice_lines.size)
    @invoice_lines.each do |src|
      line = inv.broker_invoice_lines.where(:charge_code=>src[:code]).first
      expect(line.charge_description).to eq(src[:desc])
      expect(line.charge_amount).to eq(src[:amt])
      expect(line.vendor_name).to eq(src[:v_name])
      expect(line.vendor_reference).to eq(src[:v_ref])
      expect(line.charge_type).to eq(src[:type])
    end
  end
  it 'should rebuild invoice lines on invoice update' do
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    @invoice_lines.each {|src| src[:desc] = "newdesc"}
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    expect(ent.broker_invoices.size).to eq(1)
    inv = ent.broker_invoices.first
    lines = inv.broker_invoice_lines
    expect(lines.size).to eq(@invoice_lines.size)
    @invoice_lines.each do |src|
      line = inv.broker_invoice_lines.where(:charge_code=>src[:code]).first
      expect(line.charge_description).to eq(src[:desc])
      expect(line.charge_amount).to eq(src[:amt])
      expect(line.vendor_name).to eq(src[:v_name])
      expect(line.vendor_reference).to eq(src[:v_ref])
      expect(line.charge_type).to eq(src[:type])
    end
  end

  it 'should handle times with a value of 60 minutes' do
    # Stupid alliance bug we're working around, only seems to appear in comments lines
    @comments[0][:date] = "201305152260"

    OpenChain::AllianceParser.parse @make_entry_lambda.call
    comments = Entry.find_by_broker_reference(@ref_num).entry_comments
    expect(comments.size).to eq(1)
    comment = comments.first
    expect(comment.generated_at).to eq(ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse("201305152300"))
  end

  it 'sets charge description to "NO DESCRIPTION" if blank' do
    @invoice_lines[0][:desc] = ""
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}"
    ent = Entry.first
    expect(ent.broker_invoices.first.broker_invoice_lines.first.charge_description).to eq "NO DESCRIPTION"
  end

  class MutatingInstanceOf < RSpec::Mocks::ArgumentMatchers::InstanceOf

    def ==(actual)
      actual.instance_of?(@klass)
      actual.last_exported_from_source = Time.now
    end
  end

  it "checks for stale data after the with_lock_retry call" do
    entry = Entry.new last_exported_from_source: Time.now
    expect(Lock).to receive(:with_lock_retry).with(MutatingInstanceOf.new(Entry)).and_yield

    expect(OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}\n#{@make_invoice_lambda.call}").to be_falsey
  end

  it "handles bad data" do
    expect(OpenChain::AllianceParser.parse "bjsdfjsdfjkbashjkfsdj\ansdfasdjksd\nsdjfhasjkdfsa\sndfjshd").to be_falsey
  end

  it "does not update entry filed date" do
    e = Entry.create(:broker_reference=>@ref_num, :source_system=>OpenChain::AllianceParser::SOURCE_CODE, entry_filed_date: Time.zone.now)
    OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}"
    expect(e.entry_filed_date.to_i).to eq e.reload.entry_filed_date.to_i
  end

  it "skips purged entries" do
    EntryPurge.create! broker_reference: @ref_num, source_system: OpenChain::AllianceParser::SOURCE_CODE, date_purged: Time.zone.parse("2010-03-01 00:00")
    expect(OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}").to be_falsey
    expect(Entry.where(broker_reference: @ref_num, source_system: OpenChain::AllianceParser::SOURCE_CODE).first).to be_nil
  end

  it "makes new entries for file numbers purged in the past" do
    EntryPurge.create! broker_reference: @ref_num, source_system: OpenChain::AllianceParser::SOURCE_CODE, date_purged: Time.zone.parse("2010-01-01 00:00")
    expect(OpenChain::AllianceParser.parse "#{@make_entry_lambda.call}").to be_truthy
    expect(Entry.where(broker_reference: @ref_num, source_system: OpenChain::AllianceParser::SOURCE_CODE).first).not_to be_nil
  end

  describe 'process_past_days' do
    it "should delay processing" do
      expect(OpenChain::AllianceParser).to receive(:delay).exactly(3).times.and_return(OpenChain::AllianceParser)
      expect(OpenChain::AllianceParser).to receive(:process_day).exactly(3).times
      OpenChain::AllianceParser.process_past_days 3
    end
  end
  describe 'process_day' do
    it 'should process all files from the given day' do
      d = Date.new
      expect(OpenChain::S3).to receive(:integration_keys).with(d,["//opt/wftpserver/ftproot/www-vfitrack-net/_alliance", "/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_alliance"]).and_yield("a").and_yield("b")
      expect(OpenChain::S3).to receive(:get_data).with(OpenChain::S3.integration_bucket_name,"a").and_return("x")
      expect(OpenChain::S3).to receive(:get_data).with(OpenChain::S3.integration_bucket_name,"b").and_return("y")
      expect(OpenChain::AllianceParser).to receive(:parse).with("x",{:bucket=>OpenChain::S3.integration_bucket_name,:key=>"a",:imaging=>false})
      expect(OpenChain::AllianceParser).to receive(:parse).with("y",{:bucket=>OpenChain::S3.integration_bucket_name,:key=>"b",:imaging=>false})
      OpenChain::AllianceParser.process_day d
    end
  end
  describe "process_alliance_query_details" do

    before :each do
      # Every test in here can assume there will be an entry in the system already, since there's really
      # no other way for this process to be kicked off.
      t = Factory(:commercial_invoice_tariff, hts_code: "123",
        commercial_invoice_line: Factory(:commercial_invoice_line, line_number: 1,
          commercial_invoice: Factory(:commercial_invoice, invoice_number: "INV 1", entry: Factory(:entry, broker_reference: "Reference", source_system: "Alliance", last_exported_from_source: Time.zone.now))
        )
      )
      t2 = Factory(:commercial_invoice_tariff, hts_code: "456", commercial_invoice_line: t.commercial_invoice_line)
      t3 = Factory(:commercial_invoice_tariff, hts_code: "789",
        commercial_invoice_line: Factory(:commercial_invoice_line, line_number: 2,
          commercial_invoice: t2.commercial_invoice_line.commercial_invoice
        )
      )

      t4 = Factory(:commercial_invoice_tariff, hts_code: "987",
        commercial_invoice_line: Factory(:commercial_invoice_line, line_number: 2,
          commercial_invoice: Factory(:commercial_invoice, invoice_number: "INV 2", entry: t.commercial_invoice_line.entry)
        )
      )

      @entry = t4.commercial_invoice_line.entry

      # Normally, we'd not end up missing information for certain lines, but I'm just doing it here to make sure that the 
      # correct lines are getting discovered in the code to be updated.
      @query_context = {'broker_reference' => @entry.broker_reference, 'last_exported_from_source'=> @entry.last_exported_from_source.to_json}
      # All of the values need to be sent over as strings, otherwise, the json'ization of the result set sends them as float values which causes issues w/ dates and expected int values.
      @query_results = [
        {'final statement date'=>"20140501", 'invoice number'=>'INV 1      ',  'line number'=>"10", 'customs line number'=>"1", 'visa no'=>'123', 'visa qty'=>"1", 'visa uom'=>'UOM', 'tariff line no'=>"1", 'tariff no'=>"123", 'category'=>'123'},
        {'final statement date'=>"20140501", 'invoice number'=>'INV 2      ',  'line number'=>"20", 'customs line number'=>"2", 'visa no'=>'987', 'visa qty'=>"6", 'visa uom'=>'MOU', 'tariff line no'=>"1", 'tariff no'=>"987", 'category'=>'987'},
      ]
    end

    it "parses query results from SQL Proxy and updates the line information for each line" do
      expect_any_instance_of(Entry).to receive(:broadcast_event).with :save

      OpenChain::AllianceParser.process_alliance_query_details @query_results, @query_context

      @entry.reload
      expect(@entry.final_statement_date).to eq Date.new(2014, 5, 1)
      l = @entry.commercial_invoices.first.commercial_invoice_lines.first

      expect(l.customs_line_number).to eq 1
      expect(l.visa_number).to eq '123'
      expect(l.visa_quantity).to eq BigDecimal.new(1)
      expect(l.visa_uom).to eq "UOM"

      t = l.commercial_invoice_tariffs.first
      expect(t.quota_category).to eq 123

      l = @entry.commercial_invoices.second.commercial_invoice_lines.first
      expect(l.customs_line_number).to eq 2
      expect(l.visa_number).to eq '987'
      expect(l.visa_quantity).to eq BigDecimal.new(6)
      expect(l.visa_uom).to eq "MOU"

      t = l.commercial_invoice_tariffs.first
      expect(t.quota_category).to eq 987
    end

    it "handles blank data in query results by setting columns to nil" do
      # Blank dates in alliance end up being represented by 0
      query_results = [
        {'final statement date'=>"0", 'invoice number'=>'INV 1',  'line number'=>"10", 'customs line number'=>"0", 'visa no'=>'', 'visa qty'=>"0", 'visa uom'=>'      ', 'tariff line no'=>"1", 'tariff no'=>"123", 'category'=>''}
      ]

      @entry.update_attributes! final_statement_date: Date.new(2014,5,1)
      @entry.commercial_invoices.first.commercial_invoice_lines.first.update_attributes! customs_line_number: 3, visa_number: 'abc', visa_quantity: 10, visa_uom: 'UOM'
      @entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.first.update_attributes! quota_category: 'ABC'
      OpenChain::AllianceParser.process_alliance_query_details query_results, @query_context

      @entry.reload

      expect(@entry.final_statement_date).to be_nil
      l = @entry.commercial_invoices.first.commercial_invoice_lines.first

      expect(l.customs_line_number).to be_nil
      expect(l.visa_number).to be_nil
      expect(l.visa_quantity).to be_nil
      expect(l.visa_uom).to be_nil

      t = l.commercial_invoice_tariffs.first
      expect(t.quota_category).to be_nil
    end

    it "updates tariff level fields by tariff line number when multiple lines have the same hts code" do
      t1 = @entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.first
      @entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.second.update_attributes! hts_code: t1.hts_code
      @query_results.first['tariff line no'] = 2

      OpenChain::AllianceParser.process_alliance_query_details @query_results, @query_context
      @entry.reload

      t = @entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.second
      expect(t.quota_category).to eq 123
    end

    it "does nothing if query details are outdated" do
      @query_context['last_exported_from_source'] = (@entry.last_exported_from_source - 1.day).to_json
      updated = @entry.updated_at

      OpenChain::AllianceParser.process_alliance_query_details @query_results, @query_context

      @entry.reload
      expect(@entry.updated_at).to eq updated
    end

    it "handles unmarshalling json results/context data" do
      OpenChain::AllianceParser.process_alliance_query_details @query_results.to_json, @query_context.to_json
      @entry.reload
      # Just check the entry and make sure it's updated, that's enough of a check to make sure the json data was unmarshalled
      expect(@entry.final_statement_date).to eq Date.new(2014, 5, 1)
    end

    it "handles results with nothing in them" do
      updated = @entry.updated_at
      OpenChain::AllianceParser.process_alliance_query_details [], @query_context
      @entry.reload
      expect(@entry.updated_at).to eq updated
    end

  end
end
