describe OpenChain::CustomHandler::Target::TargetCusdecXmlGenerator do
  describe "generate_xml" do
    let!(:target) { with_customs_management_id(Factory(:importer), "TARGEN") }

    it "generates an XML" do
      broker = Factory(:company, name: "Vandegrift Forwarding Co.", broker: true)
      broker.addresses.create!(system_code: "4", name: "Vandegrift Forwarding Co., Inc.", line_1: "180 E Ocean Blvd",
                               line_2: "Suite 270", city: "Long Beach", state: "CA", postal_code: "90802")
      broker.system_identifiers.create!(system: "Filer Code", code: "316")

      entry = Factory(:entry, entry_number: "31679758714", entry_type: "01", broker_reference: "ARGH58285",
                              master_bills_of_lading: "EGLV142050488076Z", lading_port_code: "57035",
                              unlading_port_code: "1401", entry_port_code: "1402", location_of_goods: "M801",
                              location_of_goods_description: "SOMEWHERE", first_it_date: Date.new(2020, 5, 11),
                              last_7501_print: Date.new(2020, 5, 12), export_date: Date.new(2020, 3, 29),
                              release_date: Date.new(2020, 4, 28), arrival_date: Date.new(2020, 4, 29),
                              import_date: Date.new(2020, 4, 30), total_packages: BigDecimal("2552"), bond_type: "8",
                              bond_surety_number: "457", paperless_release: true, importer_tax_id: "27267107400",
                              it_numbers: "it-1\n it-2", transport_mode_code: 11, carrier_code: "EGLV",
                              vessel: "EVER LYRIC", division_number: "004",
                              ult_consignee_name: "Target General Merchandise, Inc.",
                              consignee_address_1: "33 South 6th Street", consignee_address_2: "Mail stop CC-3350",
                              consignee_city: "Minneapolis", consignee_state: "MN", consignee_postal_code: "55402",
                              cotton_fee: BigDecimal("5.1"), recon_flags: "VALUE", pay_type: 7,
                              house_bills_of_lading: "EEEK142050488078\n EEEK142050488079", total_fees: BigDecimal("17.11"),
                              total_taxes: BigDecimal("18.12"), total_duty: BigDecimal("19.13"), mpf: BigDecimal("20.14"),
                              hmf: BigDecimal("21.15"), entered_value: BigDecimal("22.16"))

      inv_1 = entry.commercial_invoices.build(invoice_number: "E1I0954293", customer_reference: "ASX200325",
                                              total_quantity: BigDecimal("5.678"), currency: "USD",
                                              exchange_rate: BigDecimal("100"), invoice_value: BigDecimal("45323.52"),
                                              invoice_value_foreign: BigDecimal("45324.62"),
                                              non_dutiable_amount: BigDecimal("13.31"),
                                              master_bills_of_lading: "EGLV142050488076\n EGLV142050488077", total_quantity_uom: "CL",
                                              house_bills_of_lading: "EEEK142050488080\n EEEK142050488081")
      inv_1_line_1 = inv_1.commercial_invoice_lines.build(prorated_mpf: BigDecimal("100"),
                                                          hmf: BigDecimal("53.33"), add_to_make_amount: BigDecimal("3.5"),
                                                          country_export_code: "CN", cotton_fee: BigDecimal("75.31"),
                                                          po_number: "0082-1561840", related_parties: true, part_number: "021004200-556677",
                                                          unit_price: BigDecimal("8.55"), quantity: BigDecimal("30.00"),
                                                          unit_of_measure: "PCS", ruling_type: "R", ruling_number: "ruling8642",
                                                          freight_amount: BigDecimal("2.61"), country_origin_code: "TH",
                                                          visa_quantity: BigDecimal("98.21"), visa_uom: "AB",
                                                          agriculture_license_number: "agri5588", visa_number: "visa6868",
                                                          add_case_number: "add2020", add_bond: false, add_duty_amount: BigDecimal("22.33"),
                                                          add_case_percent: BigDecimal("8.4"), cvd_case_number: "cvd2121", cvd_bond: true,
                                                          cvd_duty_amount: BigDecimal("33.22"), cvd_case_percent: BigDecimal("9.5"),
                                                          mid: "383878", hmf_rate: BigDecimal(".106"), mpf_rate: BigDecimal(".117"),
                                                          cotton_fee_rate: BigDecimal("12.8"), customs_line_number: 1, department: "20")
      expect(inv_1_line_1).to receive(:duty_plus_fees_amount).and_return(BigDecimal("42.66"))
      Factory(:product, importer_id: target.id, unique_identifier: "021004200-556677", name: "Ava & Viv White 14W Shorts")
      tar_1 = inv_1_line_1.commercial_invoice_tariffs.build(duty_amount: BigDecimal("1000"), gross_weight: 13,
                                                            hts_code: "9506910030", spi_primary: "SP1", spi_secondary: "SP2",
                                                            classification_uom_1: "NO", classification_qty_1: BigDecimal("2578"),
                                                            classification_uom_2: "NP", classification_qty_2: BigDecimal("2579.5"),
                                                            classification_uom_3: "NQ", classification_qty_3: BigDecimal("2580.55"),
                                                            specific_rate: BigDecimal("13.9"), duty_specific: BigDecimal("73.84"),
                                                            advalorem_rate: BigDecimal(".1410"), duty_advalorem: BigDecimal("74.85"),
                                                            additional_rate: BigDecimal("15.11"), duty_additional: BigDecimal("75.86"),
                                                            quota_category: 1111, entered_value: BigDecimal("5323.51"),
                                                            tariff_description: "GYM/PLAYGRND EXERC EQUIP;OTHER")
      tar_1.pga_summaries.build(agency_code: "FDA", program_code: "ADF", agency_processing_code: "FAD",
                                disclaimer_type_code: "DAF", commercial_description: "Strictly Commercial")
      tar_1.pga_summaries.build(agency_code: "FCC", program_code: "CCF", agency_processing_code: "FCC",
                                disclaimer_type_code: "CFC", commercial_description: "Different Description")
      tar_2 = inv_1_line_1.commercial_invoice_tariffs.build(duty_amount: BigDecimal("1444.15"),
                                                            hts_code: "99038815", entered_value: BigDecimal("19.78"))
      tar_2.pga_summaries.build(agency_code: "FDA", program_code: "ADF", agency_processing_code: "FAD", disclaimer_type_code: "DAF")
      inv_1_line_2 = inv_1.commercial_invoice_lines.build(prorated_mpf: BigDecimal("57"),
                                                          hmf: BigDecimal("3.33"), add_to_make_amount: BigDecimal("2"),
                                                          country_export_code: "IN", add_duty_amount: BigDecimal("11.22"),
                                                          cvd_duty_amount: BigDecimal("22.11"), cotton_fee: BigDecimal("13.57"),
                                                          po_number: "0082-1561841", related_parties: false, part_number: "021004201-666777888",
                                                          customs_line_number: 1, ruling_type: "X", ruling_number: "ruling8642")
      inv_1_line_2.commercial_invoice_tariffs.build(hts_code: "9506910030",
                                                    duty_amount: BigDecimal("3040.05"), entered_value: BigDecimal("40000.01"),
                                                    classification_qty_1: BigDecimal(".01"), classification_qty_2: BigDecimal(".02"),
                                                    classification_qty_3: BigDecimal(".03"), duty_specific: BigDecimal(".04"),
                                                    duty_advalorem: BigDecimal(".05"), duty_additional: BigDecimal(".06"))

      inv_2 = entry.commercial_invoices.build(invoice_number: "E1I0954294", master_bills_of_lading: "  ")
      inv_2_line = inv_2.commercial_invoice_lines.build(customs_line_number: 2, related_parties: false)
      tar_3 = inv_2_line.commercial_invoice_tariffs.build(hts_code: "9506910030", entered_value: BigDecimal("3.1"))
      tar_3.pga_summaries.build(agency_code: "FCC", program_code: "CCF", agency_processing_code: "FCC", disclaimer_type_code: "CFC")

      doc = subject.generate_xml entry

      elem_root = doc.root
      expect(elem_root.name).to eq "entryRecord"
      expect(elem_root.text("partnerId")).to eq "MRSKBROK"
      expect(elem_root.text("entryDocumentId")).to eq "316-7975871-4"
      expect(elem_root.text("entryTypeId")).to eq "01"
      expect(elem_root.text("consolidatedEntry")).to eq "N"
      expect(elem_root.text("portOfLoading")).to eq "57035"
      expect(elem_root.text("portOfDischarge")).to eq "1401"
      expect(elem_root.text("portOfEntry")).to eq "1402"
      expect(elem_root.text("locationOfGoodsId")).to eq "M801/SOMEWHERE"
      expect(elem_root.text("inTransitDate")).to eq "20200511"
      expect(elem_root.text("filingDate")).to eq "20200512"
      expect(elem_root.text("merchandiseExportDate")).to eq "20200329"
      expect(elem_root.text("anticipatedEntryDate")).to eq "20200428"
      expect(elem_root.text("merchandiseImportDate")).to eq "20200429"
      expect(elem_root.text("vesselArrivalDate")).to eq "20200430"
      expect(elem_root.text("liquidationDate")).to eq nil
      expect(elem_root.text("totalCartonsQuantity")).to eq "2552"
      expect(elem_root.text("bondTypeCode")).to eq "8"
      expect(elem_root.text("bondId")).to eq "457"
      expect(elem_root.text("teamId")).to eq nil
      expect(elem_root.text("statusRequestCode")).to eq "PPLS"
      expect(elem_root.text("importerIrsId")).to eq "27-267107400"
      expect(elem_root.text("inTransitBondMovementId")).to eq "it-1,it-2"
      expect(elem_root.text("transportModeCode")).to eq "11"
      expect(elem_root.text("carrierScacCode")).to eq "EGLV"
      expect(elem_root.text("vesselName")).to eq "EVER LYRIC"
      expect(elem_root.text("brokerName")).to eq "Vandegrift Forwarding Co., Inc."
      expect(elem_root.text("brokerAddressLine1")).to eq "180 E Ocean Blvd"
      expect(elem_root.text("brokerAddressLine2")).to eq "Suite 270"
      expect(elem_root.text("brokerCityName")).to eq "Long Beach"
      expect(elem_root.text("brokerStateCode")).to eq "CA"
      expect(elem_root.text("brokerZipCode")).to eq "90802"
      expect(elem_root.text("importerName")).to eq "Target General Merchandise, Inc."
      expect(elem_root.text("importerAddressLine1")).to eq "33 South 6th Street"
      expect(elem_root.text("importerAddressLine2")).to eq "Mail stop CC-3350"
      expect(elem_root.text("importerCityName")).to eq "Minneapolis"
      expect(elem_root.text("importerStateCode")).to eq "MN"
      expect(elem_root.text("importerZipCode")).to eq "55402"
      expect(elem_root.text("entryCottonAmount")).to eq "5.10"
      expect(elem_root.text("otherReconIndicator")).to eq "001"
      expect(elem_root.text("portOfEntrySummary")).to eq "1402"
      expect(elem_root.text("paymentTypeIndicator")).to eq "7"

      invoice_elements = elem_root.elements.to_a("invoiceRecord")
      expect(invoice_elements.size).to eq 2

      elem_inv_1 = invoice_elements[0]
      expect(elem_inv_1.text("brokerInvoice")).to eq "ARGH58285"
      expect(elem_inv_1.text("invoiceId")).to eq "ASX-20-0325"
      expect(elem_inv_1.text("invoiceCartonQuantity")).to eq "5.678"
      expect(elem_inv_1.text("merchandiseProcessingFee")).to eq "157.00"
      expect(elem_inv_1.text("harborMaintenanceFee")).to eq "56.66"
      expect(elem_inv_1.text("invoiceCurrencyCode")).to eq "USD"
      expect(elem_inv_1.text("invoiceCurrencyRatePercent")).to eq "100"
      expect(elem_inv_1.text("totalInvoiceValueAmount")).to eq "45323.52"
      expect(elem_inv_1.text("invoiceLocId")).to eq nil
      expect(elem_inv_1.text("invoiceLocFolderId")).to eq nil
      expect(elem_inv_1.text("invoiceForeignValueAmount")).to eq "45324.62"
      expect(elem_inv_1.text("invoiceMakeMarketValueAmount")).to eq "5.50"
      expect(elem_inv_1.text("invoiceNonDutiableChargeAmount")).to eq "13.31"
      expect(elem_inv_1.text("invoiceNetValueAmount")).to eq "45316.81"
      expect(elem_inv_1.text("itemExportCountryCode")).to eq "CN"
      expect(elem_inv_1.text("invoiceDutyAmount")).to eq "5484.20"
      expect(elem_inv_1.text("invoiceAntiDumpingDutiesAmount")).to eq "33.55"
      expect(elem_inv_1.text("invoiceCounterVailingDutiesAmount")).to eq "55.33"
      expect(elem_inv_1.text("invoiceCottonFeeAmount")).to eq "88.88"
      expect(elem_inv_1.text("invoiceTaxAmount")).to eq nil

      elem_bol = elem_inv_1.elements.to_a("bolRecord")[0]
      expect(elem_bol.text("masterBillOfLadingNumber")).to eq "EGLV142050488076,EGLV142050488077"
      expect(elem_bol.text("totalCartonsQuantity")).to eq "5.678"
      expect(elem_bol.text("unitOfMeasure")).to eq "CL"
      expect(elem_bol.text("houseBillNumber")).to eq "EEEK142050488080,EEEK142050488081"
      expect(elem_bol.text("issuerCodeOfHouseBillNumber")).to eq "EGLV"
      expect(elem_bol.text("sourcePurchaseOrderId")).to eq "0020-0082-1561840"
      expect(elem_bol.text("relatedParty")).to eq "Y"

      invoice_line_elements = elem_inv_1.elements.to_a("itemRecord")
      expect(invoice_line_elements.size).to eq 2

      elem_item_1 = invoice_line_elements[0]
      expect(elem_item_1.text("departmentClassItem")).to eq "021004200"
      expect(elem_item_1.text("itemCostAmount")).to eq "8.55"
      expect(elem_item_1.text("itemCostUom")).to eq "PE"
      expect(elem_item_1.text("itemRoyaltiesAmount")).to eq nil
      expect(elem_item_1.text("itemBuyingCommissionAmount")).to eq nil
      expect(elem_item_1.text("itemDutyAmount")).to eq "42.66"
      expect(elem_item_1.text("itemForeighTradeZoneCode")).to eq nil
      expect(elem_item_1.text("itemForeignTradeZoneDate")).to eq nil
      expect(elem_item_1.text("itemQuantity")).to eq "30"
      expect(elem_item_1.text("itemQuantityUom")).to eq "PCS"
      expect(elem_item_1.text("itemBindRuleId")).to eq "ruling8642"
      expect(elem_item_1.text("totalItemcartonQuantity")).to eq "0"
      expect(elem_item_1.text("dpciItemDescription")).to eq "Ava & Viv White 14W Shorts"
      expect(elem_item_1.text("itemFreightAmount")).to eq "2.61"
      expect(elem_item_1.text("itemWeight")).to eq "13"
      expect(elem_item_1.text("itemUomCode")).to eq "K"

      invoice_tariff_elements = elem_item_1.elements.to_a("itemTariffRecord")
      expect(invoice_tariff_elements.size).to eq 2

      elem_tariff_1 = invoice_tariff_elements[0]
      expect(elem_tariff_1.text("tariffSeqId")).to eq "1"
      expect(elem_tariff_1.text("tariffId")).to eq "9506.91.0030"
      expect(elem_tariff_1.text("primaryTariffId")).to eq nil
      expect(elem_tariff_1.text("itemOriginatingCountryCode")).to eq "TH"
      expect(elem_tariff_1.text("spi1")).to eq "SP1"
      expect(elem_tariff_1.text("spi2")).to eq "SP2"
      expect(elem_tariff_1.text("spi3")).to eq nil
      expect(elem_tariff_1.text("visaQuantity")).to eq "98.21"
      expect(elem_tariff_1.text("visaUom")).to eq "AB"
      expect(elem_tariff_1.text("agricultureLicenseNumber")).to eq "agri5588"
      expect(elem_tariff_1.text("itemVisaId")).to eq "visa6868"
      expect(elem_tariff_1.text("hsQuantityUomCode1")).to eq "NO"
      expect(elem_tariff_1.text("hsQuantity1")).to eq "2578"
      expect(elem_tariff_1.text("hsQuantityUomCode2")).to eq "NP"
      expect(elem_tariff_1.text("hsQuantity2")).to eq "2579.5"
      expect(elem_tariff_1.text("hsQuantityUomCode3")).to eq "NQ"
      expect(elem_tariff_1.text("hsQuantity3")).to eq "2580.55"
      expect(elem_tariff_1.text("itemAddCaseId")).to eq "add2020"
      expect(elem_tariff_1.text("itemAddBondId")).to eq "N"
      expect(elem_tariff_1.text("itemAddTax")).to eq "22.33"
      expect(elem_tariff_1.text("itemAddRate")).to eq "8.4"
      expect(elem_tariff_1.text("itemCvdCaseId")).to eq "cvd2121"
      expect(elem_tariff_1.text("itemCvdBondId")).to eq "Y"
      expect(elem_tariff_1.text("itemCvdTax")).to eq "33.22"
      expect(elem_tariff_1.text("itemCvdRate")).to eq "9.5"
      expect(elem_tariff_1.text("htsManufactureId")).to eq "383878"
      expect(elem_tariff_1.text("harmonizedScheduleLineId")).to eq "001"

      item_tariff_duty_elements = elem_tariff_1.elements.to_a("itemTariffDutyRecord")
      expect(item_tariff_duty_elements.size).to eq 8

      elem_item_tariff_duty_1 = item_tariff_duty_elements[0]
      expect(elem_item_tariff_duty_1.text("dutyTypeCode")).to eq "ADD"
      expect(elem_item_tariff_duty_1.text("hsRatePercentage")).to eq "8.4"
      expect(elem_item_tariff_duty_1.text("rateAmount")).to eq "22.33"

      elem_item_tariff_duty_2 = item_tariff_duty_elements[1]
      expect(elem_item_tariff_duty_2.text("dutyTypeCode")).to eq "CVD"
      expect(elem_item_tariff_duty_2.text("hsRatePercentage")).to eq "9.5"
      expect(elem_item_tariff_duty_2.text("rateAmount")).to eq "33.22"

      elem_item_tariff_duty_3 = item_tariff_duty_elements[2]
      expect(elem_item_tariff_duty_3.text("dutyTypeCode")).to eq "HMF"
      expect(elem_item_tariff_duty_3.text("hsRatePercentage")).to eq "10.6"
      expect(elem_item_tariff_duty_3.text("rateAmount")).to eq "53.33"

      elem_item_tariff_duty_4 = item_tariff_duty_elements[3]
      expect(elem_item_tariff_duty_4.text("dutyTypeCode")).to eq "MPF"
      expect(elem_item_tariff_duty_4.text("hsRatePercentage")).to eq "11.7"
      expect(elem_item_tariff_duty_4.text("rateAmount")).to eq "100.00"

      elem_item_tariff_duty_5 = item_tariff_duty_elements[4]
      expect(elem_item_tariff_duty_5.text("dutyTypeCode")).to eq "COF"
      expect(elem_item_tariff_duty_5.text("hsRatePercentage")).to eq "12.8"
      expect(elem_item_tariff_duty_5.text("rateAmount")).to eq "75.31"

      elem_item_tariff_duty_6 = item_tariff_duty_elements[5]
      expect(elem_item_tariff_duty_6.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_item_tariff_duty_6.text("hsRatePercentage")).to eq "13.9"
      expect(elem_item_tariff_duty_6.text("rateAmount")).to eq "73.84"

      elem_item_tariff_duty_7 = item_tariff_duty_elements[6]
      expect(elem_item_tariff_duty_7.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_item_tariff_duty_7.text("hsRatePercentage")).to eq "14.1"
      expect(elem_item_tariff_duty_7.text("rateAmount")).to eq "74.85"

      elem_item_tariff_duty_8 = item_tariff_duty_elements[7]
      expect(elem_item_tariff_duty_8.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_item_tariff_duty_8.text("hsRatePercentage")).to eq "15.11"
      expect(elem_item_tariff_duty_8.text("rateAmount")).to eq "75.86"

      elem_tariff_1_pga_data = elem_tariff_1.elements.to_a("pgaData")
      expect(elem_tariff_1_pga_data.length).to eq 1
      expect(elem_tariff_1_pga_data[0].text("commercialDescription")).to eq "Strictly Commercial"

      elem_tariff_1_pga01_data = elem_tariff_1_pga_data[0].elements.to_a("pg01Data")
      expect(elem_tariff_1_pga01_data.length).to eq 2

      elem_tariff_1_pga_1 = elem_tariff_1_pga01_data[0]
      expect(elem_tariff_1_pga_1.text("lineNumber")).to eq "1"
      expect(elem_tariff_1_pga_1.text("governmentAgencyCode")).to eq "FDA"
      expect(elem_tariff_1_pga_1.text("governmentAgencyProgramCode")).to eq "ADF"
      expect(elem_tariff_1_pga_1.text("governmentAgencyProcessingCode")).to eq "FAD"
      expect(elem_tariff_1_pga_1.text("disclaimerFlag")).to eq "DAF"

      elem_tariff_1_pga_2 = elem_tariff_1_pga01_data[1]
      expect(elem_tariff_1_pga_2.text("lineNumber")).to eq "2"
      expect(elem_tariff_1_pga_2.text("governmentAgencyCode")).to eq "FCC"

      elem_tariff_2 = invoice_tariff_elements[1]
      expect(elem_tariff_2.text("tariffSeqId")).to eq "2"
      expect(elem_tariff_2.text("tariffId")).to eq "9903.88.15"
      expect(elem_tariff_2.text("harmonizedScheduleLineId")).to eq "001"

      elem_tariff_2_pga_data = elem_tariff_2.elements.to_a("pgaData")
      elem_tariff_2_pga01_data = elem_tariff_2_pga_data[0].elements.to_a("pg01Data")
      expect(elem_tariff_2_pga01_data[0].text("lineNumber")).to eq "3"

      elem_item_2 = invoice_line_elements[1]
      expect(elem_item_2.text("departmentClassItem")).to eq "021004201"
      expect(elem_item_2.text("itemBindRuleId")).to eq nil

      invoice_tariff_elements_2 = elem_item_2.elements.to_a("itemTariffRecord")
      expect(invoice_tariff_elements_2.size).to eq 1
      elem_tariff_3 = invoice_tariff_elements_2[0]
      expect(elem_tariff_3.text("tariffSeqId")).to eq "3"
      expect(elem_tariff_3.text("harmonizedScheduleLineId")).to eq "001"

      elem_inv_2 = invoice_elements[1]
      expect(elem_inv_2.text("brokerInvoice")).to eq "ARGH58285"
      expect(elem_inv_2.elements.to_a("bolRecord")[0].text("relatedParty")).to eq "N"

      elem_bol_2 = elem_inv_2.elements.to_a("bolRecord")[0]
      expect(elem_bol_2.text("masterBillOfLadingNumber")).to eq "E1I0954294"
      expect(elem_bol_2.text("houseBillNumber")).to be_nil
      expect(elem_bol_2.text("issuerCodeOfHouseBillNumber")).to be_nil

      invoice_line_elements_2 = elem_inv_2.elements.to_a("itemRecord")
      expect(invoice_line_elements_2.size).to eq 1

      elem_item_3 = invoice_line_elements_2[0]
      invoice_tariff_elements_3 = elem_item_3.elements.to_a("itemTariffRecord")
      expect(invoice_tariff_elements_3.size).to eq 1

      elem_tariff_4 = invoice_tariff_elements_3[0]
      expect(elem_tariff_4.text("tariffSeqId")).to eq "4"
      expect(elem_tariff_4.text("harmonizedScheduleLineId")).to eq "002"

      elem_tariff_4_pga_data = elem_tariff_4.elements.to_a("pgaData")
      elem_tariff_4_pga01_data = elem_tariff_4_pga_data[0].elements.to_a("pg01Data")
      expect(elem_tariff_4_pga01_data[0].text("lineNumber")).to eq "1"

      tariff_header_elements = elem_inv_1.elements.to_a("tariffHeaderRecord")
      expect(tariff_header_elements.size).to eq 2

      elem_tariff_header_1 = tariff_header_elements[0]
      expect(elem_tariff_header_1.text("harmonizedScheduleLineId")).to eq "001"
      expect(elem_tariff_header_1.text("tariffId")).to eq "9506.91.0030"
      expect(elem_tariff_header_1.text("primaryTariffId")).to eq nil
      expect(elem_tariff_header_1.text("htsQuotaCategoryId")).to eq "1111"
      expect(elem_tariff_header_1.text("valueAmount")).to eq "45323.52"
      expect(elem_tariff_header_1.text("classCode")).to eq nil
      expect(elem_tariff_header_1.text("hsQuantityUom1")).to eq "NO"
      expect(elem_tariff_header_1.text("hsQuantity1")).to eq "2578.01"
      expect(elem_tariff_header_1.text("hsQuantityUom2")).to eq "NP"
      expect(elem_tariff_header_1.text("hsQuantity2")).to eq "2579.52"
      expect(elem_tariff_header_1.text("hsQuantityUom3")).to eq "NQ"
      expect(elem_tariff_header_1.text("hsQuantity3")).to eq "2580.58"
      expect(elem_tariff_header_1.text("tariffDescription")).to eq "GYM/PLAYGRND EXERC EQUIP;OTHER"

      tariff_duty_elements = elem_tariff_header_1.elements.to_a("tariffDutyRecord")
      expect(tariff_duty_elements.size).to eq 8

      elem_tariff_duty_1 = tariff_duty_elements[0]
      expect(elem_tariff_duty_1.text("tariffId")).to eq "9506.91.0030"
      expect(elem_tariff_duty_1.text("dutyTypeCode")).to eq "ADD"
      expect(elem_tariff_duty_1.text("hsRatePercentage")).to eq "8.4"
      expect(elem_tariff_duty_1.text("rateAmount")).to eq "22.33"

      elem_tariff_duty_2 = tariff_duty_elements[1]
      expect(elem_tariff_duty_2.text("dutyTypeCode")).to eq "CVD"
      expect(elem_tariff_duty_2.text("hsRatePercentage")).to eq "9.5"
      expect(elem_tariff_duty_2.text("rateAmount")).to eq "33.22"

      elem_tariff_duty_3 = tariff_duty_elements[2]
      expect(elem_tariff_duty_3.text("dutyTypeCode")).to eq "HMF"
      expect(elem_tariff_duty_3.text("hsRatePercentage")).to eq "10.6"
      expect(elem_tariff_duty_3.text("rateAmount")).to eq "53.33"

      elem_tariff_duty_4 = tariff_duty_elements[3]
      expect(elem_tariff_duty_4.text("dutyTypeCode")).to eq "MPF"
      expect(elem_tariff_duty_4.text("hsRatePercentage")).to eq "11.7"
      expect(elem_tariff_duty_4.text("rateAmount")).to eq "100.00"

      elem_tariff_duty_5 = tariff_duty_elements[4]
      expect(elem_tariff_duty_5.text("dutyTypeCode")).to eq "COF"
      expect(elem_tariff_duty_5.text("hsRatePercentage")).to eq "12.8"
      expect(elem_tariff_duty_5.text("rateAmount")).to eq "75.31"

      elem_tariff_duty_6 = tariff_duty_elements[5]
      expect(elem_tariff_duty_6.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_tariff_duty_6.text("hsRatePercentage")).to eq "13.9"
      expect(elem_tariff_duty_6.text("rateAmount")).to eq "73.88"

      elem_tariff_duty_7 = tariff_duty_elements[6]
      expect(elem_tariff_duty_7.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_tariff_duty_7.text("hsRatePercentage")).to eq "14.1"
      expect(elem_tariff_duty_7.text("rateAmount")).to eq "74.90"

      elem_tariff_duty_8 = tariff_duty_elements[7]
      expect(elem_tariff_duty_8.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_tariff_duty_8.text("hsRatePercentage")).to eq "15.11"
      expect(elem_tariff_duty_8.text("rateAmount")).to eq "75.92"

      elem_tariff_header_2 = tariff_header_elements[1]
      expect(elem_tariff_header_2.text("harmonizedScheduleLineId")).to eq "001"
      expect(elem_tariff_header_2.text("tariffId")).to eq "9903.88.15"
      expect(elem_tariff_header_2.text("valueAmount")).to eq "19.78"

      tariff_header_elements_2 = elem_inv_2.elements.to_a("tariffHeaderRecord")
      expect(tariff_header_elements_2.size).to eq 1

      elem_tariff_header_3 = tariff_header_elements_2[0]
      expect(elem_tariff_header_3.text("harmonizedScheduleLineId")).to eq "002"
      expect(elem_tariff_header_3.text("tariffId")).to eq "9506.91.0030"
      expect(elem_tariff_header_3.text("valueAmount")).to eq "3.10"

      elem_summary = elem_root.elements.to_a("summaryRecord")[0]
      expect(elem_summary.text("totalDutyAmount")).to eq "54.36"
      expect(elem_summary.text("entryOtherAmount")).to eq "17.11"
      expect(elem_summary.text("entryTaxAmount")).to eq "18.12"
      expect(elem_summary.text("entryDutyAmount")).to eq "19.13"
      expect(elem_summary.text("entryMerchandiseProcessingFeeAmount")).to eq "20.14"
      expect(elem_summary.text("entryHarborMaintenanceFeeAmount")).to eq "21.15"
      expect(elem_summary.text("totalEntryValueAmount")).to eq "22.16"
    end

    it "handles assorted nil and missing values" do
      entry = Factory(:entry, entry_number: "31679758714")
      inv = entry.commercial_invoices.build(invoice_number: "E1I0954293")
      inv_line = inv.commercial_invoice_lines.build(customs_line_number: 1)
      inv_line.commercial_invoice_tariffs.build(hts_code: "9506910030")

      doc = subject.generate_xml entry

      elem_root = doc.root
      expect(elem_root.text("inTransitDate")).to eq nil
      expect(elem_root.text("filingDate")).to eq nil
      expect(elem_root.text("merchandiseExportDate")).to eq nil
      expect(elem_root.text("anticipatedEntryDate")).to eq nil
      expect(elem_root.text("merchandiseImportDate")).to eq nil
      expect(elem_root.text("vesselArrivalDate")).to eq nil
      expect(elem_root.text("liquidationDate")).to eq nil
      expect(elem_root.text("importerIrsId")).to eq nil
      expect(elem_root.text("brokerName")).to eq nil
      expect(elem_root.text("brokerAddressLine1")).to eq nil
      expect(elem_root.text("brokerAddressLine2")).to eq nil
      expect(elem_root.text("brokerCityName")).to eq nil
      expect(elem_root.text("brokerStateCode")).to eq nil
      expect(elem_root.text("brokerZipCode")).to eq nil
      expect(elem_root.text("otherReconIndicator")).to eq nil
      expect(elem_root.text("paymentTypeIndicator")).to eq nil

      elem_inv = elem_root.elements.to_a("invoiceRecord")[0]
      expect(elem_inv.text("invoiceId")).to eq nil
      expect(elem_inv.text("merchandiseProcessingFee")).to eq "0.00"
      expect(elem_inv.text("harborMaintenanceFee")).to eq "0.00"
      expect(elem_inv.text("invoiceMakeMarketValueAmount")).to eq "0.00"
      expect(elem_inv.text("invoiceNetValueAmount")).to eq "0.00"
      expect(elem_inv.text("invoiceDutyAmount")).to eq "0.00"
      expect(elem_inv.text("invoiceAntiDumpingDutiesAmount")).to eq "0.00"
      expect(elem_inv.text("invoiceCounterVailingDutiesAmount")).to eq "0.00"
      expect(elem_inv.text("invoiceCottonFeeAmount")).to eq "0.00"

      elem_bol = elem_inv.elements.to_a("bolRecord")[0]
      expect(elem_bol.text("sourcePurchaseOrderId")).to eq ""

      elem_item = elem_inv.elements.to_a("itemRecord")[0]
      expect(elem_item.text("itemBindRuleId")).to eq nil
      expect(elem_item.text("dpciItemDescription")).to eq nil
      expect(elem_item.text("itemWeight")).to eq "0"

      elem_tariff = elem_item.elements.to_a("itemTariffRecord")[0]
      expect(elem_tariff.elements.to_a("hsQuantityUomCode1").length).to eq 0
      expect(elem_tariff.elements.to_a("hsQuantity1").length).to eq 0
      expect(elem_tariff.elements.to_a("hsQuantityUomCode2").length).to eq 0
      expect(elem_tariff.elements.to_a("hsQuantity2").length).to eq 0
      expect(elem_tariff.elements.to_a("hsQuantityUomCode3").length).to eq 0
      expect(elem_tariff.elements.to_a("hsQuantity3").length).to eq 0

      item_tariff_duty_elements = elem_tariff.elements.to_a("itemTariffDutyRecord")
      expect(item_tariff_duty_elements.size).to eq 0

      expect(elem_tariff.elements.to_a("pgaData").length).to eq 0

      elem_tariff_header = elem_inv.elements.to_a("tariffHeaderRecord")[0]
      expect(elem_tariff_header.text("valueAmount")).to eq "0.00"
      expect(elem_tariff_header.elements.to_a("hsQuantityUom1").length).to eq 0
      expect(elem_tariff_header.elements.to_a("hsQuantity1").length).to eq 0
      expect(elem_tariff_header.elements.to_a("hsQuantityUom2").length).to eq 0
      expect(elem_tariff_header.elements.to_a("hsQuantity2").length).to eq 0
      expect(elem_tariff_header.elements.to_a("hsQuantityUom3").length).to eq 0
      expect(elem_tariff_header.elements.to_a("hsQuantity3").length).to eq 0

      tariff_duty_elements = elem_tariff_header.elements.to_a("tariffDutyRecord")
      expect(tariff_duty_elements.size).to eq 0
    end

    it "shows consolidatedEntry value of 'Y' when multiple bills of lading present" do
      entry = Factory(:entry, entry_number: "31679758714", master_bills_of_lading: "A\n B")
      entry.commercial_invoices.build(invoice_number: "E1I0954293")

      doc = subject.generate_xml entry

      elem_root = doc.root
      expect(elem_root.text("consolidatedEntry")).to eq "Y"
    end

    it "defaults broker address to Baltimore if no division match" do
      broker = Factory(:company, name: "Vandegrift Forwarding Co.", broker: true)
      broker.addresses.create!(system_code: "10", name: "Vandegrift Forwarding Co., Inc.", line_1: "20 South Charles Street",
                               line_2: "STE 501", city: "Baltimore", state: "MD", postal_code: "21201")
      broker.system_identifiers.create!(system: "Filer Code", code: "316")

      entry = Factory(:entry, entry_number: "31679758714", division_number: "004")

      doc = subject.generate_xml entry

      elem_root = doc.root
      expect(elem_root.text("brokerName")).to eq "Vandegrift Forwarding Co., Inc."
      expect(elem_root.text("brokerAddressLine1")).to eq "20 South Charles Street"
      expect(elem_root.text("brokerAddressLine2")).to eq "STE 501"
      expect(elem_root.text("brokerCityName")).to eq "Baltimore"
      expect(elem_root.text("brokerStateCode")).to eq "MD"
      expect(elem_root.text("brokerZipCode")).to eq "21201"
    end

    it "shows statusRequestCode value of 'DOCS' when not paperless release" do
      entry = Factory(:entry, entry_number: "31679758714", paperless_release: false)

      doc = subject.generate_xml entry

      elem_root = doc.root
      expect(elem_root.text("statusRequestCode")).to eq "DOCS"
    end

    it "shows paymentTypeIndicator value of nil when pay type is 0" do
      entry = Factory(:entry, entry_number: "31679758714", pay_type: nil)

      doc = subject.generate_xml entry

      elem_root = doc.root
      expect(elem_root.text("paymentTypeIndicator")).to eq nil
    end

    it "handles abnormal invoice customer ref" do
      entry = Factory(:entry, entry_number: "31679758714")
      entry.commercial_invoices.build(invoice_number: "E1I0954293", customer_reference: "SHORT")

      doc = subject.generate_xml entry

      elem_inv = doc.root.elements.to_a("invoiceRecord")[0]
      expect(elem_inv.text("invoiceId")).to eq "SHORT"
    end

    it "rounds money fields" do
      entry = Factory(:entry, entry_number: "31679758714", cotton_fee: BigDecimal("5.095"))
      inv = entry.commercial_invoices.build(invoice_number: "E1I0954293", invoice_value: BigDecimal("45323.516"),
                                            invoice_value_foreign: BigDecimal("45324.617"),
                                            non_dutiable_amount: BigDecimal("13.308"))
      inv_line = inv.commercial_invoice_lines.build(customs_line_number: 1, prorated_mpf: BigDecimal("99.999"),
                                                    hmf: BigDecimal("53.328"), add_to_make_amount: BigDecimal("3.495"),
                                                    cotton_fee: BigDecimal("75.309"), unit_price: BigDecimal("8.546"),
                                                    freight_amount: BigDecimal("2.605"), add_duty_amount: BigDecimal("22.327"),
                                                    add_case_percent: BigDecimal("8.396"), cvd_duty_amount: BigDecimal("33.218"))
      expect(inv_line).to receive(:duty_plus_fees_amount).and_return(BigDecimal("42.656"))
      inv_line.commercial_invoice_tariffs.build(hts_code: "9506910030", duty_amount: BigDecimal("999.997"),
                                                duty_specific: BigDecimal("73.838"), duty_advalorem: BigDecimal("74.848"),
                                                duty_additional: BigDecimal("75.856"), entered_value: BigDecimal("5323.509"))

      doc = subject.generate_xml entry

      elem_root = doc.root
      expect(elem_root.text("entryCottonAmount")).to eq "5.10"

      elem_inv = elem_root.elements.to_a("invoiceRecord")[0]
      expect(elem_inv.text("merchandiseProcessingFee")).to eq "100.00"
      expect(elem_inv.text("harborMaintenanceFee")).to eq "53.33"
      expect(elem_inv.text("totalInvoiceValueAmount")).to eq "45323.52"
      expect(elem_inv.text("invoiceForeignValueAmount")).to eq "45324.62"
      expect(elem_inv.text("invoiceMakeMarketValueAmount")).to eq "3.50"
      expect(elem_inv.text("invoiceNonDutiableChargeAmount")).to eq "13.31"
      expect(elem_inv.text("invoiceNetValueAmount")).to eq "45314.81"
      expect(elem_inv.text("invoiceDutyAmount")).to eq "1000.00"
      expect(elem_inv.text("invoiceAntiDumpingDutiesAmount")).to eq "22.33"
      expect(elem_inv.text("invoiceCounterVailingDutiesAmount")).to eq "33.22"
      expect(elem_inv.text("invoiceCottonFeeAmount")).to eq "75.31"

      elem_item = elem_inv.elements.to_a("itemRecord")[0]
      expect(elem_item.text("itemCostAmount")).to eq "8.55"
      expect(elem_item.text("itemDutyAmount")).to eq "42.66"
      expect(elem_item.text("itemFreightAmount")).to eq "2.61"

      elem_tariff = elem_item.elements.to_a("itemTariffRecord")[0]
      expect(elem_tariff.text("itemAddTax")).to eq "22.33"
      expect(elem_tariff.text("itemCvdTax")).to eq "33.22"

      item_tariff_duty_elements = elem_tariff.elements.to_a("itemTariffDutyRecord")
      expect(item_tariff_duty_elements.size).to eq 8

      elem_item_tariff_duty_1 = item_tariff_duty_elements[0]
      expect(elem_item_tariff_duty_1.text("dutyTypeCode")).to eq "ADD"
      expect(elem_item_tariff_duty_1.text("rateAmount")).to eq "22.33"

      elem_item_tariff_duty_2 = item_tariff_duty_elements[1]
      expect(elem_item_tariff_duty_2.text("dutyTypeCode")).to eq "CVD"
      expect(elem_item_tariff_duty_2.text("rateAmount")).to eq "33.22"

      elem_item_tariff_duty_3 = item_tariff_duty_elements[2]
      expect(elem_item_tariff_duty_3.text("dutyTypeCode")).to eq "HMF"
      expect(elem_item_tariff_duty_3.text("rateAmount")).to eq "53.33"

      elem_item_tariff_duty_4 = item_tariff_duty_elements[3]
      expect(elem_item_tariff_duty_4.text("dutyTypeCode")).to eq "MPF"
      expect(elem_item_tariff_duty_4.text("rateAmount")).to eq "100.00"

      elem_item_tariff_duty_5 = item_tariff_duty_elements[4]
      expect(elem_item_tariff_duty_5.text("dutyTypeCode")).to eq "COF"
      expect(elem_item_tariff_duty_5.text("rateAmount")).to eq "75.31"

      elem_item_tariff_duty_6 = item_tariff_duty_elements[5]
      expect(elem_item_tariff_duty_6.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_item_tariff_duty_6.text("rateAmount")).to eq "73.84"

      elem_item_tariff_duty_7 = item_tariff_duty_elements[6]
      expect(elem_item_tariff_duty_7.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_item_tariff_duty_7.text("rateAmount")).to eq "74.85"

      elem_item_tariff_duty_8 = item_tariff_duty_elements[7]
      expect(elem_item_tariff_duty_8.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_item_tariff_duty_8.text("rateAmount")).to eq "75.86"

      elem_tariff_header = elem_inv.elements.to_a("tariffHeaderRecord")[0]
      expect(elem_tariff_header.text("valueAmount")).to eq "5323.51"

      tariff_duty_elements = elem_tariff_header.elements.to_a("tariffDutyRecord")
      expect(tariff_duty_elements.size).to eq 8

      elem_tariff_duty_1 = tariff_duty_elements[0]
      expect(elem_tariff_duty_1.text("dutyTypeCode")).to eq "ADD"
      expect(elem_tariff_duty_1.text("rateAmount")).to eq "22.33"

      elem_tariff_duty_2 = tariff_duty_elements[1]
      expect(elem_tariff_duty_2.text("dutyTypeCode")).to eq "CVD"
      expect(elem_tariff_duty_2.text("rateAmount")).to eq "33.22"

      elem_tariff_duty_3 = tariff_duty_elements[2]
      expect(elem_tariff_duty_3.text("dutyTypeCode")).to eq "HMF"
      expect(elem_tariff_duty_3.text("rateAmount")).to eq "53.33"

      elem_tariff_duty_4 = tariff_duty_elements[3]
      expect(elem_tariff_duty_4.text("dutyTypeCode")).to eq "MPF"
      expect(elem_tariff_duty_4.text("rateAmount")).to eq "100.00"

      elem_tariff_duty_5 = tariff_duty_elements[4]
      expect(elem_tariff_duty_5.text("dutyTypeCode")).to eq "COF"
      expect(elem_tariff_duty_5.text("rateAmount")).to eq "75.31"

      elem_tariff_duty_6 = tariff_duty_elements[5]
      expect(elem_tariff_duty_6.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_tariff_duty_6.text("rateAmount")).to eq "73.84"

      elem_tariff_duty_7 = tariff_duty_elements[6]
      expect(elem_tariff_duty_7.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_tariff_duty_7.text("rateAmount")).to eq "74.85"

      elem_tariff_duty_8 = tariff_duty_elements[7]
      expect(elem_tariff_duty_8.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_tariff_duty_8.text("rateAmount")).to eq "75.86"
    end

    it "handles XVV tariff instances" do
      entry = Factory(:entry, entry_number: "31679758714")
      inv = entry.commercial_invoices.build(invoice_number: "E1I0954293")
      inv_line = inv.commercial_invoice_lines.build(customs_line_number: 1, prorated_mpf: BigDecimal("100"),
                                                    hmf: BigDecimal("53.33"), cotton_fee: BigDecimal("75.31"),
                                                    add_duty_amount: BigDecimal("22.33"), add_case_percent: BigDecimal("8.39"),
                                                    cvd_duty_amount: BigDecimal("33.22"), cvd_case_percent: BigDecimal("9.40"),
                                                    hmf_rate: BigDecimal("10.6"), mpf_rate: BigDecimal("11.7"),
                                                    cotton_fee_rate: BigDecimal("12.8"))
      inv_line.commercial_invoice_tariffs.build(hts_code: "9506910030", spi_secondary: "X", specific_rate: BigDecimal("13.9"),
                                                duty_specific: BigDecimal("73.84"), advalorem_rate: BigDecimal("14.10"),
                                                duty_advalorem: BigDecimal("74.85"), additional_rate: BigDecimal("15.11"),
                                                duty_additional: BigDecimal("75.86"))
      # These "V" lines would probably have zero values for duties in the real world.  We're testing that they are
      # excluded here in the off-chance that the 0 assumption doesn't always hold true.
      inv_line.commercial_invoice_tariffs.build(hts_code: "9506910030", spi_secondary: "V", specific_rate: BigDecimal("13.9"),
                                                duty_specific: BigDecimal("73.84"), advalorem_rate: BigDecimal("14.10"),
                                                duty_advalorem: BigDecimal("74.85"), additional_rate: BigDecimal("15.11"),
                                                duty_additional: BigDecimal("75.86"))
      inv_line.commercial_invoice_tariffs.build(hts_code: "3506910033", spi_secondary: "V", specific_rate: BigDecimal("13.9"),
                                                duty_specific: BigDecimal("73.84"), advalorem_rate: BigDecimal("14.10"),
                                                duty_advalorem: BigDecimal("74.85"), additional_rate: BigDecimal("15.11"),
                                                duty_additional: BigDecimal("75.86"))

      doc = subject.generate_xml entry

      elem_root = doc.root
      elem_inv = elem_root.elements.to_a("invoiceRecord")[0]
      elem_item = elem_inv.elements.to_a("itemRecord")[0]

      elem_tariff_1 = elem_item.elements.to_a("itemTariffRecord")[0]
      expect(elem_tariff_1.text("tariffId")).to eq "9506.91.0030"
      item_tariff_duty_elements_1 = elem_tariff_1.elements.to_a("itemTariffDutyRecord")
      expect(item_tariff_duty_elements_1.size).to eq 8

      elem_item_tariff_duty_1 = item_tariff_duty_elements_1[0]
      expect(elem_item_tariff_duty_1.text("dutyTypeCode")).to eq "ADD"
      expect(elem_item_tariff_duty_1.text("rateAmount")).to eq "22.33"

      elem_item_tariff_duty_2 = item_tariff_duty_elements_1[1]
      expect(elem_item_tariff_duty_2.text("dutyTypeCode")).to eq "CVD"
      expect(elem_item_tariff_duty_2.text("rateAmount")).to eq "33.22"

      elem_item_tariff_duty_3 = item_tariff_duty_elements_1[2]
      expect(elem_item_tariff_duty_3.text("dutyTypeCode")).to eq "HMF"
      expect(elem_item_tariff_duty_3.text("rateAmount")).to eq "53.33"

      elem_item_tariff_duty_4 = item_tariff_duty_elements_1[3]
      expect(elem_item_tariff_duty_4.text("dutyTypeCode")).to eq "MPF"
      expect(elem_item_tariff_duty_4.text("rateAmount")).to eq "100.00"

      elem_item_tariff_duty_5 = item_tariff_duty_elements_1[4]
      expect(elem_item_tariff_duty_5.text("dutyTypeCode")).to eq "COF"
      expect(elem_item_tariff_duty_5.text("rateAmount")).to eq "75.31"

      elem_item_tariff_duty_6 = item_tariff_duty_elements_1[5]
      expect(elem_item_tariff_duty_6.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_item_tariff_duty_6.text("rateAmount")).to eq "73.84"

      elem_item_tariff_duty_7 = item_tariff_duty_elements_1[6]
      expect(elem_item_tariff_duty_7.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_item_tariff_duty_7.text("rateAmount")).to eq "74.85"

      elem_item_tariff_duty_8 = item_tariff_duty_elements_1[7]
      expect(elem_item_tariff_duty_8.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_item_tariff_duty_8.text("rateAmount")).to eq "75.86"

      elem_tariff_2 = elem_item.elements.to_a("itemTariffRecord")[1]
      expect(elem_tariff_2.text("tariffId")).to eq "9506.91.0030"
      item_tariff_duty_elements_2 = elem_tariff_2.elements.to_a("itemTariffDutyRecord")
      expect(item_tariff_duty_elements_2.size).to eq 3

      elem_item_tariff_duty_1 = item_tariff_duty_elements_2[0]
      expect(elem_item_tariff_duty_1.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_item_tariff_duty_1.text("rateAmount")).to eq "73.84"

      elem_item_tariff_duty_2 = item_tariff_duty_elements_2[1]
      expect(elem_item_tariff_duty_2.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_item_tariff_duty_2.text("rateAmount")).to eq "74.85"

      elem_item_tariff_duty_3 = item_tariff_duty_elements_2[2]
      expect(elem_item_tariff_duty_3.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_item_tariff_duty_3.text("rateAmount")).to eq "75.86"

      elem_tariff_3 = elem_item.elements.to_a("itemTariffRecord")[2]
      expect(elem_tariff_3.text("tariffId")).to eq "3506.91.0033"
      item_tariff_duty_elements_3 = elem_tariff_3.elements.to_a("itemTariffDutyRecord")
      expect(item_tariff_duty_elements_3.size).to eq 3

      elem_item_tariff_duty_1 = item_tariff_duty_elements_3[0]
      expect(elem_item_tariff_duty_1.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_item_tariff_duty_1.text("rateAmount")).to eq "73.84"

      elem_item_tariff_duty_2 = item_tariff_duty_elements_3[1]
      expect(elem_item_tariff_duty_2.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_item_tariff_duty_2.text("rateAmount")).to eq "74.85"

      elem_item_tariff_duty_3 = item_tariff_duty_elements_3[2]
      expect(elem_item_tariff_duty_3.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_item_tariff_duty_3.text("rateAmount")).to eq "75.86"

      tariff_header_elements = elem_inv.elements.to_a("tariffHeaderRecord")
      expect(tariff_header_elements.length).to eq 2

      elem_tariff_1 = tariff_header_elements[0]
      expect(elem_tariff_1.text("tariffId")).to eq "9506.91.0030"
      tariff_duty_elements = elem_tariff_1.elements.to_a("tariffDutyRecord")
      expect(tariff_duty_elements.size).to eq 8

      elem_tariff_duty_1 = tariff_duty_elements[0]
      expect(elem_tariff_duty_1.text("dutyTypeCode")).to eq "ADD"
      expect(elem_tariff_duty_1.text("rateAmount")).to eq "22.33"

      elem_tariff_duty_2 = tariff_duty_elements[1]
      expect(elem_tariff_duty_2.text("dutyTypeCode")).to eq "CVD"
      expect(elem_tariff_duty_2.text("rateAmount")).to eq "33.22"

      elem_tariff_duty_3 = tariff_duty_elements[2]
      expect(elem_tariff_duty_3.text("dutyTypeCode")).to eq "HMF"
      expect(elem_tariff_duty_3.text("rateAmount")).to eq "53.33"

      elem_tariff_duty_4 = tariff_duty_elements[3]
      expect(elem_tariff_duty_4.text("dutyTypeCode")).to eq "MPF"
      expect(elem_tariff_duty_4.text("rateAmount")).to eq "100.00"

      elem_tariff_duty_5 = tariff_duty_elements[4]
      expect(elem_tariff_duty_5.text("dutyTypeCode")).to eq "COF"
      expect(elem_tariff_duty_5.text("rateAmount")).to eq "75.31"

      elem_tariff_duty_6 = tariff_duty_elements[5]
      expect(elem_tariff_duty_6.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_tariff_duty_6.text("rateAmount")).to eq "73.84"

      elem_tariff_duty_7 = tariff_duty_elements[6]
      expect(elem_tariff_duty_7.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_tariff_duty_7.text("rateAmount")).to eq "74.85"

      elem_tariff_duty_8 = tariff_duty_elements[7]
      expect(elem_tariff_duty_8.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_tariff_duty_8.text("rateAmount")).to eq "75.86"

      elem_tariff_2 = tariff_header_elements[1]
      expect(elem_tariff_2.text("tariffId")).to eq "3506.91.0033"
      expect(elem_tariff_2.elements.to_a("tariffDutyRecord").size).to eq 0
    end

    it "handles chapter 99 tariffs" do
      entry = Factory(:entry, entry_number: "31679758714")
      inv = entry.commercial_invoices.build(invoice_number: "E1I0954293")
      inv_line = inv.commercial_invoice_lines.build(customs_line_number: 1, prorated_mpf: BigDecimal("100"),
                                                    hmf: BigDecimal("53.33"), cotton_fee: BigDecimal("75.31"),
                                                    add_duty_amount: BigDecimal("22.33"), add_case_percent: BigDecimal("8.39"),
                                                    cvd_duty_amount: BigDecimal("33.22"), cvd_case_percent: BigDecimal("9.40"),
                                                    hmf_rate: BigDecimal("10.6"), mpf_rate: BigDecimal("11.7"),
                                                    cotton_fee_rate: BigDecimal("12.8"))
      inv_line.commercial_invoice_tariffs.build(hts_code: "9506910030", specific_rate: BigDecimal("13.9"),
                                                duty_specific: BigDecimal("73.84"), advalorem_rate: BigDecimal("14.10"),
                                                duty_advalorem: BigDecimal("74.85"), additional_rate: BigDecimal("15.11"),
                                                duty_additional: BigDecimal("75.86"))
      # The 99 tariff line would probably have zero values for duties in the real world.  We're testing that they are
      # excluded here in the off-chance that the 0 assumption doesn't always hold true.
      inv_line.commercial_invoice_tariffs.build(hts_code: "99038835", specific_rate: BigDecimal("13.9"),
                                                duty_specific: BigDecimal("73.84"), advalorem_rate: BigDecimal("14.10"),
                                                duty_advalorem: BigDecimal("74.85"), additional_rate: BigDecimal("15.11"),
                                                duty_additional: BigDecimal("75.86"))

      doc = subject.generate_xml entry

      elem_root = doc.root
      elem_inv = elem_root.elements.to_a("invoiceRecord")[0]
      elem_item = elem_inv.elements.to_a("itemRecord")[0]

      elem_tariff_1 = elem_item.elements.to_a("itemTariffRecord")[0]
      expect(elem_tariff_1.text("tariffId")).to eq "9506.91.0030"
      item_tariff_duty_elements_1 = elem_tariff_1.elements.to_a("itemTariffDutyRecord")
      expect(item_tariff_duty_elements_1.size).to eq 8

      elem_item_tariff_duty_1 = item_tariff_duty_elements_1[0]
      expect(elem_item_tariff_duty_1.text("dutyTypeCode")).to eq "ADD"
      expect(elem_item_tariff_duty_1.text("rateAmount")).to eq "22.33"

      elem_item_tariff_duty_2 = item_tariff_duty_elements_1[1]
      expect(elem_item_tariff_duty_2.text("dutyTypeCode")).to eq "CVD"
      expect(elem_item_tariff_duty_2.text("rateAmount")).to eq "33.22"

      elem_item_tariff_duty_3 = item_tariff_duty_elements_1[2]
      expect(elem_item_tariff_duty_3.text("dutyTypeCode")).to eq "HMF"
      expect(elem_item_tariff_duty_3.text("rateAmount")).to eq "53.33"

      elem_item_tariff_duty_4 = item_tariff_duty_elements_1[3]
      expect(elem_item_tariff_duty_4.text("dutyTypeCode")).to eq "MPF"
      expect(elem_item_tariff_duty_4.text("rateAmount")).to eq "100.00"

      elem_item_tariff_duty_5 = item_tariff_duty_elements_1[4]
      expect(elem_item_tariff_duty_5.text("dutyTypeCode")).to eq "COF"
      expect(elem_item_tariff_duty_5.text("rateAmount")).to eq "75.31"

      elem_item_tariff_duty_6 = item_tariff_duty_elements_1[5]
      expect(elem_item_tariff_duty_6.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_item_tariff_duty_6.text("rateAmount")).to eq "73.84"

      elem_item_tariff_duty_7 = item_tariff_duty_elements_1[6]
      expect(elem_item_tariff_duty_7.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_item_tariff_duty_7.text("rateAmount")).to eq "74.85"

      elem_item_tariff_duty_8 = item_tariff_duty_elements_1[7]
      expect(elem_item_tariff_duty_8.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_item_tariff_duty_8.text("rateAmount")).to eq "75.86"

      elem_tariff_2 = elem_item.elements.to_a("itemTariffRecord")[1]
      expect(elem_tariff_2.text("tariffId")).to eq "9903.88.35"
      item_tariff_duty_elements_2 = elem_tariff_2.elements.to_a("itemTariffDutyRecord")
      expect(item_tariff_duty_elements_2.size).to eq 3
      # Includes the 3 constant duty records.
      elem_item_tariff_duty_1 = item_tariff_duty_elements_2[0]
      expect(elem_item_tariff_duty_1.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_item_tariff_duty_1.text("rateAmount")).to eq "73.84"

      elem_item_tariff_duty_2 = item_tariff_duty_elements_2[1]
      expect(elem_item_tariff_duty_2.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_item_tariff_duty_2.text("rateAmount")).to eq "74.85"

      elem_item_tariff_duty_3 = item_tariff_duty_elements_2[2]
      expect(elem_item_tariff_duty_3.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_item_tariff_duty_3.text("rateAmount")).to eq "75.86"

      tariff_header_elements = elem_inv.elements.to_a("tariffHeaderRecord")
      expect(tariff_header_elements.length).to eq 2

      elem_tariff_1 = tariff_header_elements[0]
      expect(elem_tariff_1.text("tariffId")).to eq "9506.91.0030"
      tariff_duty_elements = elem_tariff_1.elements.to_a("tariffDutyRecord")
      expect(tariff_duty_elements.size).to eq 8

      elem_tariff_duty_1 = tariff_duty_elements[0]
      expect(elem_tariff_duty_1.text("dutyTypeCode")).to eq "ADD"
      expect(elem_tariff_duty_1.text("rateAmount")).to eq "22.33"

      elem_tariff_duty_2 = tariff_duty_elements[1]
      expect(elem_tariff_duty_2.text("dutyTypeCode")).to eq "CVD"
      expect(elem_tariff_duty_2.text("rateAmount")).to eq "33.22"

      elem_tariff_duty_3 = tariff_duty_elements[2]
      expect(elem_tariff_duty_3.text("dutyTypeCode")).to eq "HMF"
      expect(elem_tariff_duty_3.text("rateAmount")).to eq "53.33"

      elem_tariff_duty_4 = tariff_duty_elements[3]
      expect(elem_tariff_duty_4.text("dutyTypeCode")).to eq "MPF"
      expect(elem_tariff_duty_4.text("rateAmount")).to eq "100.00"

      elem_tariff_duty_5 = tariff_duty_elements[4]
      expect(elem_tariff_duty_5.text("dutyTypeCode")).to eq "COF"
      expect(elem_tariff_duty_5.text("rateAmount")).to eq "75.31"

      elem_tariff_duty_6 = tariff_duty_elements[5]
      expect(elem_tariff_duty_6.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_tariff_duty_6.text("rateAmount")).to eq "73.84"

      elem_tariff_duty_7 = tariff_duty_elements[6]
      expect(elem_tariff_duty_7.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_tariff_duty_7.text("rateAmount")).to eq "74.85"

      elem_tariff_duty_8 = tariff_duty_elements[7]
      expect(elem_tariff_duty_8.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_tariff_duty_8.text("rateAmount")).to eq "75.86"

      elem_tariff_2 = tariff_header_elements[1]
      expect(elem_tariff_2.text("tariffId")).to eq "9903.88.35"
      tariff_duty_elements = elem_tariff_2.elements.to_a("tariffDutyRecord")
      # Includes the 3 constant duty records.
      expect(tariff_duty_elements.size).to eq 3

      elem_tariff_duty_1 = tariff_duty_elements[0]
      expect(elem_tariff_duty_1.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_tariff_duty_1.text("rateAmount")).to eq "73.84"

      elem_tariff_duty_2 = tariff_duty_elements[1]
      expect(elem_tariff_duty_2.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_tariff_duty_2.text("rateAmount")).to eq "74.85"

      elem_tariff_duty_3 = tariff_duty_elements[2]
      expect(elem_tariff_duty_3.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_tariff_duty_3.text("rateAmount")).to eq "75.86"
    end

    # The "squeezing" process can combine items with like tariff numbers onto the same US customs line (i.e.
    # customs line number is shared between two invoice lines).  This test ensures that we're totalling up
    # invoice line-level fields correctly in the tariff header.
    it "handles squeezed tariffs" do
      entry = Factory(:entry, entry_number: "31679758714")
      inv = entry.commercial_invoices.create!(invoice_number: "E1I0954293")
      inv_line_1 = inv.commercial_invoice_lines.create!(customs_line_number: 1, prorated_mpf: BigDecimal("100"),
                                                        hmf: BigDecimal("53.33"), cotton_fee: BigDecimal("75.31"),
                                                        add_duty_amount: BigDecimal("22.33"), add_case_percent: BigDecimal("8.39"),
                                                        cvd_duty_amount: BigDecimal("33.22"), cvd_case_percent: BigDecimal("9.40"),
                                                        hmf_rate: BigDecimal("10.6"), mpf_rate: BigDecimal("11.7"),
                                                        cotton_fee_rate: BigDecimal("12.8"))
      inv_line_1.commercial_invoice_tariffs.create!(hts_code: "9506910030", specific_rate: BigDecimal("13.9"),
                                                    duty_specific: BigDecimal("73.84"), advalorem_rate: BigDecimal("14.10"),
                                                    duty_advalorem: BigDecimal("74.85"), additional_rate: BigDecimal("15.11"),
                                                    duty_additional: BigDecimal("75.86"))
      # The 99 tariff line should be handled independently of the other two tariff records.
      inv_line_1.commercial_invoice_tariffs.create!(hts_code: "99038835", specific_rate: BigDecimal("13.9"),
                                                    duty_specific: BigDecimal("73.84"), advalorem_rate: BigDecimal("14.10"),
                                                    duty_advalorem: BigDecimal("74.85"), additional_rate: BigDecimal("15.11"),
                                                    duty_additional: BigDecimal("75.86"))

      inv_line_2 = inv.commercial_invoice_lines.create!(customs_line_number: 1, prorated_mpf: BigDecimal("10"),
                                                        hmf: BigDecimal("5.33"), cotton_fee: BigDecimal("7.53"),
                                                        add_duty_amount: BigDecimal("2.23"), add_case_percent: BigDecimal("8.39"),
                                                        cvd_duty_amount: BigDecimal("3.32"), cvd_case_percent: BigDecimal("9.40"),
                                                        hmf_rate: BigDecimal("10.6"), mpf_rate: BigDecimal("11.7"),
                                                        cotton_fee_rate: BigDecimal("12.8"))
      inv_line_2.commercial_invoice_tariffs.create!(hts_code: "9506910030", specific_rate: BigDecimal("13.9"),
                                                    duty_specific: BigDecimal("7.38"), advalorem_rate: BigDecimal("14.10"),
                                                    duty_advalorem: BigDecimal("7.48"), additional_rate: BigDecimal("15.11"),
                                                    duty_additional: BigDecimal("7.58"))

      doc = subject.generate_xml entry

      elem_root = doc.root
      elem_inv = elem_root.elements.to_a("invoiceRecord")[0]
      elem_item = elem_inv.elements.to_a("itemRecord")[0]

      elem_tariff_1 = elem_item.elements.to_a("itemTariffRecord")[0]
      expect(elem_tariff_1.text("tariffId")).to eq "9506.91.0030"
      item_tariff_duty_elements_1 = elem_tariff_1.elements.to_a("itemTariffDutyRecord")
      expect(item_tariff_duty_elements_1.size).to eq 8

      elem_item_tariff_duty_1 = item_tariff_duty_elements_1[0]
      expect(elem_item_tariff_duty_1.text("dutyTypeCode")).to eq "ADD"
      expect(elem_item_tariff_duty_1.text("rateAmount")).to eq "22.33"

      elem_item_tariff_duty_2 = item_tariff_duty_elements_1[1]
      expect(elem_item_tariff_duty_2.text("dutyTypeCode")).to eq "CVD"
      expect(elem_item_tariff_duty_2.text("rateAmount")).to eq "33.22"

      elem_item_tariff_duty_3 = item_tariff_duty_elements_1[2]
      expect(elem_item_tariff_duty_3.text("dutyTypeCode")).to eq "HMF"
      expect(elem_item_tariff_duty_3.text("rateAmount")).to eq "53.33"

      elem_item_tariff_duty_4 = item_tariff_duty_elements_1[3]
      expect(elem_item_tariff_duty_4.text("dutyTypeCode")).to eq "MPF"
      expect(elem_item_tariff_duty_4.text("rateAmount")).to eq "100.00"

      elem_item_tariff_duty_5 = item_tariff_duty_elements_1[4]
      expect(elem_item_tariff_duty_5.text("dutyTypeCode")).to eq "COF"
      expect(elem_item_tariff_duty_5.text("rateAmount")).to eq "75.31"

      elem_item_tariff_duty_6 = item_tariff_duty_elements_1[5]
      expect(elem_item_tariff_duty_6.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_item_tariff_duty_6.text("rateAmount")).to eq "73.84"

      elem_item_tariff_duty_7 = item_tariff_duty_elements_1[6]
      expect(elem_item_tariff_duty_7.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_item_tariff_duty_7.text("rateAmount")).to eq "74.85"

      elem_item_tariff_duty_8 = item_tariff_duty_elements_1[7]
      expect(elem_item_tariff_duty_8.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_item_tariff_duty_8.text("rateAmount")).to eq "75.86"

      elem_tariff_2 = elem_item.elements.to_a("itemTariffRecord")[1]
      expect(elem_tariff_2.text("tariffId")).to eq "9903.88.35"
      item_tariff_duty_elements_2 = elem_tariff_2.elements.to_a("itemTariffDutyRecord")
      expect(item_tariff_duty_elements_2.size).to eq 3
      # Includes the 3 constant duty records.
      elem_item_tariff_duty_1 = item_tariff_duty_elements_2[0]
      expect(elem_item_tariff_duty_1.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_item_tariff_duty_1.text("rateAmount")).to eq "73.84"

      elem_item_tariff_duty_2 = item_tariff_duty_elements_2[1]
      expect(elem_item_tariff_duty_2.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_item_tariff_duty_2.text("rateAmount")).to eq "74.85"

      elem_item_tariff_duty_3 = item_tariff_duty_elements_2[2]
      expect(elem_item_tariff_duty_3.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_item_tariff_duty_3.text("rateAmount")).to eq "75.86"

      tariff_header_elements = elem_inv.elements.to_a("tariffHeaderRecord")
      expect(tariff_header_elements.length).to eq 2

      elem_tariff_1 = tariff_header_elements[0]
      expect(elem_tariff_1.text("tariffId")).to eq "9506.91.0030"
      tariff_duty_elements = elem_tariff_1.elements.to_a("tariffDutyRecord")
      expect(tariff_duty_elements.size).to eq 8

      elem_tariff_duty_1 = tariff_duty_elements[0]
      expect(elem_tariff_duty_1.text("dutyTypeCode")).to eq "ADD"
      expect(elem_tariff_duty_1.text("rateAmount")).to eq "24.56"

      elem_tariff_duty_2 = tariff_duty_elements[1]
      expect(elem_tariff_duty_2.text("dutyTypeCode")).to eq "CVD"
      expect(elem_tariff_duty_2.text("rateAmount")).to eq "36.54"

      elem_tariff_duty_3 = tariff_duty_elements[2]
      expect(elem_tariff_duty_3.text("dutyTypeCode")).to eq "HMF"
      expect(elem_tariff_duty_3.text("rateAmount")).to eq "58.66"

      elem_tariff_duty_4 = tariff_duty_elements[3]
      expect(elem_tariff_duty_4.text("dutyTypeCode")).to eq "MPF"
      expect(elem_tariff_duty_4.text("rateAmount")).to eq "110.00"

      elem_tariff_duty_5 = tariff_duty_elements[4]
      expect(elem_tariff_duty_5.text("dutyTypeCode")).to eq "COF"
      expect(elem_tariff_duty_5.text("rateAmount")).to eq "82.84"

      elem_tariff_duty_6 = tariff_duty_elements[5]
      expect(elem_tariff_duty_6.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_tariff_duty_6.text("rateAmount")).to eq "81.22"

      elem_tariff_duty_7 = tariff_duty_elements[6]
      expect(elem_tariff_duty_7.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_tariff_duty_7.text("rateAmount")).to eq "82.33"

      elem_tariff_duty_8 = tariff_duty_elements[7]
      expect(elem_tariff_duty_8.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_tariff_duty_8.text("rateAmount")).to eq "83.44"

      elem_tariff_2 = tariff_header_elements[1]
      expect(elem_tariff_2.text("tariffId")).to eq "9903.88.35"
      tariff_duty_elements = elem_tariff_2.elements.to_a("tariffDutyRecord")
      # Includes the 3 constant duty records.
      expect(tariff_duty_elements.size).to eq 3

      elem_tariff_duty_1 = tariff_duty_elements[0]
      expect(elem_tariff_duty_1.text("dutyTypeCode")).to eq "SPECFC"
      expect(elem_tariff_duty_1.text("rateAmount")).to eq "73.84"

      elem_tariff_duty_2 = tariff_duty_elements[1]
      expect(elem_tariff_duty_2.text("dutyTypeCode")).to eq "ADVAL"
      expect(elem_tariff_duty_2.text("rateAmount")).to eq "74.85"

      elem_tariff_duty_3 = tariff_duty_elements[2]
      expect(elem_tariff_duty_3.text("dutyTypeCode")).to eq "OTHER"
      expect(elem_tariff_duty_3.text("rateAmount")).to eq "75.86"
    end

    describe "recon variants" do
      it "returns recon indicator of 007 when VALUE, CLASS and 9802 are part of recon flags" do
        entry = Factory(:entry, entry_number: "31679758714", recon_flags: "CLASS value 9802 SOMETHING")

        doc = subject.generate_xml entry

        expect(doc.root.text("otherReconIndicator")).to eq "007"
      end

      it "returns recon indicator of 006 when CLASS and 9802 are part of recon flags" do
        entry = Factory(:entry, entry_number: "31679758714", recon_flags: "SOMETHING class 9802")

        doc = subject.generate_xml entry

        expect(doc.root.text("otherReconIndicator")).to eq "006"
      end

      it "returns recon indicator of 005 when VALUE and 9802 are part of recon flags" do
        entry = Factory(:entry, entry_number: "31679758714", recon_flags: "VALUE SOMETHING 9802")

        doc = subject.generate_xml entry

        expect(doc.root.text("otherReconIndicator")).to eq "005"
      end

      it "returns recon indicator of 004 when VALUE and CLASS are part of recon flags" do
        entry = Factory(:entry, entry_number: "31679758714", recon_flags: "vaLue clAss 9803")

        doc = subject.generate_xml entry

        expect(doc.root.text("otherReconIndicator")).to eq "004"
      end

      it "returns recon indicator of 003 when only 9802 is part of recon flags" do
        entry = Factory(:entry, entry_number: "31679758714", recon_flags: "SOMETHING 9802")

        doc = subject.generate_xml entry

        expect(doc.root.text("otherReconIndicator")).to eq "003"
      end

      it "returns recon indicator of 002 when only CLASS is part of recon flags" do
        entry = Factory(:entry, entry_number: "31679758714", recon_flags: "cLASS SOMETHING")

        doc = subject.generate_xml entry

        expect(doc.root.text("otherReconIndicator")).to eq "002"
      end

      it "returns recon indicator of 001 when only VALUE is part of recon flags" do
        entry = Factory(:entry, entry_number: "31679758714", recon_flags: "SOMETHING vALUE")

        doc = subject.generate_xml entry

        expect(doc.root.text("otherReconIndicator")).to eq "001"
      end
    end
  end

  describe "generate_and_send" do
    let (:packet_generator) { instance_double(OpenChain::CustomHandler::Target::TargetDocumentPacketZipGenerator) }

    it "generates and sends a file" do
      entry = Factory(:entry)

      expect(subject).to receive(:generate_xml).with(entry).and_return REXML::Document.new("<FakeXml><child>A</child></FakeXml>")
      expect(subject).to receive(:packet_generator).and_return packet_generator
      expect(packet_generator).to receive(:generate_and_send_doc_packs).with(entry)

      doc = nil
      expect(subject).to receive(:ftp_sync_file) do |file, sync|
        doc = REXML::Document.new(file.read)
        sync.ftp_session_id = 357
        expect(file.original_filename).to eq "ENTRY_FILE_20200324020508000.xml"
        file.close!
      end

      current = ActiveSupport::TimeZone["America/New_York"].parse("2020-03-24 02:05:08")
      Timecop.freeze(current) do
        subject.generate_and_send entry
      end

      expect(doc.root.name).to eq "FakeXml"

      expect(entry.sync_records.length).to eq 1
      expect(entry.sync_records[0].trading_partner).to eq described_class::SYNC_TRADING_PARTNER
      expect(entry.sync_records[0].sent_at).to eq (current - 1.second)
      expect(entry.sync_records[0].confirmed_at).to eq current
      expect(entry.sync_records[0].ftp_session_id).to eq 357
    end
  end

  describe "find_generate_and_send_entries" do

    it "calls generate and send method for each matching entry" do
      target = with_customs_management_id(Factory(:importer), "TARGEN")

      entry_no_sync = Factory(:entry, importer_id: target.id, summary_accepted_date: Date.new(2020, 4, 14), final_statement_date: nil)

      entry_old_sync = Factory(:entry, importer_id: target.id, summary_accepted_date: Date.new(2020, 4, 14), final_statement_date: nil)
      entry_old_sync.sync_records.create!(trading_partner: described_class::SYNC_TRADING_PARTNER, sent_at: Date.new(2020, 4, 13))

      # This should be excluded because it has a sync record with a sent at date later than the entry's summary accepted date.
      entry_new_sync = Factory(:entry, importer_id: target.id, summary_accepted_date: Date.new(2020, 4, 14), final_statement_date: nil)
      entry_new_sync.sync_records.create!(trading_partner: described_class::SYNC_TRADING_PARTNER, sent_at: Date.new(2020, 4, 15))

      # This should be excluded because it belongs to a different importer.
      entry_not_target = Factory(:entry, importer_id: target.id - 1, summary_accepted_date: Date.new(2020, 4, 14), final_statement_date: nil)

      # This should be excluded because it has no accepted date.
      entry_no_summary_accepted_date = Factory(:entry, importer_id: target.id, summary_accepted_date: nil, final_statement_date: nil)

      # This should not be excluded because it has a final statement date, but has not been sent previously
      entry_finalized = Factory(:entry, importer_id: target.id, summary_accepted_date: Date.new(2020, 4, 14), final_statement_date: Date.new(2020, 4, 15))

      entry_finalized_sent = Factory(:entry, importer_id: target.id, summary_accepted_date: Date.new(2020, 4, 14), final_statement_date: Date.new(2020, 4, 15))
      entry_finalized_sent.sync_records.create!(trading_partner: described_class::SYNC_TRADING_PARTNER, sent_at: Date.new(2020, 4, 13))

      expect(subject).to receive(:generate_and_send).with(entry_old_sync)
      expect(subject).to receive(:generate_and_send).with(entry_no_sync)
      expect(subject).not_to receive(:generate_and_send).with(entry_new_sync)
      expect(subject).not_to receive(:generate_and_send).with(entry_not_target)
      expect(subject).not_to receive(:generate_and_send).with(entry_no_summary_accepted_date)
      expect(subject).to receive(:generate_and_send).with(entry_finalized)
      expect(subject).not_to receive(:generate_and_send).with(entry_finalized_sent)

      subject.find_generate_and_send_entries
    end

    it "raises an error when Target isn't found" do
      expect { subject.find_generate_and_send_entries }.to raise_error "Target company record not found."
    end
  end

  describe "run_schedulable" do
    subject { described_class }

    it "calls find_generate_and_send_entries" do
      expect_any_instance_of(subject).to receive(:find_generate_and_send_entries)
      subject.run_schedulable
    end
  end

  describe "cusdec_ftp_credentials" do
    it "gets test creds" do
      allow(stub_master_setup).to receive(:production?).and_return false
      cred = subject.cusdec_ftp_credentials
      expect(cred[:folder]).to eq "to_ecs/target_cusdec_test"
    end

    it "gets production creds" do
      allow(stub_master_setup).to receive(:production?).and_return true
      cred = subject.cusdec_ftp_credentials
      expect(cred[:folder]).to eq "to_ecs/target_cusdec"
    end
  end
end