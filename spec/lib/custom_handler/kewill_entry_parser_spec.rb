describe OpenChain::CustomHandler::KewillEntryParser do

  let (:tz) {ActiveSupport::TimeZone["Eastern Time (US & Canada)"]}

  describe "process_entry" do
    let! (:us) { Factory(:country, iso_code: "US")}

    let! (:tariff_classification) { 
      # Use a duty computation that includes all the rate types
      c = Factory(:tariff_classification, country: us, tariff_number: "1234567890", effective_date_start: Date.new(2001, 1, 1), unit_of_measure_1: "CM", unit_of_measure_2: "KG", duty_computation: "6")
      rate_1 = Factory(:tariff_classification_rate, tariff_classification: c, rate_advalorem: BigDecimal("0.50"), rate_specific: BigDecimal("1.25"), rate_additional: BigDecimal("3.55"), special_program_indicator: "JO")
      rate_2 = Factory(:tariff_classification_rate, tariff_classification: c, rate_advalorem: BigDecimal("0.15"), rate_specific: BigDecimal("0.25"), rate_additional: BigDecimal("1.55"), special_program_indicator: "MX")
      c
    }

    before :each do
      pms_dates = {
        3 => 15
      }

      KeyJsonItem.usc_periodic_dates(2015).create! json_data: pms_dates.to_json

      @e = {
        'cust_no' => 'TEST',
        'irs_no' => "12-23456789",
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
        'vessel_airline_name' => "Vessel",
        'location' => "ABC123",
        'location_of_goods' => "LOCATION",
        'uc_no' => "UCNO",
        'uc_name' => "UC Name",
        'uc_address_1' => "123 Fake St.",
        'uc_address_2' => "STE 123",
        'uc_state' => "PA",
        'uc_city' => "Fakesville",
        'uc_zip' => "12345",
        'uc_country' => "XX",
        'mot' => 10,
        'carrier' => "Carrier",
        'carrier_name' => "Carrier Name",
        'company_no' => 2,
        'division_no' => 9,
        'recon_nafta' => "Y",
        'recon_value' => "Y",
        'recon_class' => "Y",
        'recon_9802' => "Y",
        'fees_tot' => 12345,
        'taxes_tot' => 234,
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
        'liquidation_action_desc' => 'liquidation_desc',
        'extend_suspend_liq' => 'extend_suspend_liq',
        'extension_suspension_desc' => 'extension_desc',
        'no_extend_suspend_liquidation' => '2',
        'duty_amt_liquidated' => 123.45,
        'fee_amt_liquidated' => 234.56,
        'tax_amt_liquidated' => 345.67,
        'ada_amt_liquidated' => 456.78,
        'cvd_amt_liquidated' => 567.89,
        'split' => "N",
        'split_release_option' => "1",
        'dates' => [
          # Note the time ending in 60..stupid Alliance has dates w/ a minute value of 60 rather
          # than incrementing the hour.
          {'date_no'=>1, 'date'=>201503010660},
          {'date_no'=>2, 'date'=>201604271130},
          {'date_no'=>3, 'date'=>201503010800},
          {'date_no'=>4, 'date'=>201503010900},
          {'date_no'=>7, 'date'=>201710191200},
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
          {'date_no'=>99202, 'date'=>201503021000},
          {'date_no'=>10, 'date'=>201701031200},
          # release/hold dates
          {'date_no'=>99628, 'date'=>201701031300},
          {'date_no'=>99630, 'date'=>201701031400},
          {'date_no'=>99616, 'date'=>201701031500},
          {'date_no'=>99618, 'date'=>201701031600},
          {'date_no'=>99694, 'date'=>201701031700},
          {'date_no'=>99696, 'date'=>201701031800},
          {'date_no'=>90036, 'date'=>201701031900},
          {'date_no'=>90037, 'date'=>201701032000},
          {'date_no'=>90054, 'date'=>201701032100}, #multi
          {'date_no'=>90055, 'date'=>201701032200}, #multi
          {'date_no'=>99638, 'date'=>201701032300},
          {'date_no'=>99640, 'date'=>201701040000},
          {'date_no'=>99689, 'date'=>201701040100},
          {'date_no'=>99684, 'date'=>201701040200},
          {'date_no'=>99604, 'date'=>201701040300},
          {'date_no'=>99607, 'date'=>201701040400},
          {'date_no'=>99611, 'date'=>201701040500},
          {'date_no'=>99613, 'date'=>201701040600},
          {'date_no'=>99645, 'date'=>201701040700},
          {'date_no'=>99648, 'date'=>201701040800},
          {'date_no'=>5052, 'date'=>201701040900},
          {'date_no'=>5055, 'date'=>201701041000},
          {'date_no'=>5053, 'date'=>201701041100},
          {'date_no'=>5056, 'date'=>201701041200},
          {'date_no'=>91065, 'date'=>201701041300},
          {'date_no'=>99851, 'date'=>201701041400}, #multi
          {'date_no'=>99846, 'date'=>201701041500},          
          {'date_no'=>99844, 'date'=>201701041600},
          
          {'date_no'=>92033, 'date'=>201712181400},

          # milestone exceptions
          {'date_no'=>3000, 'date'=>201701050000},
          {'date_no'=>3001, 'date'=>201701060000},
          {'date_no'=>3002, 'date'=>201701070000},
          {'date_no'=>3003, 'date'=>201701080000},
          {'date_no'=>3004, 'date'=>201701090000},
          {'date_no'=>3005, 'date'=>201701100000},
          {'date_no'=>3006, 'date'=>201701110000},
          {'date_no'=>3007, 'date'=>201701120000},
          {'date_no'=>3008, 'date'=>201701130000},
          {'date_no'=>3009, 'date'=>201701140000},
          {'date_no'=>3010, 'date'=>201701150000},
          {'date_no'=>3011, 'date'=>201701160000},
          {'date_no'=>3012, 'date'=>201701170000},
          {'date_no'=>3013, 'date'=>201701180000}
        ],
        'notes' => [
          {'note' => "Document Image created for F7501F   7501 Form.", 'modified_by'=>"User1", 'date_updated' => 201503191930, 'confidential' => "Y"},
          {'note' => "Document Image created for FORM_N7501", 'modified_by'=>"User2", 'date_updated' => 201503201247},
          {'note' => "User3 did something", 'modified_by'=>"User3", 'date_updated' => 201503201247},
          {'note' => "Customs Did something", 'modified_by'=>"CUSTOMS", 'date_updated'=>201601191230}
        ],
        'ids' => [
          {'scac'=>"XXXX", 'master_bill'=>"MASTER", 'house_bill'=>"HOUSE", 'sub_bill'=>'SUB', 'it_no'=>'ITNO', 'scac_house'=>'    '},
          {'scac'=>"XXXX", 'master_bill'=>"MASTER", 'house_bill'=>"HOUSE", 'sub_bill'=>'SUB', 'it_no'=>'ITNO', 'scac_house'=>"SCAC"}, # Skip the second line, it's duplicate
          {'scac'=>"XXXX", 'master_bill'=>"MASTER2", 'house_bill'=>"HOUSE2", 'sub_bill'=>'SUB2', 'it_no'=>'ITNO2', 'scac_house'=>"SCAC2"},
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
              {'charge' => '1', 'description' => 'DUTY', 'amount'=>-10000, 'vendor'=>'VEND', 'vendor_name' => 'VENDOR NAME', 'vendor_ref'=>'VENDOR', 'charge_type'=>'D'},
              {'charge' => '100', 'description' => 'OUTLAY', 'amount'=>99, 'vendor'=>'', 'vendor_name' => '', 'vendor_ref'=>'', 'charge_type'=>'O'}
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
            'non_dutiable_amt' => 12345,
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
                'contract' => 123.12,
                'department' => "DEPT",
                "store_no" => "STORE",
                'product_line' => "PRODUCT",
                "visa_no" => 123,
                "visa_qty" => 199,
                "visa_uom" => "VISAUOM",
                "uscs_line_no" => 1,
                "freight_amt" => 12.30,
                "other_amt" => 45.60,
                "cash_discount" => 78.90,
                "add_to_make_amt" => 1.23,
                "value_foreign" => 99999,
                "container_no" => "CONT1",
                'value_appraisal_method' => "F",
                'non_dutiable_amt' => 12345,
                'misc_discount' => 33.44,
                'agriculture_license_no' => "LICENSE NO",
                'fees' => [
                  {'customs_fee_code'=>499, 'amt_fee'=>123, 'amt_fee_prorated'=>234},
                  {'customs_fee_code'=>501, 'amt_fee'=>345},
                  {'customs_fee_code'=>56, 'amt_fee'=>456},
                  {'customs_fee_code'=>123, 'amt_fee'=>5, 'amt_fee_prorated' => 250},
                  {'customs_fee_code'=>100, 'amt_fee'=>1250}
                ],
                'penalties' => [
                  {'penalty_type'=>"ADA", 'case_no'=>'123', 'bonded'=>"Y", "duty_amt"=>123, 'case_value'=>234, 'duty_percent'=>345},
                  {'penalty_type'=>"CVD", 'case_no'=>'234', 'bonded'=>"N", "duty_amt"=>345, 'case_value'=>456, 'duty_percent'=>567},
                ],
                'tariffs' => [
                  {
                    'tariff_no' => '1234567890',
                    'duty_advalorem' => 110,
                    'duty_specific' => 220,
                    'duty_additional' => 330,
                    'duty_other' => 440,
                    'value_entered' => 9960,
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
                    'tariff_desc' => "STUFF",
                    "lacey" => [{
                                "pg_seq_nbr": 1,
                                "product_seq_nbr": 0,
                                "detailed_description": "2 IN 1 CONVERTABLE PET STEPS",
                                "line_value": 309960,
                                "component_name": "WOOD",
                                "component_qty": 93200,
                                "component_uom": "KG",
                                "scientific_genus_name": "Special",
                                "scientific_species_name": "Composite",
                                "country_harvested": "CN",
                                "percent_recycled_material": 0,
                                "containers": ["EMCU9890535", "IMTU1064900", "EGHU1017227"]
                              },
                              {
                                "pg_seq_nbr": 2,
                                "product_seq_nbr": 0,
                                "detailed_description": "WAVY WOOD PET GATE",
                                "line_value": 1256400,
                                "component_name": "WOOD",
                                "component_qty": 736400,
                                "component_uom": "KG",
                                "scientific_genus_name": "Special",
                                "scientific_species_name": "Composite",
                                "country_harvested": "CN",
                                "percent_recycled_material": 20000,
                                "containers": []
                              }
                            ]
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
                ],
                'containers' => [
                  {
                    "seq_no": 1,
                    "container_no": "CONT2",
                    "cartons": 0,
                    "qty": 21772800,
                    "qty_uom": "SQ"
                  }
                ]
              }
            ],
            "master_bills":["MOLU13903762056", "MOLU13903762057"],
            "house_bills":["ABCD1029384756", "ABCD1029384757"]
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
            'non_dutiable_amt' => 12345,
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
                'contract' => "$9,999.00",
                'department' => "DEPT2",
                "store_no" => "STORE2",
                'product_line' => "PRODUCT2",
                "visa_no" => 123,
                "visa_qty" => 199,
                "visa_uom" => "VISAUOM",
                "uscs_line_no" => 2,
                "value_foreign" => 99999,
                "container_no" => "NOTACONTAINER",
                "value_appraisal_method" => "A",
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
            ],
            "master_bills":[],
            "house_bills":[]
          }
        ],
        'post_summary_corrections' => [
          { 'lines' => [ 
                         {
                          'ci_no' => 'INV1',
                          'ci_line_no' => 10,
                          'reason_code' => 'L04'
                         }

             ],
            'sent_date' => 201803151200 
          }
        ]
      }
    end

    it "creates an entry using json data" do
      expect(subject).to receive(:process_special_tariffs)

      entry = subject.process_entry @e
      entry.reload

      expect(entry).to be_persisted
      expect(entry.broker_reference).to eq "12345"
      expect(entry.entry_number).to eq "316123456"
      expect(entry.source_system).to eq "Alliance"
      expect(entry.last_exported_from_source).to eq "2015-03-12 17:26:20"
      expect(entry.expected_update_time).to eq "2015-02-12 11:00"
      expect(entry.release_cert_message).to eq "CERT MESSAGE"
      expect(entry.fda_message).to eq "FDA MESSAGE"
      expect(entry.customer_number).to eq "TEST"
      expect(entry.customer_name).to eq "CUST NAME"
      expect(entry.importer_tax_id).to eq "12-23456789"
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
      expect(entry.vessel).to eq "Vessel"
      expect(entry.location_of_goods).to eq "ABC123"
      expect(entry.location_of_goods_description).to eq "LOCATION"
      expect(entry.ult_consignee_code).to eq "UCNO"
      expect(entry.ult_consignee_name).to eq "UC Name"
      expect(entry.consignee_address_1).to eq "123 Fake St."
      expect(entry.consignee_address_2).to eq "STE 123"
      expect(entry.consignee_city).to eq "Fakesville"
      expect(entry.consignee_state).to eq "PA"
      expect(entry.consignee_postal_code).to eq "12345"
      expect(entry.consignee_country_code).to eq "XX"
      expect(entry.transport_mode_code).to eq "10"
      expect(entry.carrier_code).to eq "Carrier"
      expect(entry.house_carrier_code).to eq "SCAC"
      expect(entry.carrier_name).to eq "Carrier Name"
      expect(entry.company_number).to eq "02"
      expect(entry.division_number).to eq "0009"
      expect(entry.recon_flags).to eq "NAFTA VALUE CLASS 9802"
      expect(entry.total_fees).to eq BigDecimal.new("123.45")
      expect(entry.total_taxes).to eq BigDecimal.new("2.34")
      expect(entry.total_duty).to eq BigDecimal.new("1.23")
      expect(entry.total_duty_direct).to eq BigDecimal.new("8.90")
      expect(entry.entered_value).to eq BigDecimal.new("999.99")
      expect(entry.gross_weight).to eq 987654
      expect(entry.pay_type).to eq 3
      expect(entry.hmf).to eq BigDecimal.new("1.11")
      expect(entry.mpf).to eq BigDecimal.new("2.22")
      expect(entry.cotton_fee).to eq BigDecimal.new("3.33")
      expect(entry.other_fees).to eq BigDecimal.new("15")
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
      expect(entry.entry_filed_date).to eq tz.parse "201601191230"
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
      expect(entry.bol_received_date).to eq tz.parse "201604271130"
      expect(entry.arrival_notice_receipt_date).to eq tz.parse "201701031200"

      #hold/release dates
      expect(entry.ams_hold_date).to eq tz.parse "201701031300" 
      expect(entry.ams_hold_release_date).to eq tz.parse "201701031400" 
      expect(entry.aphis_hold_date).to eq tz.parse "201701031500" 
      expect(entry.aphis_hold_release_date).to eq tz.parse "201701031600" 
      expect(entry.atf_hold_date).to eq tz.parse "201701031700" 
      expect(entry.atf_hold_release_date).to eq tz.parse "201701031800" 
      expect(entry.cargo_manifest_hold_date).to eq tz.parse "201701031900" 
      expect(entry.cargo_manifest_hold_release_date).to eq tz.parse "201701032000" 
      expect(entry.cbp_hold_date).to eq tz.parse "201701032100" 
      expect(entry.cbp_hold_release_date).to eq tz.parse "201701032200" 
      expect(entry.cbp_intensive_hold_date).to eq tz.parse "201701032100" 
      expect(entry.cbp_intensive_hold_release_date).to eq tz.parse "201701032200" 
      expect(entry.ddtc_hold_date).to eq tz.parse "201701032300" 
      expect(entry.ddtc_hold_release_date).to eq tz.parse "201701040000" 
      expect(entry.fda_hold_date).to eq tz.parse "201701040100" 
      expect(entry.fda_hold_release_date).to eq tz.parse "201701040200" 
      expect(entry.fsis_hold_date).to eq tz.parse "201701040300" 
      expect(entry.fsis_hold_release_date).to eq tz.parse "201701040400" 
      expect(entry.nhtsa_hold_date).to eq tz.parse "201701040500" 
      expect(entry.nhtsa_hold_release_date).to eq tz.parse "201701040600" 
      expect(entry.nmfs_hold_date).to eq tz.parse "201701040700" 
      expect(entry.nmfs_hold_release_date).to eq tz.parse "201701040800" 
      expect(entry.usda_hold_date).to eq tz.parse "201701040900" 
      expect(entry.usda_hold_release_date).to eq tz.parse "201701041000" 
      expect(entry.other_agency_hold_date).to eq tz.parse "201701041100" 
      expect(entry.other_agency_hold_release_date).to eq tz.parse "201701041200"
      expect(entry.one_usg_date).to eq tz.parse "201701041300"
      expect(entry.hold_date).to eq tz.parse "201701031300"
      expect(entry.hold_release_date).to eq tz.parse "201701041500" 
      expect(entry.fish_and_wildlife_hold_date).to eq tz.parse "201701041400"
      expect(entry.fish_and_wildlife_hold_release_date).to eq tz.parse "201701041500"

      # exception dates
      expect(entry.miscellaneous_entry_exception_date).to eq tz.parse("201701050000").to_date
      expect(entry.invoice_missing_date).to eq tz.parse("201701060000").to_date
      expect(entry.bol_discrepancy_date).to eq tz.parse("201701070000").to_date
      expect(entry.detained_at_port_of_discharge_date).to eq tz.parse("201701080000").to_date
      expect(entry.invoice_discrepancy_date).to eq tz.parse("201701090000").to_date
      expect(entry.docs_missing_date).to eq tz.parse("201701100000").to_date
      expect(entry.hts_missing_date).to eq tz.parse("201701110000").to_date
      expect(entry.hts_expired_date).to eq tz.parse("201701120000").to_date
      expect(entry.hts_misclassified_date).to eq tz.parse("201701130000").to_date
      expect(entry.hts_need_additional_info_date).to eq tz.parse("201701140000").to_date
      expect(entry.mid_discrepancy_date).to eq tz.parse("201701150000").to_date
      expect(entry.additional_duty_confirmation_date).to eq tz.parse("201701160000").to_date
      expect(entry.pga_docs_missing_date).to eq tz.parse("201701170000").to_date
      expect(entry.pga_docs_incomplete_date).to eq tz.parse("201701180000").to_date
      
      expect(entry.fish_and_wildlife_transmitted_date).to eq tz.parse "201701041600"
      expect(entry.fish_and_wildlife_secure_facility_date).to eq tz.parse "201701041400"
      expect(entry.first_7501_print).to eq tz.parse "201503191930"
      expect(entry.last_7501_print).to eq tz.parse "201503201247"
      expect(entry.import_date).to eq Date.new(2017, 10, 19)
      expect(entry.first_release_received_date).to eq tz.parse("201712181400")

      expect(entry.master_bills_of_lading).to eq "XXXXMASTER\n XXXXMASTER2"
      expect(entry.house_bills_of_lading).to eq "HOUSE\n SCAC2HOUSE2\n SCACHOUSE"
      expect(entry.sub_house_bills_of_lading).to eq "SUB\n SUB2"
      expect(entry.it_numbers).to eq "ITNO\n ITNO2"
      expect(entry.total_non_dutiable_amount).to eq BigDecimal("246.9")
      expect(entry.product_lines).to eq "PRODUCT\n PRODUCT2"
      expect(entry.summary_rejected?).to eq false
      expect(entry.split_shipment?).to eq false
      expect(entry.split_release_option).to eq "1"
      expect(entry.summary_line_count).to eq 2

      comments = entry.entry_comments
      expect(comments.size).to eq 4

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
      c = entry.containers.find {|co| co.container_number == "CONT1"}
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

      c = entry.containers.find {|co| co.container_number == "CONT2"}
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
      expect(l.charge_amount).to eq -100.00
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
      expect(ci.non_dutiable_amount).to eq BigDecimal("123.45")
      expect(ci.master_bills_of_lading).to eq("MOLU13903762056\n MOLU13903762057")
      expect(ci.house_bills_of_lading).to eq("ABCD1029384756\n ABCD1029384757")
      expect(ci.entered_value_7501).to eq 300

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
      expect(line.related_parties).to be_truthy
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
      expect(line.freight_amount).to eq BigDecimal.new("12.3")
      expect(line.other_amount).to eq BigDecimal.new("45.6")
      expect(line.cash_discount).to eq BigDecimal.new("78.9")
      expect(line.add_to_make_amount).to eq BigDecimal.new("1.23")
      expect(line.value_foreign).to eq BigDecimal.new("999.99")
      expect(line.mpf).to eq 1.23
      expect(line.prorated_mpf).to eq 2.34
      expect(line.hmf).to eq 3.45
      expect(line.cotton_fee).to eq 4.56
      expect(line.add_case_number).to eq '123'
      expect(line.add_bond).to be_truthy
      expect(line.add_duty_amount).to eq 1.23
      expect(line.add_case_value).to eq 2.34
      expect(line.add_case_percent).to eq 3.45
      expect(line.cvd_case_number).to eq '234'
      expect(line.cvd_bond).to be_falsey
      expect(line.cvd_duty_amount).to eq 3.45
      expect(line.cvd_case_value).to eq 4.56
      expect(line.cvd_case_percent).to eq 5.67
      expect(line.container.container_number).to eq "CONT2"
      expect(line.fda_review_date).to be_nil
      expect(line.fda_hold_date).to be_nil
      expect(line.fda_release_date).to be_nil
      expect(line.value_appraisal_method).to eq "F"
      expect(line.first_sale).to be_truthy
      expect(line.non_dutiable_amount).to eq BigDecimal("123.45")
      expect(line.unit_price).to eq BigDecimal("95.23")
      expect(line.other_fees).to eq BigDecimal("15.00")
      expect(line.miscellaneous_discount).to eq BigDecimal("33.44")
      expect(line.psc_reason_code).to eq "L04"
      expect(line.psc_date).to eq tz.parse "201803151200"
      expect(line.agriculture_license_number).to eq "LICENSE NO"

      tariff = line.commercial_invoice_tariffs.first
      expect(tariff.hts_code).to eq "1234567890"
      expect(tariff.duty_advalorem).to eq 1.1
      expect(tariff.duty_specific).to eq 2.2
      expect(tariff.duty_additional).to eq 3.3
      expect(tariff.duty_other).to eq 4.4
      expect(tariff.duty_amount).to eq 11.00
      expect(tariff.entered_value).to eq BigDecimal.new("99.60")
      expect(tariff.entered_value_7501).to eq 100
      expect(tariff.duty_rate).to eq BigDecimal.new("0.037")
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
      expect(tariff.advalorem_rate).to eq BigDecimal("0.50")
      expect(tariff.specific_rate).to eq BigDecimal("1.25")
      expect(tariff.specific_rate_uom).to eq "CM"
      expect(tariff.additional_rate).to eq BigDecimal("3.55")
      expect(tariff.additional_rate_uom).to eq "KG"

      expect(tariff.commercial_invoice_lacey_components.length).to eq 2
      lacey = tariff.commercial_invoice_lacey_components.first
      expect(lacey.line_number).to eq 1
      expect(lacey.detailed_description).to eq "2 IN 1 CONVERTABLE PET STEPS"
      expect(lacey.value).to eq BigDecimal("3099.60")
      expect(lacey.name).to eq "WOOD"
      expect(lacey.quantity).to eq BigDecimal("932.00")
      expect(lacey.unit_of_measure).to eq "KG"
      expect(lacey.genus).to eq "Special"
      expect(lacey.species).to eq "Composite"
      expect(lacey.harvested_from_country).to eq "CN"
      expect(lacey.percent_recycled_material).to eq 0
      expect(lacey.container_numbers).to eq "EMCU9890535\n IMTU1064900\n EGHU1017227"

      lacey = tariff.commercial_invoice_lacey_components.second
      # Just check the things that have different parsing scenarios on the second lacey line
      expect(lacey.line_number).to eq 2
      expect(lacey.percent_recycled_material).to eq BigDecimal("0.02")
      expect(lacey.container_numbers).to be_nil

      tariff = line.commercial_invoice_tariffs.second
      expect(tariff.tariff_description).to eq "REPLACEMENT DESC"

      # There's a couple different scenarios to check out in the second invoice
      ci = entry.commercial_invoices.second
      line = ci.commercial_invoice_lines.first
      expect(line.customs_line_number).to eq 2
      expect(ci.master_bills_of_lading).to be_nil
      expect(ci.house_bills_of_lading).to be_nil

      # This used to parse as 99.99 because it assumed missing decimal points meant there was an implied decimal point,
      # which was wrong and has since been fixed.
      expect(line.contract_amount).to eq BigDecimal.new("9999.00")
      expect(line.value_appraisal_method).to eq "A"
      expect(line.first_sale).to be_falsey

      # If we didn't get a matching container record, then we want to make sure the line level linkage
      # is nil
      line = entry.commercial_invoices.second.commercial_invoice_lines.first
      expect(line.container).to be_nil

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
      expect(entry.fda_pending_release_line_count).to eq 0

      expect(entry.importer).not_to be_nil
      expect(entry.importer.name).to eq entry.customer_name
      expect(entry.importer.alliance_customer_number).to eq entry.customer_number
      expect(entry.importer.importer).to be_truthy
      expect(entry.last_exported_from_source).to eq ActiveSupport::TimeZone["Eastern Time (US & Canada)"].parse "2015-03-12T13:26:20-04:00"

      # This should all be nil because the liquidation date is not set
      expect(entry.liquidation_date).to be_nil
      expect(entry.liquidation_type_code).to be_nil
      expect(entry.liquidation_type).to be_nil
      expect(entry.liquidation_action_code).to be_nil
      expect(entry.liquidation_action_description).to be_nil
      expect(entry.liquidation_extension_code).to be_nil
      expect(entry.liquidation_extension_description).to be_nil
      expect(entry.liquidation_extension_count).to be_nil
      expect(entry.liquidation_duty).to be_nil
      expect(entry.liquidation_fees).to be_nil
      expect(entry.liquidation_tax).to be_nil
      expect(entry.liquidation_ada).to be_nil
      expect(entry.liquidation_cvd).to be_nil
      expect(entry.liquidation_total).to be_nil

      expect(entry.entity_snapshots.length).to eq 1
      snapshot = entry.entity_snapshots.first
      expect(snapshot.user).to eq User.integration

      expect(importer).to have_system_identifier("Customs Management", "TEST")
    end

    it "processes liquidation information if liquidation date is not in the future" do
      @e['dates'] << {'date_no'=>44, 'date'=>201501011230}

      entry = subject.process_entry @e
      entry.reload

      expect(entry.liquidation_date).to eq DateTime.new(2015,1,1,17,30)
      expect(entry.liquidation_type_code).to eq "liq_type"
      expect(entry.liquidation_type).to eq "liq type desc"
      expect(entry.liquidation_action_code).to eq "action_liquidation"
      expect(entry.liquidation_action_description).to eq "liquidation_desc"
      expect(entry.liquidation_extension_code).to eq "extend_suspend_liq"
      expect(entry.liquidation_extension_description).to eq "extension_desc"
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
      entry = subject.process_entry @e
      entry.reload

      expect(entry.daily_statement_number).to eq "astatement"
      expect(entry.monthly_statement_number).to be_nil
    end

    it "identifies split shipments" do
      @e['split'] = "Y"
      entry = subject.process_entry @e
      entry.reload
      expect(entry.split_shipment?).to eq true
    end

    it "skips unused recon flags" do
      @e['recon_nafta'] = "N"
      @e['recon_9802'] = "N"
      @e['recon_value'] = "N"
      entry = subject.process_entry @e
      expect(entry.recon_flags).to eq "CLASS"

      @e['recon_class'] = 'N'
      @e['recon_nafta'] = "Y"
      entry = subject.process_entry @e
      expect(entry.recon_flags).to eq "NAFTA"

      @e['recon_nafta'] = 'N'
      @e['recon_9802'] = "Y"
      entry = subject.process_entry @e
      expect(entry.recon_flags).to eq "9802"

      @e['recon_9802'] = "N"
      @e['recon_value'] = "Y"
      entry = subject.process_entry @e
      expect(entry.recon_flags).to eq "VALUE"
    end

    it "handles 98 date for docs received" do
      @e['dates'] << {'date_no'=>98, 'date'=>201503310000}
      entry = subject.process_entry @e
      expect(entry.docs_received_date).to eq tz.parse("201503310000").to_date
    end

    it "uses earliest it date value" do
      # Put an actual Date value in the entry here so that we're also making sure that
      # the earliest value is handing comparison against the actual entry itself
      e = Factory(:entry, broker_reference: @e['file_no'], source_system: "Alliance", first_it_date: Date.new(2016, 1, 1))
      entry = subject.process_entry @e
      expect(entry.first_it_date).to eq tz.parse("201503011000").to_date
    end

    it "updates an entry using json data" do
      # Make sure the entry has all the components of an existing entry, and that they're
      # all wiped
      t = Factory(:commercial_invoice_tariff)
      e = t.commercial_invoice_line.entry
      e.update_attributes! source_system: "Alliance", broker_reference: "REF"
      @e['file_no'] = e.broker_reference

      line = Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: e, invoice_number: "12345A"))
      Factory(:container, entry: e, container_number: "CONT1")
      e.entry_comments.create! body: "Testing"

      expect(subject).to receive(:process_special_tariffs)

      entry = subject.process_entry @e

      # Make sure the exisitng data was wiped and new data populated
      expect(entry).to be_persisted
      entry.reload
      expect(entry.broker_reference).to eq e.broker_reference
      expect(entry.broker_invoices.size).to eq 1
      expect(entry.broker_invoices.first.invoice_number).to eq "12345A"
      expect(entry.commercial_invoices.size).to eq 2
      expect(entry.commercial_invoices.first.invoice_number).to eq "INV1"
      expect(entry.entry_comments.size).to eq 4
      expect(entry.containers.size).to eq 2
      expect(entry.containers.map{|c| c.container_number}).to include("CONT1")
    end

    it "copies sync records from existing broker invoice to newly created one" do
      e = Factory(:entry, source_system: "Alliance", broker_reference: @e['file_no'])
      line = Factory(:broker_invoice_line, broker_invoice: Factory(:broker_invoice, entry: e, invoice_number: "12345A", customer_number: "CUST1", invoice_total: BigDecimal.new("100.99"), invoice_date: Date.new(2015, 4, 1)),
                        charge_code: "0001", charge_description: "DUTY", charge_amount: BigDecimal("-100.00"), vendor_name: "VENDOR NAME", vendor_reference: "VENDOR", charge_type: "D")
      line_2 = Factory(:broker_invoice_line, broker_invoice: line.broker_invoice, charge_code: "0100", charge_description: "OUTLAY", charge_amount: BigDecimal("0.99"), vendor_name: "", vendor_reference: "", charge_type: "O")
      broker_invoice = line.broker_invoice
      # Ultimately, the reason we're doing this is to make sure we're copying sync records, so bake this into the test case
      sync_record = broker_invoice.sync_records.create! trading_partner: "TESTING", sent_at: Time.zone.now, ftp_session_id: 10

      # Create a second invoice and make sure it gets removed, since it won't be in the json
      Factory(:broker_invoice, entry: e)

      # Create a third invoice just to make sure the s
      broker_invoice_3 = Factory(:broker_invoice, entry: e, invoice_number: "12345")
      broker_invoice_3.sync_records.create! trading_partner: "TEST2", sent_at: Time.zone.now, confirmed_at: Time.zone.now, confirmation_file_name: "file.txt", failure_message:"Message", fingerprint: Time.zone.now, ignore_updates_before: Time.zone.now

      @e['broker_invoices'] << {
        'file_no'=>12345, 'invoice_date'=>20150401, 'total_amount'=>100.99, 'bill_to_cust'=>'CUST1',
        'lines' => [{'charge' => '1', 'description' => 'DUTY', 'amount'=>-10000, 'vendor'=>'VEND', 'vendor_name' => 'VENDOR NAME', 'vendor_ref'=>'VENDOR', 'charge_type'=>'D'}]
      }

      entry = subject.process_entry @e

      expect(entry).to be_persisted
      entry.reload
      expect(entry.broker_invoices.size).to eq 2
      expect(entry.broker_invoices.first.id).not_to eq broker_invoice.id
      expect(entry.broker_invoices.first.invoice_number).to eq "12345A"

      expect(entry.broker_invoices.first.sync_records.first.id).not_to eq sync_record.id
      # make sure the attributes of the sync record were copied over
      expect(entry.broker_invoices.first.sync_records.first.trading_partner).to eq "TESTING"
      expect(entry.broker_invoices.first.sync_records.first.sent_at.to_i).to eq sync_record.sent_at.to_i
      expect(entry.broker_invoices.first.sync_records.first.ftp_session_id).to eq 10

      expect(entry.broker_invoices.second.invoice_number).to eq "12345"
      expect(entry.broker_invoices.second.sync_records.length).to eq 1

      # There was a bug where we were adding destroyed invoice's total amounts into the entry's broker invoice total..make sure it doesn't happen again
      expect(entry.broker_invoice_total).to eq 201.98
    end

    it "uses cross process locking / per entry locking" do
      expect(Lock).to receive(:acquire).with(Lock::ALLIANCE_PARSER).and_yield
      expect(Lock).to receive(:acquire).with("Company-Customs Management-TEST").and_yield
      expect(Lock).to receive(:with_lock_retry).with(instance_of(Entry)).and_yield

      entry = subject.process_entry @e
      expect(entry).to be_persisted
    end

    it "does not update data with a newer last exported from source date" do
      e = Factory(:entry, broker_reference: @e['file_no'], source_system: "Alliance", last_exported_from_source: Time.zone.now)
      expect(subject.process_entry @e).to be_nil
    end

    it "logs an error message if periodic monthly data is missing" do
      @e['pms_year'] = 2016
      expect {subject.process_entry @e}.to change(ErrorLogEntry,:count).by(1)
    end

    it "does not log an error if periodic data is missing and the entry does not have a filed date value" do
      @e['dates'].reject! {|v| v['date_no'] == 16 }

      expect {subject.process_entry @e}.to_not change(ErrorLogEntry,:count)
    end

    it "skips purged entries" do
      EntryPurge.create source_system: "Alliance", broker_reference: @e['file_no'], date_purged: Time.zone.parse("2015-05-01 00:00")
      expect(subject.process_entry @e).to be_nil
      expect(Entry.where(broker_reference: @e['file_no']).first).to be_nil
    end

    it "creates entries if they were purged in the past" do
      EntryPurge.create source_system: "Alliance", broker_reference: @e['file_no'], date_purged: Time.zone.parse("2015-01-01 00:00")
      expect(subject.process_entry @e).not_to be_nil
      expect(Entry.where(broker_reference: @e['file_no']).first).not_to be_nil
    end

    it "parses fda review/hold/release information for multiple lines from notes" do
      @e['notes'] << {'note' => "07/23/15 13:44 AG FDA 01 FDA REVIEW", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507201247}
      @e['notes'] << {'note' => "07/20/15 09:13 AG FDA 02 FDA HOLD", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507211247}
      @e['notes'] << {'note' => "FDA DETAINED USCS Ln 001 THRU 002", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507211247}
      @e['notes'] << {'note' => "07/17/15 17:07 AG FDA 05 FDA RELEASE", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507221247}
      @e['notes'] << {'note' => "FDA RELEASED USCS Ln 001 THRU 002", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507221247}

      @e['commercial_invoices'].first['lines'].first['tariffs'].first['fda'] = 'Y'
      @e['commercial_invoices'].second['lines'].first['tariffs'].first['fda'] = 'Y'

      entry = subject.process_entry @e
      expect(entry.fda_pending_release_line_count).to eq 0

      line = entry.commercial_invoices.first.commercial_invoice_lines.first
      # Values are 4 hours ahead due to timezone translation
      expect(line.fda_review_date).to eq Time.zone.parse("2015-07-20 16:47")
      expect(line.fda_hold_date).to eq Time.zone.parse("2015-07-21 16:47")
      expect(line.fda_release_date).to eq Time.zone.parse("2015-07-22 16:47")

      line = entry.commercial_invoices.second.commercial_invoice_lines.first
      expect(line.fda_review_date).to eq Time.zone.parse("2015-07-20 16:47")
      expect(line.fda_hold_date).to eq Time.zone.parse("2015-07-21 16:47")
      expect(line.fda_release_date).to eq Time.zone.parse("2015-07-22 16:47")
    end

    it "parses fda review hold information one line at a time" do
      @e['notes'] << {'note' => "07/23/15 13:44 AG FDA 01 FDA REVIEW", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507201247}
      @e['notes'] << {'note' => "07/20/15 09:13 AG FDA 02 FDA HOLD", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507211247}
      @e['notes'] << {'note' => "FDA DETAINED USCS Ln 001", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507211247}
      @e['notes'] << {'note' => "FDA DETAINED USCS Ln 002    000", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507211247}
      @e['notes'] << {'note' => "07/17/15 17:07 AG FDA 05 FDA RELEASE", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507221247}
      @e['notes'] << {'note' => "FDA RELEASED USCS Ln 001 THRU 001", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507221247}

      @e['commercial_invoices'].first['lines'].first['tariffs'].first['fda'] = 'Y'
      @e['commercial_invoices'].second['lines'].first['tariffs'].first['fda'] = 'Y'

      entry = subject.process_entry @e

      # Because no release was given for the second line the pending release line count should be 1
      expect(entry.fda_pending_release_line_count).to eq 1

      line = entry.commercial_invoices.first.commercial_invoice_lines.first
      # Values are 4 hours ahead due to timezone translation
      expect(line.fda_review_date).to eq Time.zone.parse("2015-07-20 16:47")
      expect(line.fda_hold_date).to eq Time.zone.parse("2015-07-21 16:47")
      expect(line.fda_release_date).to eq Time.zone.parse("2015-07-22 16:47")

      line = entry.commercial_invoices.second.commercial_invoice_lines.first
      expect(line.fda_review_date).to eq Time.zone.parse("2015-07-20 16:47")
      expect(line.fda_hold_date).to eq Time.zone.parse("2015-07-21 16:47")
      expect(line.fda_release_date).to be_nil
    end

    it "parses review / may proceed messages" do
      @e['notes'] << {'note' => "07/23/15 13:44 AG FDA 01 FDA REVIEW", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507201247}
      @e['notes'] << {'note' => "07/17/15 17:07 AG FDA 06 FDA MAY PROCEED", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507221247}
      @e['notes'] << {'note' => "FDA MAY PROCEED USCS Ln 001 THRU 002", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507221247}

      @e['commercial_invoices'].first['lines'].first['tariffs'].first['fda'] = 'Y'
      @e['commercial_invoices'].second['lines'].first['tariffs'].first['fda'] = 'Y'

      entry = subject.process_entry @e

      # Because no release was given for the second line the pending release line count should be 1
      expect(entry.fda_pending_release_line_count).to eq 0

      line = entry.commercial_invoices.first.commercial_invoice_lines.first
      # Values are 4 hours ahead due to timezone translation
      expect(line.fda_review_date).to eq Time.zone.parse("2015-07-20 16:47")
      expect(line.fda_hold_date).to be_nil
      expect(line.fda_release_date).to eq Time.zone.parse("2015-07-22 16:47")

      line = entry.commercial_invoices.second.commercial_invoice_lines.first
      expect(line.fda_review_date).to eq Time.zone.parse("2015-07-20 16:47")
      expect(line.fda_hold_date).to be_nil
      expect(line.fda_release_date).to eq Time.zone.parse("2015-07-22 16:47")
    end

    it "skips messages that are not modified by customs" do
      # Normally, the following line would set the review date on the lines, but since it's not modified by CUSTOMS, we skip it.
      @e['notes'] << {'note' => "07/23/15 13:44 AG FDA 01 FDA REVIEW", 'modified_by'=>"SOME PERSON", 'date_updated' => 201507201247}

      @e['commercial_invoices'].first['lines'].first['tariffs'].first['fda'] = 'Y'
      @e['commercial_invoices'].second['lines'].first['tariffs'].first['fda'] = 'Y'

      entry = subject.process_entry @e

      expect(entry.fda_pending_release_line_count).to eq 0
      expect(entry.commercial_invoices.first.commercial_invoice_lines.first.fda_review_date).to be_nil
      expect(entry.commercial_invoices.second.commercial_invoice_lines.first.fda_review_date).to be_nil
    end

    it "skips lines that are not marked as FDA lines" do
      # Customs sends ranges on the FDA note records and sometimes the line numbers in that range are not FDA records
      # These lines should not get FDA records set on them then.
      @e['notes'] << {'note' => "07/23/15 13:44 AG FDA 01 FDA REVIEW", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507201247}
      @e['notes'] << {'note' => "07/20/15 09:13 AG FDA 02 FDA HOLD", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507211247}
      @e['notes'] << {'note' => "FDA DETAINED USCS Ln 001 THRU 002", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507211247}
      @e['notes'] << {'note' => "07/17/15 17:07 AG FDA 05 FDA RELEASE", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507221247}
      @e['notes'] << {'note' => "FDA RELEASED USCS Ln 001 THRU 002", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507221247}

      @e['commercial_invoices'].first['lines'].first['tariffs'].first['fda'] = 'Y'

      entry = subject.process_entry @e
      expect(entry.fda_pending_release_line_count).to eq 0

      line = entry.commercial_invoices.first.commercial_invoice_lines.first
      # Values are 4 hours ahead due to timezone translation
      expect(line.fda_review_date).to eq Time.zone.parse("2015-07-20 16:47")
      expect(line.fda_hold_date).to eq Time.zone.parse("2015-07-21 16:47")
      expect(line.fda_release_date).to eq Time.zone.parse("2015-07-22 16:47")

      line = entry.commercial_invoices.second.commercial_invoice_lines.first
      expect(line.fda_review_date).to be_nil
      expect(line.fda_hold_date).to be_nil
      expect(line.fda_release_date).to be_nil
    end

    it "handles FDA line level messages that are not preceeded by header level ones" do
      @e['notes'] << {'note' => "07/23/15 13:44 AG FDA 01 FDA REVIEW", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507201247}
      @e['notes'] << {'note' => "FDA DETAINED USCS Ln 001", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507211247}
      @e['notes'] << {'note' => "FDA EXAM USCS Ln 002    000", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507211247}
      @e['notes'] << {'note' => "FDA RELEASED USCS Ln 001 THRU 001", 'modified_by'=>"CUSTOMS", 'date_updated' => 201507221247}

      @e['commercial_invoices'].first['lines'].first['tariffs'].first['fda'] = 'Y'
      @e['commercial_invoices'].second['lines'].first['tariffs'].first['fda'] = 'Y'

      entry = subject.process_entry @e

      # Because no release was given for the second line the pending release line count should be 1
      expect(entry.fda_pending_release_line_count).to eq 1

      line = entry.commercial_invoices.first.commercial_invoice_lines.first
      # Values are 4 hours ahead due to timezone translation
      expect(line.fda_review_date).to eq Time.zone.parse("2015-07-20 16:47")
      expect(line.fda_hold_date).to eq Time.zone.parse("2015-07-21 16:47")
      expect(line.fda_release_date).to eq Time.zone.parse("2015-07-22 16:47")

      line = entry.commercial_invoices.second.commercial_invoice_lines.first
      expect(line.fda_review_date).to eq Time.zone.parse("2015-07-20 16:47")
      expect(line.fda_hold_date).to eq Time.zone.parse("2015-07-21 16:47")
      expect(line.fda_release_date).to be_nil
    end

    it "clears date values that are no longer sent in updated data" do
      # basically, this just checks that if a date value has been removed from the Kewill data
      # that it gets cleared from VFI Track.
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance")
      standard_dates = [:export_date, :docs_received_date, :file_logged_date, :eta_date, :arrival_date, :release_date, :fda_release_date, :trucker_called_date, :delivery_order_pickup_date,
        :freight_pickup_date, :last_billed_date, :invoice_paid_date, :duty_due_date, :liquidation_date, :daily_statement_due_date, :free_date, :edi_received_date, :fda_transmit_date, :daily_statement_approved_date,
        :final_delivery_date, :worksheet_date, :available_date, :isf_sent_date, :isf_accepted_date, :fda_review_date, :first_release_date, :first_entry_sent_date, :monthly_statement_received_date, :monthly_statement_paid_date]
      first_last_dates = [:first_it_date]

      values = {}
      (standard_dates + first_last_dates).each {|k| values[k] = Date.today}
      entry.update_attributes! values
      @e['dates'] = []

      # Make sure all the dates that should have cleared out did and the ones that didn't did not.
      entry = subject.process_entry @e

      attributes = entry.attributes
      # These values should not be cleared by the fact that there was no json in the data we sent to the process_entry method
      first_last_dates.each {|d| expect(attributes[d.to_s]).not_to be_nil, "expected #{d.to_s} not to be nil, got '#{attributes[d.to_s]}'"}

      # These values all should have been cleared and reparsed from the dates in the json - and since there are no dates in the json we
      # sent in the test, they should all be nil
      standard_dates.each {|d| expect(attributes[d.to_s]).to be_nil, "expected #{d.to_s} to be nil, got '#{attributes[d.to_s]}'"}
    end

    it "uses the earliest CUSTOMS comment for Entry Filed Date" do
      @e['notes'] << {'note' => "Customs Did something", 'modified_by'=>"CUSTOMS", 'date_updated'=>201501191230}
      entry = subject.process_entry @e

      expect(entry.entry_filed_date).to eq tz.parse("201501191230")
    end

    it "falls back to line level container_no attribute if no container is found via sub-elements" do
      @e['commercial_invoices'].first['lines'].first['containers'].first["container_no"] = "NOTACONTAINER"
      entry = subject.process_entry @e
      expect(entry.commercial_invoices.first.commercial_invoice_lines.first.container.container_number).to eq "CONT1"
    end

    it "handles missing quantity value when calculating unit_price" do
      @e['commercial_invoices'].first['lines'].first['qty'] = nil
      entry = subject.process_entry @e
      expect(entry.commercial_invoices.first.commercial_invoice_lines.first.unit_price).to be_nil
    end

    it "handles zero quantity value when calculating unit_price" do
      @e['commercial_invoices'].first['lines'].first['qty'] = 0
      entry = subject.process_entry @e
      expect(entry.commercial_invoices.first.commercial_invoice_lines.first.unit_price).to be_nil
    end

    it "handles missing value when calculating unit price" do
      @e['commercial_invoices'].first['lines'].first['value_us'] = nil
      entry = subject.process_entry @e
      expect(entry.commercial_invoices.first.commercial_invoice_lines.first.unit_price).to eq 0
    end

    it "assigns fiscal month to entry and broker invoice" do
      imp = with_customs_management_id(Factory(:company, fiscal_reference: "ent_release_date"), "TEST")
      fm_1 = Factory(:fiscal_month, company: imp, year: 2015, month_number: 1, start_date: Date.new(2015,3,1), end_date: Date.new(2015,3,31))
      fm_2 = Factory(:fiscal_month, company: imp, year: 2015, month_number: 2, start_date: Date.new(2015,4,1), end_date: Date.new(2015,4,30))

      entry = subject.process_entry @e
      expect(entry.fiscal_date).to eq fm_1.start_date
      expect(entry.fiscal_month).to eq 1
      expect(entry.fiscal_year).to eq 2015
      brok_inv = entry.broker_invoices.first
      expect(brok_inv.fiscal_date).to eq fm_2.start_date
      expect(brok_inv.fiscal_month).to eq 2
      expect(brok_inv.fiscal_year).to eq 2015
    end

    it "does not create entries that have cancelled dates" do
      @e['dates'] << {'date_no'=>5023, 'date'=>201503021000}
      expect(subject.process_entry @e).to be_nil
    end

    it "purges existing entries that have been cancelled" do
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance")

      @e['dates'] << {'date_no'=>5023, 'date'=>201503021000}
      expect(subject.process_entry @e).to be_nil

      expect {entry.reload}.to raise_error ActiveRecord::RecordNotFound

      purge = EntryPurge.where(broker_reference: "12345", source_system: "Alliance").first
      expect(purge).not_to be_nil
      # Verify the purge date is the extract time value
      expect(purge.date_purged).to eq "2015-03-12 17:26:20"
    end

    it "sets summary rejected when TRANSACTION DATA REJECTED is in notes" do
      @e['notes'] << {'note' => "TRANSACTION DATA REJECTED", 'modified_by'=>"CUSTOMS", 'date_updated' => 201603191930, 'confidential' => "Y"}
      entry = subject.process_entry @e
      expect(entry.summary_rejected).to eq true
    end

    it "does not set summary rejected if data rjected note was not set by CUSTOMS" do
      @e['notes'] << {'note' => "TRANSACTION DATA REJECTED", 'modified_by'=>"SOMEDUDE", 'date_updated' => 201603191930, 'confidential' => "Y"}
      entry = subject.process_entry @e
      expect(entry.summary_rejected).to eq false
    end

    it "does not set summary rejected if data rjected note was followed by summary replacement message" do 
      @e['notes'] << {'note' => "TRANSACTION DATA REJECTED", 'modified_by'=>"CUSTOMS", 'date_updated' => 201603191930, 'confidential' => "Y"}
      @e['notes'] << {'note' => "SUMMARY HAS BEEN REPLACED", 'modified_by'=>"CUSTOMS", 'date_updated' => 201603191931, 'confidential' => "Y"}
      entry = subject.process_entry @e
      expect(entry.summary_rejected).to eq false
    end

    it "does not set summary rejected if data rjected note was followed by summary add message" do 
      @e['notes'] << {'note' => "TRANSACTION DATA REJECTED", 'modified_by'=>"CUSTOMS", 'date_updated' => 201603191930, 'confidential' => "Y"}
      @e['notes'] << {'note' => "SUMMARY HAS BEEN ADDED", 'modified_by'=>"CUSTOMS", 'date_updated' => 201603191931, 'confidential' => "Y"}
      entry = subject.process_entry @e
      expect(entry.summary_rejected).to eq false
    end

    it "does sets summary rejected if data rjected note was followed by summary add message by a person" do 
      @e['notes'] << {'note' => "TRANSACTION DATA REJECTED", 'modified_by'=>"CUSTOMS", 'date_updated' => 201603191930, 'confidential' => "Y"}
      @e['notes'] << {'note' => "SUMMARY HAS BEEN ADDED", 'modified_by'=>"APERSON", 'date_updated' => 201603191931, 'confidential' => "Y"}
      entry = subject.process_entry @e
      expect(entry.summary_rejected).to eq true
    end

    it "does not use One USG as the hold release date if a hold is issued after One USG" do
      @e['dates'] << {'date_no'=>91065, 'date'=>201711131200} # ONE USG
      @e['dates'] << {'date_no'=>99616, 'date'=>201711131300} # APHIS HOLD DATE

      entry = subject.process_entry @e
      expect(entry.hold_release_date).to be_nil
      expect(entry.aphis_hold_date).to eq tz.parse "201711131300"
      expect(entry.aphis_hold_release_date).to be_nil
      expect(entry.one_usg_date).to eq tz.parse "201711131200"
    end

    it "clears entry level field accumulations when new json does not have values" do
      entry = Factory(:entry, broker_reference: "12345", source_system: "Alliance", customer_references: "0", commercial_invoice_numbers: "1", mfids: "2", export_country_codes: "3", origin_country_codes: "4", 
        vendor_names: "5", total_units_uoms: "6", special_program_indicators: "7", po_numbers: "8", part_numbers: "9", container_numbers: "10", container_sizes: "11",
        charge_codes: "12", departments: "13", store_names: "14", fcl_lcl: "15", product_lines: "16",
        total_invoiced_value: 17, broker_invoice_total: 18, total_units: 19, total_cvd: 20, total_add: 21, total_non_dutiable_amount: 22, other_fees: 23)

      # By stripping out the containers, invoices, broker_invoices, all the accumulation fields we're setting should be blanked.
      @e['cust_refs'] = []
      @e['containers'] = []
      @e['broker_invoices'] = []
      @e['commercial_invoices'] = []
      @e['post_summary_corrections'] = []
      entry = subject.process_entry @e

      expect(entry.customer_references).to eq ""
      expect(entry.commercial_invoice_numbers).to eq ""
      expect(entry.mfids).to eq ""
      expect(entry.export_country_codes).to eq ""
      expect(entry.origin_country_codes).to eq ""
      expect(entry.vendor_names).to eq ""
      expect(entry.total_units_uoms).to eq ""
      expect(entry.special_program_indicators).to eq ""
      expect(entry.po_numbers).to eq ""
      expect(entry.part_numbers).to eq ""
      expect(entry.container_numbers).to eq ""
      expect(entry.container_sizes).to eq ""
      expect(entry.charge_codes).to eq ""
      expect(entry.commercial_invoice_numbers).to eq ""
      expect(entry.departments).to eq ""
      expect(entry.store_names).to eq ""
      expect(entry.fcl_lcl).to eq ""
      expect(entry.product_lines).to eq ""
      expect(entry.total_invoiced_value).to eq 0
      expect(entry.broker_invoice_total).to eq 0
      expect(entry.total_units).to eq 0
      expect(entry.total_cvd).to eq 0
      expect(entry.total_add).to eq 0
      expect(entry.total_non_dutiable_amount).to eq 0
      expect(entry.other_fees).to eq 0
    end

    it "handles informal MPF fee codes" do
      fee = @e["commercial_invoices"].first["lines"].first["fees"].find {|f| f["customs_fee_code"] == 499}
      fee["customs_fee_code"] = 311


      entry = subject.process_entry @e

      line = entry.commercial_invoices.first.commercial_invoice_lines.first
      expect(line.mpf).to eq 1.23
      expect(line.prorated_mpf).to eq 2.34
    end

    it "reraises deadlock_errors" do
      error = ActiveRecord::TransactionIsolationConflict.new "Deadlock, Shmedlock"
      expect(subject).to receive(:preprocess).and_raise error
      expect { subject.process_entry @e }.to raise_error error
    end

    it "does not attempt to create importers accounts with missing customer numbers" do
      @e['cust_no'] = ""
      entry = subject.process_entry @e
      expect(entry.importer).to be_nil
    end

    it "does not attempt to create importers accounts with missing customer names" do
      @e['cust_name'] = ""
      entry = subject.process_entry @e
      expect(entry.importer).to be_nil
    end

    it "skips files without a file number" do
      @e["file_no"] = nil
      expect(subject.process_entry(@e)).to be_nil
    end

    it "skips files with a 0 file number" do
      @e["file_no"] = "0"
      expect(subject.process_entry(@e)).to be_nil
    end

    context "with statement updates" do
      let (:statement) { DailyStatement.create! statement_number: "bstatement" }
      let! (:statement_entry) { DailyStatementEntry.create! daily_statement_id: statement.id, broker_reference: "12345" }
      let (:entry) { Factory(:entry, broker_reference: "12345", source_system: "Alliance") }

      it "updates statement links" do
        entry = subject.process_entry @e, {key: "file.json", bucket: "bucket"}

        statement_entry.reload
        statement.reload
        expect(statement_entry.entry).to eq entry
        expect(statement_entry.billed_amount).to eq BigDecimal("-100")

        expect(statement.entity_snapshots.length).to eq 1
        snap = statement.entity_snapshots.first
        expect(snap.user).to eq User.integration
        expect(snap.context).to eq "file.json"
      end

      it "does not snapshot statement if nothing changed" do
        statement_entry.update_attributes! billed_amount: BigDecimal("-100"), entry_id: entry.id

        entry = subject.process_entry @e, {key: "file.json", bucket: "bucket"}

        statement.reload
        expect(statement.entity_snapshots.length).to eq 0
      end

      it "snapshots statement if billed amount changes" do
        statement_entry.update_attributes! entry_id: entry.id
        entry = subject.process_entry @e, {key: "file.json", bucket: "bucket"}

        statement.reload
        expect(statement.entity_snapshots.length).to eq 1
      end
    end
  end

  describe "parse" do
    let (:master_setup) { double("MasterSetup") }
    before :each do
      allow(OpenChain::AllianceImagingClient).to receive(:request_images)
      allow(MasterSetup).to receive(:get).and_return master_setup
      allow(master_setup).to receive(:custom_feature?).with("Kewill Imaging").and_return true
    end

    it "reads json, parses it, notifies listeners" do
      json = {entry: {'file_no'=>12345, 'extract_time'=>"2015-04-01 00:00"}}
      entry = Entry.new(broker_reference: "TESTING")
      expect_any_instance_of(described_class).to receive(:process_entry).with(json[:entry], {}).and_return entry

      expect(OpenChain::AllianceImagingClient).to receive(:request_images).with "TESTING", delay_seconds: 600
      expect(entry).to receive(:broadcast_event).with(:save)

      described_class.parse json.to_json
    end

    it "handles a hash instead of json" do
      json = {entry: {'file_no'=>12345, 'extract_time'=>"2015-04-01 00:00"}}.with_indifferent_access
      expect_any_instance_of(described_class).to receive(:process_entry).with(json[:entry], {})
      described_class.parse json
    end

    it "returns if there is no entry wrapped" do
      described_class.parse({})
    end

    it "does not call request images if Kewill Imaging is not enabled" do
      json = {entry: {'file_no'=>12345, 'extract_time'=>"2015-04-01 00:00"}}
      expect(master_setup).to receive(:custom_feature?).with("Kewill Imaging").and_return false
      expect(OpenChain::AllianceImagingClient).not_to receive(:request_images)

      entry = Entry.new(broker_reference: "TESTING")
      expect_any_instance_of(described_class).to receive(:process_entry).with(json[:entry], {}).and_return entry
      described_class.parse json.to_json
    end
  end

  describe OpenChain::CustomHandler::KewillEntryParser::HoldReleaseSetter do
    let(:ent) { Factory(:entry, aphis_hold_date: nil, aphis_hold_release_date: nil) }
    let(:date1) { DateTime.new(2017,3,15) }
    let(:date2) { DateTime.new(2017,3,16)}
    let(:date3) { DateTime.new(2017,3,17)}
    let(:setter) { described_class.new ent }
    
    describe "set_any_hold_date" do
      let(:attribute) { :aphis_hold_date }

      it "sets hold date" do
        setter.set_any_hold_date date1, attribute
        expect(ent.aphis_hold_date).to eq date1
      end
      
      it "also sets corresponding release date to nil (along w/ 'updated' hashes) if hold is already populated" do
        ent.update_attributes!(aphis_hold_date: date2, aphis_hold_release_date: date2)
        setter.updated_before_one_usg = { aphis_hold_release_date: date2 }
        setter.updated_after_one_usg = { aphis_hold_release_date: date2 }

        setter.set_any_hold_date date1, attribute
        expect(ent.aphis_hold_date).to eq date1
        expect(ent.aphis_hold_release_date).to be_nil
        expect(setter.updated_before_one_usg).to be_empty
        expect(setter.updated_after_one_usg).to be_empty
      end

      context "when One USG is already set" do
        it "doesn't clear hold-release if hold is before One USG" do
          ent.update_attributes!(aphis_hold_date: date1, aphis_hold_release_date: date2, one_usg_date: date3)
          setter.updated_before_one_usg = { aphis_hold_release_date: date2 }

          setter.set_any_hold_date date2, attribute
          expect(ent.aphis_hold_date).to eq date2
          expect(ent.aphis_hold_release_date).to eq date2
          expect(setter.updated_before_one_usg).to be_empty
        end

        it "sets hold-release to One USG if blank" do
          ent.update_attributes!(aphis_hold_date: nil, aphis_hold_release_date: nil, one_usg_date: date3)

          setter.set_any_hold_date date2, attribute
          expect(ent.aphis_hold_date).to eq date2
          expect(ent.aphis_hold_release_date).to eq date3
        end

        it "sets date to nil, making no other changes (for testing)" do
          ent.update_attributes!(aphis_hold_date: date1, aphis_hold_release_date: date2, one_usg_date: date3)
          setter.updated_before_one_usg = { aphis_hold_release_date: date2 }
          setter.set_any_hold_date nil, attribute
          expect(ent.aphis_hold_date).to be_nil
          expect(setter.updated_before_one_usg).to eq({ aphis_hold_release_date: date2 })
        end
      end
    end

    describe "set_any_hold_release_date" do
      let(:attribute) { :aphis_hold_release_date }
    
      it "sets release date" do
        ent.update_attributes!(aphis_hold_date: date1)
        setter.set_any_hold_release_date date1, attribute
        expect(ent.aphis_hold_release_date).to eq date1
        expect(setter.updated_before_one_usg).to eq({aphis_hold_release_date: date1})
      end

      it "sets release date to nil if hold date isn't set" do
        setter.set_any_hold_release_date date1, attribute
        expect(ent.aphis_hold_release_date).to be_nil
      end

      it "delegates to #set_one_usg_date if needed" do
        attribute = :one_usg_date
        expect_any_instance_of(described_class).to receive(:set_one_usg_date).with date1
        setter.set_any_hold_release_date date1, attribute
      end

      it "adds to 'updated_after_one_usg' when appropriate" do
        ent.update_attributes!(aphis_hold_date: date1, one_usg_date: date1)
        setter.set_any_hold_release_date date2, attribute
        expect(setter.updated_after_one_usg).to eq({aphis_hold_release_date: date2})
      end

      it "sets date to nil, making no other changes (for testing)" do
        ent.update_attributes!(aphis_hold_date: date1, one_usg_date: date1)
        setter.set_any_hold_release_date nil, attribute
        expect(setter.updated_after_one_usg).to be_empty
      end
    
      context "one_usg_date" do
        let(:attribute) { :one_usg_date }    

        it "sets One USG date" do
          setter.set_any_hold_release_date date1, attribute
          expect(ent.one_usg_date).to eq date1
          expect(setter.updated_before_one_usg).to be_empty
          expect(setter.updated_after_one_usg).to be_empty
        end

        it "also sets the empty release dates of all populated hold dates" do
          ent.update_attributes!(aphis_hold_date: date1, ams_hold_date: date1, ams_hold_release_date: nil, nmfs_hold_date: date1, nmfs_hold_release_date: date1)
          setter.set_any_hold_release_date date2, attribute
          expect(ent.one_usg_date).to eq date2
          expect(ent.aphis_hold_release_date).to eq date2
          expect(ent.ams_hold_release_date).to eq date2
          expect(ent.nmfs_hold_release_date).to eq date1 # unchanged
        end

        it "treats any release date earlier than One USG as if it arrived first" do
          ent.update_attributes!(aphis_hold_date: date1, aphis_hold_release_date: date2, one_usg_date: date3)
          setter.updated_before_one_usg = { aphis_hold_release_date: date2 }
          setter.set_any_hold_release_date date1, :aphis_hold_release_date
          expect(ent.aphis_hold_release_date).to eq date1
          expect(setter.updated_before_one_usg[:aphis_hold_release_date]).to eq date1
          expect(setter.updated_after_one_usg[:aphis_hold_release_date]).to be_nil
        end

        it "sets date to nil, making no other changes (for testing purposes)" do
          ent.update_attributes!(aphis_hold_date: date1, aphis_hold_release_date: date2, one_usg_date: date3)
          setter.updated_before_one_usg = { aphis_hold_release_date: date2 }
          setter.set_any_hold_release_date nil, :one_usg_date
          expect(ent.one_usg_date).to be_nil
          expect(ent.aphis_hold_release_date).to eq date2
          expect(setter.updated_before_one_usg).to eq({ aphis_hold_release_date: date2 })
        end
      end
    end

    describe "set_summary_hold_date" do
      it "assigns the earliest hold date" do
        ent.update_attributes! aphis_hold_date: date1, cbp_hold_date: date2, nmfs_hold_date: date3, hold_date: nil
        setter.entry = ent
        expect{setter.set_summary_hold_date}.to change(ent, :hold_date).from(nil).to date1
      end
    end

    describe "set_summary_hold_release_date" do
      it "assigns nil if entry is on hold" do
        ent.update_attributes! hold_release_date: date1
        expect(ent).to receive(:on_hold?).and_return true
        setter.set_summary_hold_release_date
        expect(ent.hold_release_date).to be_nil
      end

      it "assigns 'One USG One date' if it exists and hasn't been overridden, entry is not on hold, and there is at least one inactive hold" do
        ent.update_attributes! aphis_hold_date: date1, aphis_hold_release_date: date2, one_usg_date: date3
        expect(ent).to receive(:on_hold?).and_return false
        setter.updated_before_one_usg = {aphis_hold_release_date: date2}
        setter.set_summary_hold_release_date
        expect(ent.hold_release_date).to eq date3
      end

      it "if 'One USG date' has been overridden, assign most recent overriding hold-release date" do
        ent.update_attributes! aphis_hold_date: date1, aphis_hold_release_date: date2, one_usg_date: date2
        setter.updated_after_one_usg = { aphis_hold_release_date: date2, nmfs_hold_date: date3}
        setter.set_summary_hold_release_date
        expect(ent.hold_release_date).to eq date3
      end

      it "assigns most recent release date if the entry is not on hold and 'One USG date' is nil" do
        ent.update_attributes! fda_hold_date: date1, fda_hold_release_date: date3, one_usg_date: nil
        expect(ent).to receive(:on_hold?).and_return false
        setter.updated_before_one_usg = {aphis_hold_release_date: date2, fda_hold_release_date: date3}
        setter.set_summary_hold_release_date
        expect(ent.hold_release_date).to eq date3
      end
      
      it "assigns nil if 'One USG date' exists and there are no holds" do
        ent.update_attributes! one_usg_date: date3
        expect(ent).to receive(:on_hold?).and_return false
        setter.set_summary_hold_release_date
        expect(ent.hold_release_date).to be_nil
      end
    end

    describe "set_on_hold" do
      it "returns 'true' if any of the customs hold dates are assigned without a corresponding release date" do
        ent.update_attributes!(aphis_hold_date: date1, on_hold: nil)
        expect{setter.set_on_hold}.to change(ent, :on_hold).from(nil).to true
      end

      it "returns 'false' if no customs hold dates are assigned" do
        ent.update_attributes!(on_hold: true)
        expect{setter.set_on_hold}.to change(ent, :on_hold).from(true).to false
      end

      it "returns 'false' if a customs hold date is assigned with a corresponding release date" do
        ent.update_attributes!(on_hold: true, aphis_hold_date: date1, aphis_hold_release_date: date2)
        expect{setter.set_on_hold}.to change(ent, :on_hold).from(true).to false
      end
    end
  end
end
