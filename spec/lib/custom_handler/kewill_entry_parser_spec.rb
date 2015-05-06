require 'spec_helper'

describe OpenChain::CustomHandler::KewillEntryParser do

  def tz
    ActiveSupport::TimeZone["Eastern Time (US & Canada)"]
  end

  describe "process_entry" do

    before :each do
      us = Factory(:country, iso_code: "US")
      pms_dates = {
        3 => 15
      }

      KeyJsonItem.usc_periodic_dates(2015).create! json_data: pms_dates.to_json

      @e = {
        'cust_no' => 'TEST',
        'file_no' => 12345,
        'entry_no' => '316123456',
        'cr_certification_output_mess' => 'CERT MESSAGE',
        'fda_output_mess' => 'FDA MESSAGE',
        'updated_at' => 201502120600,
        'extract_time' => '2015-03-12T13:26:20-04:00',
        'cust_name' => "CUST NAME",
        'desc_of_goods' => "Goods Desc",
        'port_entry' => 12345,
        'port_lading' => 23456,
        'port_unlading' => 1234,
        'destination_state' => "PA",
        'entry_type' => 1,
        'voyage_flight_no' => "Voyage",
        'uc_no' => "UCNO",
        'uc_name' => "UC Name",
        'uc_address_1' => "123 Fake St.",
        'uc_address_2' => "STE 123",
        'uc_state' => "PA",
        'uc_city' => "Fakesville",
        'mot' => 10,
        'carrier' => "Carrier",
        'company_no' => 2,
        'division_no' => 9,
        'recon_nafta' => "Y",
        'recon_value' => "Y",
        'recon_class' => "Y",
        'recon_9802' => "Y",
        'fees_tot' => 12345,
        'duty_tot' => 123,
        'duty_paid_direct_amt' => 890,
        'value_entered' => 99999,
        'weight_gross' => 987654,
        'abi_payment_type' => 3,
        'piece_count' => 67,
        'piece_count_uom' => "PCS",
        'hmf_tot' => 111,
        'mpf_tot' => 222,
        'cotton_tot' => 333,
        'statement_no' => "astatement",
        'daily_statement_no' => "bstatement",
        'pms_year' => 2015,
        'pms_month' => 3,
        'type_liquidation' => "liq_type",
        'liquidation_type_desc' => 'liq type desc',
        'action_liquidation' => 'action_liquidation',
        'extend_suspend_liq' => 'extend_suspend_liq',
        'no_extend_suspend_liquidation' => '2',
        'duty_amt_liquidated' => 123.45,
        'fee_amt_liquidated' => 234.56,
        'tax_amt_liquidated' => 345.67,
        'ada_amt_liquidated' => 456.78,
        'cvd_amt_liquidated' => 567.89,
        'dates' => [
          # Note the time ending in 60..stupid Alliance has dates w/ a minute value of 60 rather
          # than incrementing the hour.
          {'date_no'=>1, 'date'=>201503010660},
          {'date_no'=>3, 'date'=>201503010800},
          {'date_no'=>4, 'date'=>201503010900},
          {'date_no'=>9, 'date'=>201503011000},
          # Add 2 IT Dates, since we only want to log the first
          {'date_no'=>9, 'date'=>201503081000},
          {'date_no'=>11, 'date'=>201503011100},
          {'date_no'=>12, 'date'=>201503011200},
          {'date_no'=>16, 'date'=>201503011300},
          {'date_no'=>19, 'date'=>201503011400},
          {'date_no'=>20, 'date'=>201503011500},
          {'date_no'=>24, 'date'=>201503011600},
          {'date_no'=>25, 'date'=>201503011700},
          {'date_no'=>26, 'date'=>201503011800},
          {'date_no'=>28, 'date'=>201503011900},
          {'date_no'=>32, 'date'=>201503012000},
          {'date_no'=>42, 'date'=>201503012100},
          {'date_no'=>48, 'date'=>201503012200},
          {'date_no'=>52, 'date'=>201503012300},
          {'date_no'=>85, 'date'=>201503020000},
          {'date_no'=>108, 'date'=>201503020100},
          {'date_no'=>121, 'date'=>201503020200},
          {'date_no'=>2014, 'date'=>201503020300},
          {'date_no'=>92007, 'date'=>201503020400},
          {'date_no'=>92008, 'date'=>201503020500},
          {'date_no'=>93002, 'date'=>201503020600},
          {'date_no'=>99212, 'date'=>201503020700},
          {'date_no'=>99310, 'date'=>201503020800},
          {'date_no'=>99311, 'date'=>201503020900},
          {'date_no'=>99202, 'date'=>201503021000}
        ],
        'notes' => [
          {'note' => "Document Image created for F7501F   7501 Form.", 'modified_by'=>"User1", 'date_updated' => 201503191930, 'confidential' => "Y"},
          {'note' => "Document Image created for FORM_N7501", 'modified_by'=>"User2", 'date_updated' => 201503201247},
          {'note' => "User3 did something", 'modified_by'=>"User3", 'date_updated' => 201503201247}
        ],
        'ids' => [
          {'scac'=>"XXXX", 'master_bill'=>"MASTER", 'house_bill'=>"HOUSE", 'sub_bill'=>'SUB', 'it_no'=>'ITNO'},
          {'scac'=>"XXXX", 'master_bill'=>"MASTER", 'house_bill'=>"HOUSE", 'sub_bill'=>'SUB', 'it_no'=>'ITNO'}, # Skip the second line, it's duplicate
          {'scac'=>"XXXX", 'master_bill'=>"MASTER2", 'house_bill'=>"HOUSE2", 'sub_bill'=>'SUB2', 'it_no'=>'ITNO2'},
          {'scac'=>"", 'master_bill'=>"", 'house_bill'=>"", 'sub_bill'=>'', 'it_no'=>''} # Skip blanks
        ],
        'cust_refs' => [
          {'cust_ref' => "ref1"},
          {'cust_ref' => "ref2"},
          {'cust_ref' => "po"} # Set a po here to make sure we're pulling them out of cust refs and into PO accumulations
        ],
        'containers' => [
          {'number' => 'CONT1', 'desc_content_1' => 'DESC 1', 'desc_content_2' => '', 'size' => 20, 'weight' => 123.45, 'quantity' => 234.56, 'uom'=>'CTNS', 'seal_no' => "ARF", 'lcl_fcl'=>'L', 'type_desc'=>'DRY VAN', 'teu'=>2},
          {'number' => 'CONT2', 'desc_content_1' => 'DESC 3', 'desc_content_2' => 'DESC 4', 'size' => 40, 'weight' => 123.45, 'quantity' => 234.56, 'uom'=>'CTNS', 'seal_no' => "ARF", 'lcl_fcl'=>'L', 'type_desc'=>'WET VAN', 'teu'=>3},
        ],
        'broker_invoices' => [
          {
            'file_no'=>12345, 'suffix'=>"A", 'cust_ref'=>"broker_inv_ref", 'invoice_date'=>20150401, 'total_amount'=>100.99, 'bill_to_cust'=>'CUST1',
            'name'=>'Customer 1', 'address_1' => '123 Fake St.', 'address_2' => 'Ste 22', 'city' => "Fakesville", 'state'=>'PA', 'zip' => 12345, 'country' => 'US',
            'lines' => [
              {'charge' => '1', 'description' => 'DUTY', 'amount'=>100.00, 'vendor'=>'VEND', 'vendor_name' => 'VENDOR NAME', 'vendor_ref'=>'VENDOR', 'charge_type'=>'D'},
              {'charge' => '100', 'description' => 'OUTLAY', 'amount'=>0.99, 'vendor'=>'', 'vendor_ref'=>'', 'charge_type'=>'O'}
            ]
          }
        ],
        'commercial_invoices' => [
          {
            'ci_no' => 'INV1',
            'currency' => "USD",
            'exchange_rate' => 123456,
            'value_foreign' => 12345,
            'country_origin' => 'CN',
            'weight_gross' => 123,
            'charges' => 1200,
            'invoice_date' => 20150402,
            'value_us' => 12399,
            'value_tot' => 12500,
            'qty' => 99,
            'qty_uom' => 'PCS',
            'lines' => [
              {
                'ci_line_no' => 10,
                'mid' => "MANFU",
                'part_no' => "PART",
                'po_no' => "po",
                'qty' => 1050,
                'qty_uom' => "BRL",
                'value_us' => 9999,
                'country_origin' => "CN",
                'country_export' => "VN",
                'related_parties' => "Y",
                'mid_name' => "MANFU NAME",
                'volume' => 1299,
                'contract' => 12312,
                'department' => "DEPT",
                "store_no" => "STORE",
                'product_line' => "PRODUCT",
                "visa_no" => 123,
                "visa_qty" => 199,
                "visa_uom" => "VISAUOM",
                "uscs_line_no" => 1,
                "value_foreign" => 99999,
                'fees' => [
                  {'customs_fee_code'=>499, 'amt_fee'=>123, 'amt_fee_prorated'=>234},
                  {'customs_fee_code'=>501, 'amt_fee'=>345},
                  {'customs_fee_code'=>56, 'amt_fee'=>456},
                ],
                'penalties' => [
                  {'penalty_type'=>"ADA", 'case_no'=>'123', 'bonded'=>"Y", "duty_amt"=>123, 'case_value'=>234, 'duty_percent'=>345},
                  {'penalty_type'=>"CVD", 'case_no'=>'234', 'bonded'=>"N", "duty_amt"=>345, 'case_value'=>456, 'duty_percent'=>567},
                ],
                'tariffs' => [
                  {
                    'tariff_no' => '1234567890',
                    'duty_specific' => 100,
                    'duty_advalorem' => 200,
                    'duty_additional' => 300,
                    'duty_other' => 400,
                    'value_entered' => 10000,
                    'spi_primary' => 'JO',
                    'spi_secondary' => 'EY',
                    'qty_1' => 100,
                    'uom_1' => "KG",
                    'qty_2' => 200,
                    'uom_2' => "LB",
                    'qty_3' => 300,
                    'uom_3' => "MT",
                    'weight_gross' => 10000,
                    'category_no' => '123',
                    'tariff_desc' => "STUFF"
                  },
                  {
                    'tariff_no' => '9876543210',
                    'duty_specific' => 400,
                    'duty_advalorem' => 500,
                    'duty_additional' => 600,
                    'duty_other' => 700,
                    'value_entered' => 20000,
                    'spi_primary' => 'JO',
                    'spi_secondary' => 'EY',
                    'qty_1' => 200,
                    'uom_1' => "KG",
                    'qty_2' => 300,
                    'uom_2' => "LB",
                    'qty_3' => 400,
                    'uom_3' => "MT",
                    'weight_gross' => 20000,
                    'category_no' => '123',
                    'tariff_desc' => "OTHER STUFF",
                    'tariff_desc_additional' => "REPLACEMENT DESC"
                  }
                ]
              }
            ]
          },
          {
            'ci_no' => 'INV2',
            'currency' => "USD",
            'exchange_rate' => 123456,
            'value_foreign' => 12345,
            'country_origin' => 'VN',
            'weight_gross' => 123,
            'charges' => 1200,
            'invoice_date' => 20150402,
            'value_us' => 12399,
            'value_tot' => 12500,
            'qty' => 99,
            'qty_uom' => 'PCS',
            'lines' => [
              {
                'ci_line_no' => 10,
                'mid' => "MANFU2",
                'part_no' => "PART2",
                'po_no' => "po2",
                'qty' => 1050,
                'qty_uom' => "CTN",
                'value_us' => 9999,
                'country_origin' => "VN",
                'country_export' => "MX",
                'related_parties' => "Y",
                'mid_name' => "MANFU2 NAME",
                'volume' => 1299,
                'contract' => 9999,
                'department' => "DEPT2",
                "store_no" => "STORE2",
                'product_line' => "PRODUCT2",
                "visa_no" => 123,
                "visa_qty" => 199,
                "visa_uom" => "VISAUOM",
                "uscs_line_no" => 1,
                "value_foreign" => 99999,
                'tariffs' => [
                  {
                    'tariff_no' => '1234567890',
                    'duty_specific' => 100,
                    'duty_advalorem' => 200,
                    'duty_additional' => 300,
                    'duty_other' => 400,
                    'value_entered' => 10000,
                    'spi_primary' => 'MX',
                    'spi_secondary' => 'EE',
                    'qty_1' => 100,
                    'uom_1' => "KG",
                    'qty_2' => 200,
                    'uom_2' => "LB",
                    'qty_3' => 300,
                    'uom_3' => "MT",
                    'weight_gross' => 10000,
                    'category_no' => 'CAT#',
                    'tariff_desc' => "STUFF"
                  }
                ]
              }
            ]
          }
        ]
      }
    end

    it "creates an entry using json data" do
      entry = described_class.new.process_entry @e
      entry.reload

      expect(entry).to be_persisted
      expect(entry.broker_reference).to eq "12345"
      expect(entry.entry_number).to eq "316123456"
      expect(entry.source_system).to eq "Alliance"
      expect(entry.release_cert_message).to eq "CERT MESSAGE"
      expect(entry.fda_message).to eq "FDA MESSAGE"
      expect(entry.customer_number).to eq "TEST"
      expect(entry.customer_name).to eq "CUST NAME"
      importer = Company.where(importer: true, alliance_customer_number: "TEST").first
      expect(importer).not_to be_nil
      expect(entry.importer).to eq importer
      expect(entry.merchandise_description).to eq "Goods Desc"
      expect(entry.entry_port_code).to eq "12345"
      expect(entry.lading_port_code).to eq "23456"
      expect(entry.unlading_port_code).to eq "1234"
      expect(entry.destination_state).to eq "PA"
      expect(entry.entry_type).to eq "01"
      expect(entry.voyage).to eq "Voyage"
      expect(entry.ult_consignee_code).to eq "UCNO"
      expect(entry.ult_consignee_name).to eq "UC Name"
      expect(entry.consignee_address_1).to eq "123 Fake St."
      expect(entry.consignee_address_2).to eq "STE 123"
      expect(entry.consignee_city).to eq "Fakesville"
      expect(entry.consignee_state).to eq "PA"
      expect(entry.transport_mode_code).to eq "10"
      expect(entry.carrier_code).to eq "Carrier"
      expect(entry.company_number).to eq "02"
      expect(entry.division_number).to eq "0009"
      expect(entry.recon_flags).to eq "NAFTA VALUE CLASS 9802"
      expect(entry.total_fees).to eq BigDecimal.new("123.45")
      expect(entry.total_duty_direct).to eq BigDecimal.new("8.90")
      expect(entry.entered_value).to eq BigDecimal.new("999.99")
      expect(entry.gross_weight).to eq 987654
      expect(entry.pay_type).to eq 3
      expect(entry.hmf).to eq BigDecimal.new("1.11")
      expect(entry.mpf).to eq BigDecimal.new("2.22")
      expect(entry.cotton_fee).to eq BigDecimal.new("3.33")
      expect(entry.daily_statement_number).to eq "bstatement"
      expect(entry.monthly_statement_number).to eq "astatement"
      expect(entry.monthly_statement_due_date).to eq Date.new(2015,3,15)

      # This is the only field different than the value above, since it's testing
      # that we handle date times w/ 60 as a minute value correctly
      expect(entry.export_date).to eq tz.parse("201503010700").to_date
      expect(entry.docs_received_date).to eq tz.parse("201503010800").to_date
      expect(entry.file_logged_date).to eq tz.parse "201503010900"
      expect(entry.first_it_date).to eq tz.parse("201503011000").to_date
      expect(entry.eta_date).to eq tz.parse("201503011100").to_date
      expect(entry.arrival_date).to eq tz.parse "201503011200"
      expect(entry.entry_filed_date).to eq tz.parse "201503011300"
      expect(entry.release_date).to eq tz.parse "201503011400"
      expect(entry.fda_release_date).to eq tz.parse "201503011500"
      expect(entry.trucker_called_date).to eq tz.parse "201503011600"
      expect(entry.delivery_order_pickup_date).to eq tz.parse "201503011700"
      expect(entry.freight_pickup_date).to eq tz.parse "201503011800"
      expect(entry.last_billed_date).to eq tz.parse "201503011900"
      expect(entry.invoice_paid_date).to eq tz.parse "201503012000"
      expect(entry.duty_due_date).to eq tz.parse("201503012100").to_date
      expect(entry.daily_statement_due_date).to eq tz.parse("201503012200").to_date
      expect(entry.free_date).to eq tz.parse "201503012300"
      expect(entry.edi_received_date).to eq tz.parse("201503020000").to_date
      expect(entry.fda_transmit_date).to eq tz.parse "201503020100"
      expect(entry.daily_statement_approved_date).to eq tz.parse("201503020200").to_date
      expect(entry.final_delivery_date).to eq tz.parse "201503020300"
      expect(entry.isf_sent_date).to eq tz.parse "201503020400"
      expect(entry.isf_accepted_date).to eq tz.parse "201503020500"
      expect(entry.fda_review_date).to eq tz.parse "201503020600"
      expect(entry.first_entry_sent_date).to eq tz.parse "201503020700"
      expect(entry.monthly_statement_received_date).to eq tz.parse("201503020800").to_date
      expect(entry.monthly_statement_paid_date).to eq tz.parse("201503020900").to_date
      expect(entry.first_release_date).to eq tz.parse "201503021000"

      expect(entry.first_7501_print).to eq tz.parse "201503191930"
      expect(entry.last_7501_print).to eq tz.parse "201503201247"

      expect(entry.master_bills_of_lading).to eq "XXXXMASTER\n XXXXMASTER2"
      expect(entry.house_bills_of_lading).to eq "HOUSE\n HOUSE2"
      expect(entry.sub_house_bills_of_lading).to eq "SUB\n SUB2"
      expect(entry.it_numbers).to eq "ITNO\n ITNO2"

      comments = entry.entry_comments
      expect(comments.size).to eq 3

      expect(comments.first.body).to eq "Document Image created for F7501F   7501 Form."
      expect(comments.first.username).to eq "User1"
      expect(comments.first).not_to be_public_comment
      expect(comments.first.generated_at).to eq(tz.parse "201503191930")

      expect(comments.second.body).to eq "Document Image created for FORM_N7501"
      expect(comments.second.username).to eq "User2"
      # This one is private because of the note's actual textual content
      expect(comments.second).not_to be_public_comment
      expect(comments.second.generated_at).to eq(tz.parse "201503201247")

      expect(comments.third.body).to eq "User3 did something"
      expect(comments.third.username).to eq "User3"
      expect(comments.third).to be_public_comment
      expect(comments.third.generated_at).to eq(tz.parse "201503201247")

      expect(entry.customer_references).to eq "ref1\n ref2\n broker_inv_ref"

      expect(entry.containers.size).to eq 2
      c = entry.containers.first
      expect(c.container_number).to eq "CONT1"
      expect(c.goods_description).to eq "DESC 1"
      expect(c.container_size).to eq "20"
      expect(c.weight).to eq 123
      expect(c.quantity).to eq 234
      expect(c.uom).to eq "CTNS"
      expect(c.seal_number).to eq "ARF"
      expect(c.fcl_lcl).to eq "L"
      expect(c.size_description).to eq "DRY VAN"
      expect(c.teus).to eq 2

      c = entry.containers.second
      expect(c.container_number).to eq "CONT2"
      expect(c.goods_description).to eq "DESC 3\n DESC 4"
      expect(c.container_size).to eq "40"
      expect(c.weight).to eq 123
      expect(c.quantity).to eq 234
      expect(c.uom).to eq "CTNS"
      expect(c.seal_number).to eq "ARF"
      expect(c.fcl_lcl).to eq "L"
      expect(c.size_description).to eq "WET VAN"
      expect(c.teus).to eq 3

      expect(entry.container_numbers).to eq "CONT1\n CONT2"
      expect(entry.fcl_lcl).to eq "LCL"
      expect(entry.container_sizes).to eq "20-DRY VAN\n 40-WET VAN"

      expect(entry.broker_invoices.size).to eq 1
      bi = entry.broker_invoices.first

      expect(bi.invoice_number).to eq "12345A"
      expect(bi.suffix).to eq "A"
      expect(bi.customer_number).to eq "CUST1"
      expect(bi.broker_reference).to eq "12345"
      expect(bi.invoice_date).to eq Date.new(2015, 4, 1)
      expect(bi.invoice_total).to eq 100.99
      expect(bi.source_system).to eq "Alliance"
      expect(bi.bill_to_name).to eq "Customer 1"
      expect(bi.bill_to_address_1).to eq "123 Fake St."
      expect(bi.bill_to_address_2).to eq "Ste 22"
      expect(bi.bill_to_city).to eq "Fakesville"
      expect(bi.bill_to_state).to eq "PA"
      expect(bi.bill_to_zip).to eq "12345"
      expect(bi.bill_to_country.iso_code).to eq "US"

      expect(bi.broker_invoice_lines.size).to eq 2
      l = bi.broker_invoice_lines.first
      expect(l.charge_code).to eq "0001"
      expect(l.charge_description).to eq "DUTY"
      expect(l.charge_amount).to eq 100.00
      expect(l.vendor_name).to eq "VENDOR NAME"
      expect(l.vendor_reference).to eq "VENDOR"
      expect(l.charge_type).to eq "D"

      l = bi.broker_invoice_lines.second
      expect(l.charge_code).to eq "0100"
      expect(l.charge_description).to eq "OUTLAY"
      expect(l.charge_amount).to eq 0.99
      expect(l.vendor_name).to be_blank
      expect(l.vendor_reference).to be_blank
      expect(l.charge_type).to eq "O"

      expect(entry.charge_codes).to eq "0001\n 0100"
      expect(entry.broker_invoice_total).to eq 100.99

      expect(entry.commercial_invoices.size).to eq 2

      ci = entry.commercial_invoices.first
      expect(ci.invoice_number).to eq "INV1"
      expect(ci.currency).to eq "USD"
      expect(ci.exchange_rate).to eq BigDecimal.new("0.123456")
      expect(ci.invoice_value_foreign).to eq 123.45
      expect(ci.country_origin_code).to eq "CN"
      expect(ci.gross_weight).to eq 123
      expect(ci.total_charges).to eq 12.00
      expect(ci.invoice_date).to eq Date.new(2015,4,2)
      expect(ci.invoice_value).to eq (BigDecimal.new("0.123456") * 123.45).round(2)
      expect(ci.total_quantity).to eq 99
      expect(ci.total_quantity_uom).to eq 'PCS'
      # MID is pulled up from the first line.
      expect(ci.mfid).to eq "MANFU"

      line = ci.commercial_invoice_lines.first
      expect(line.line_number).to eq 1
      expect(line.mid).to eq "MANFU"
      expect(line.part_number).to eq "PART"
      expect(line.po_number).to eq "po"
      expect(line.quantity).to eq 1.05
      expect(line.unit_of_measure).to eq "BRL"
      expect(line.value).to eq BigDecimal.new("99.99")
      expect(line.country_origin_code).to eq "CN"
      expect(line.country_export_code).to eq "VN"
      expect(line.related_parties).to be_true
      expect(line.vendor_name).to eq "MANFU NAME"
      expect(line.volume).to eq 12.99
      expect(line.contract_amount).to eq 123.12
      expect(line.department).to eq "DEPT"
      expect(line.store_name).to eq "STORE"
      expect(line.product_line).to eq "PRODUCT"
      expect(line.visa_number).to eq "123"
      expect(line.visa_quantity).to eq 1.99
      expect(line.visa_uom).to eq "VISAUOM"
      expect(line.customs_line_number).to eq 1
      expect(line.value_foreign).to eq BigDecimal.new("999.99")
      expect(line.mpf).to eq 1.23
      expect(line.prorated_mpf).to eq 2.34
      expect(line.hmf).to eq 3.45
      expect(line.cotton_fee).to eq 4.56
      expect(line.add_case_number).to eq '123'
      expect(line.add_bond).to be_true
      expect(line.add_duty_amount).to eq 1.23
      expect(line.add_case_value).to eq 2.34
      expect(line.add_case_percent).to eq 3.45
      expect(line.cvd_case_number).to eq '234'
      expect(line.cvd_bond).to be_false
      expect(line.cvd_duty_amount).to eq 3.45
      expect(line.cvd_case_value).to eq 4.56
      expect(line.cvd_case_percent).to eq 5.67

      tariff = line.commercial_invoice_tariffs.first
      expect(tariff.hts_code).to eq "1234567890"
      expect(tariff.duty_amount).to eq 10.00
      expect(tariff.entered_value).to eq BigDecimal.new("100.00")
      expect(tariff.duty_rate).to eq BigDecimal.new("0.1")
      expect(tariff.spi_primary).to eq "JO"
      expect(tariff.spi_secondary).to eq "EY"
      expect(tariff.classification_qty_1).to eq 1
      expect(tariff.classification_uom_1).to eq "KG"
      expect(tariff.classification_qty_2).to eq 2
      expect(tariff.classification_uom_2).to eq "LB"
      expect(tariff.classification_qty_3).to eq 3
      expect(tariff.classification_uom_3).to eq "MT" 
      expect(tariff.gross_weight).to eq 10000
      expect(tariff.quota_category).to eq 123
      expect(tariff.tariff_description).to eq "STUFF"

      tariff = line.commercial_invoice_tariffs.second
      expect(tariff.tariff_description).to eq "REPLACEMENT DESC"


      expect(entry.mfids).to eq "MANFU\n MANFU2"
      expect(entry.export_country_codes).to eq "VN\n MX"
      expect(entry.origin_country_codes).to eq "CN\n VN"
      expect(entry.vendor_names).to eq "MANFU NAME\n MANFU2 NAME"
      expect(entry.total_units_uoms).to eq "BRL\n CTN"
      expect(entry.po_numbers).to eq "po\n po2"
      expect(entry.part_numbers).to eq "PART\n PART2"
      expect(entry.departments).to eq "DEPT\n DEPT2"
      expect(entry.store_names).to eq "STORE\n STORE2"
      expect(entry.special_program_indicators).to eq "JO\n EY\n MX\n EE"
      expect(entry.total_units).to eq BigDecimal.new("2.10")
      expect(entry.total_cvd).to eq BigDecimal.new("3.45")
      expect(entry.total_add).to eq BigDecimal.new("1.23")
      expect(entry.total_packages).to eq BigDecimal.new("67")
      expect(entry.total_packages_uom).to eq "PCS"
  
      expect(entry.importer).not_to be_nil
      expect(entry.importer.name).to eq entry.customer_name
      expect(entry.importer.alliance_customer_number).to eq entry.customer_number
      expect(entry.importer.importer).to be_true

      # Uncomment this once this feed is the "One True Source" instead of the AllianceParser
      #expect(entry.last_exported_from_source).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse "2015-03-12T13:26:20-04:00"

      # This should all be nil because the liquidation date is not set
      expect(entry.liquidation_type_code).to be_nil
      expect(entry.liquidation_type).to be_nil
      expect(entry.liquidation_action_code).to be_nil
      expect(entry.liquidation_extension_code).to be_nil
      expect(entry.liquidation_extension_count).to be_nil
      expect(entry.liquidation_duty).to be_nil
      expect(entry.liquidation_fees).to be_nil
      expect(entry.liquidation_tax).to be_nil
      expect(entry.liquidation_ada).to be_nil
      expect(entry.liquidation_cvd).to be_nil
      expect(entry.liquidation_total).to be_nil
    end

    it "processes liquidation information if liquidation date is not in the future" do
      @e['dates'] << {'date_no'=>44, 'date'=>201501010000}

      entry = described_class.new.process_entry @e
      entry.reload

      expect(entry.liquidation_type_code).to eq "liq_type"
      expect(entry.liquidation_type).to eq "liq type desc"
      expect(entry.liquidation_action_code).to eq "action_liquidation"
      expect(entry.liquidation_extension_code).to eq "extend_suspend_liq"
      expect(entry.liquidation_extension_count).to eq 2
      expect(entry.liquidation_duty).to eq BigDecimal.new("123.45")
      expect(entry.liquidation_fees).to eq BigDecimal.new('234.56')
      expect(entry.liquidation_tax).to eq BigDecimal.new('345.67')
      expect(entry.liquidation_ada).to eq BigDecimal.new('456.78')
      expect(entry.liquidation_cvd).to eq BigDecimal.new('567.89')
      expect(entry.liquidation_total).to eq BigDecimal.new("1728.35")

    end

    it "handles single statement numbers as daily statements" do
      @e['daily_statement_no'] = 'astatement'
      entry = described_class.new.process_entry @e
      entry.reload

      expect(entry.daily_statement_number).to eq "astatement"
      expect(entry.monthly_statement_number).to be_nil
    end

    it "skips unused recon flags" do
      @e['recon_nafta'] = "N"
      @e['recon_9802'] = "N"
      @e['recon_value'] = "N"
      entry = described_class.new.process_entry @e
      expect(entry.recon_flags).to eq "CLASS"

      @e['recon_class'] = 'N'
      @e['recon_nafta'] = "Y"
      entry = described_class.new.process_entry @e
      expect(entry.recon_flags).to eq "NAFTA"

      @e['recon_nafta'] = 'N'
      @e['recon_9802'] = "Y"
      entry = described_class.new.process_entry @e
      expect(entry.recon_flags).to eq "9802"

      @e['recon_9802'] = "N"
      @e['recon_value'] = "Y"
      entry = described_class.new.process_entry @e
      expect(entry.recon_flags).to eq "VALUE"
    end

    it "handles 98 date for docs received" do
      @e['dates'] << {'date_no'=>98, 'date'=>201503310000}
      entry = described_class.new.process_entry @e
      expect(entry.docs_received_date).to eq tz.parse("201503310000").to_date
    end

    it "uses earliest it date value" do
      # Put an actual Date value in the entry here so that we're also making sure that
      # the earliest value is handing comparison against the actual entry itself
      e = Factory(:entry, broker_reference: @e['file_no'], source_system: "Alliance", first_it_date: Date.new(2016, 1, 1))
      entry = described_class.new.process_entry @e
      expect(entry.first_it_date).to eq tz.parse("201503011000").to_date
    end

    it "updates an entry using json data" do
      # Make sure the entry has all the components of an existing entry, and that they're
      # all wiped
      t = Factory(:commercial_invoice_tariff)
      e = t.commercial_invoice_line.entry
      e.update_attributes! source_system: "Alliance", broker_reference: "REF"
      @e['file_no'] = e.broker_reference

      Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: e))
      Factory(:container, entry: e)
      e.entry_comments.create! body: "Testing"


      entry = described_class.new.process_entry @e

      # Make sure the exisitng data was wiped and new data populated
      expect(entry).to be_persisted
      expect(entry.broker_reference).to eq e.broker_reference
      expect(entry.broker_invoices.size).to eq 1
      expect(entry.broker_invoices.first.invoice_number).to eq "12345A"
      expect(entry.commercial_invoices.size).to eq 2
      expect(entry.commercial_invoices.first.invoice_number).to eq "INV1"
      expect(entry.entry_comments.size).to eq 3
      expect(entry.containers.size).to eq 2
      expect(entry.containers.first.container_number).to eq "CONT1"
    end

    it "uses cross process locking / per entry locking" do
      Lock.should_receive(:acquire).with(Lock::ALLIANCE_PARSER).and_yield
      Lock.should_receive(:acquire).with("CreateAllianceCustomer").and_yield
      Lock.should_receive(:with_lock_retry).with(instance_of(Entry)).and_yield

      entry = described_class.new.process_entry @e
      expect(entry).to be_persisted
    end

    it "does not update data with a newer last exported from source date" do
      e = Factory(:entry, broker_reference: @e['file_no'], source_system: "Alliance", last_exported_from_source: Time.zone.now)
      expect(described_class.new.process_entry @e).to be_nil
    end

    it "does not update data with a newer expected update date source date" do
      # This only needs to be in place until we discontinue the Alliance feed, at which point the extract_time value from this feed
      # should be stored in the last exported from source field.
      e = Factory(:entry, broker_reference: @e['file_no'], source_system: "Alliance", expected_update_time: Time.zone.now)
      expect(described_class.new.process_entry @e).to be_nil
    end

    it "logs an error message if periodic monthly data is missing" do
      @e['pms_year'] = 2016
      StandardError.any_instance.should_receive(:log_me)
      described_class.new.process_entry @e
    end
  end

  describe "parse" do
    before :each do 
      OpenChain::AllianceImagingClient.stub(:request_images)
    end

    it "reads json, saves copy of json to s3, parses it" do
      described_class.stub(:production?).and_return true
      json = {entry: {'file_no'=>12345, 'extract_time'=>"2015-04-01 00:00"}}
      now = Time.zone.now.strftime "%Y-%m/%d"
      expected_key = "#{now}/home/ubuntu/ftproot/chainroot/www-vfitrack-net/_kewill_entry/12345-2015-04-01-00-00.json"
      entry = Entry.new(broker_reference: "TESTING")
      described_class.any_instance.should_receive(:process_entry).with(json[:entry], save_to_s3: true, key:expected_key, bucket: OpenChain::S3.integration_bucket_name).and_return entry
      contents = nil
      s3_bucket = nil
      s3_key = nil
      OpenChain::S3.should_receive(:upload_file) do |bucket, key, file|
        s3_bucket = bucket
        s3_key = key
        contents = file.read
      end

      OpenChain::AllianceImagingClient.should_receive(:request_images).with "TESTING"
      entry.should_receive(:broadcast_event).with(:save)

      described_class.parse json.to_json, save_to_s3: true

      expect(contents).to eq json.to_json
      expect(s3_bucket).to eq OpenChain::S3.integration_bucket_name
      expect(s3_key).to eq expected_key
    end

    it "doesn't upload to s3 outside of production" do
      json = {entry: {'file_no'=>12345, 'extract_time'=>"2015-04-01 00:00"}}
      described_class.stub(:production?).and_return false
      described_class.any_instance.should_receive(:process_entry).with(json[:entry], save_to_s3: true)
      OpenChain::S3.should_not_receive(:upload_file)

      described_class.parse json.to_json, save_to_s3: true
    end

    it "handles a hash instead of json" do
      json = {entry: {'file_no'=>12345, 'extract_time'=>"2015-04-01 00:00"}}.with_indifferent_access
      described_class.any_instance.should_receive(:process_entry).with(json[:entry], {})
      described_class.parse json
    end

    it 'does not upload if save_to_s3 is missing' do 
      json = {'entry' => {'file_no'=>12345, 'extract_time'=>"2015-04-01 00:00"}}
      described_class.any_instance.should_receive(:process_entry).with(json['entry'], {})
      described_class.parse json.to_json
    end

    it "returns if there is no entry wrapped" do
      described_class.parse({})
    end
  end
end