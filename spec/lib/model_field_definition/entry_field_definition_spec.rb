describe OpenChain::ModelFieldDefinition::EntryFieldDefinition do
  describe 'ent_first_billed_date' do
    let :mf do
      ModelField.find_by_uid :ent_first_billed_date
    end

    it "is first billed date when multiple bills" do
      bi = create(:broker_invoice, invoice_date: Date.new(2016, 10, 1))
      create(:broker_invoice, invoice_date: Date.new(2016, 10, 2), entry: bi.entry)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_first_billed_date', operator: 'eq', value: '2016-10-01')
      expect(ss.result_keys).to eq [bi.entry.id]

      # test in memory export value
      expect(mf.process_export(bi.entry, nil, true)).to eq Date.new(2016, 10, 1)
    end

    it "is nil when no bills" do
      ent = create(:entry)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_first_billed_date', operator: 'null')
      expect(ss.result_keys).to eq [ent.id]

      # test in memory export value
      expect(mf.process_export(ent, nil, true)).to be_nil
    end

    it "is read only" do
      expect(mf).to be_read_only
    end
  end

  describe 'ent_container_count' do
    let :mf do
      ModelField.find_by_uid :ent_container_count
    end

    it "returns 0 if no containers" do
      ent = create(:entry)
      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_container_count', operator: 'eq', value: '0')
      expect(ss.result_keys).to eq [ent.id]

      # test in memory export value
      expect(mf.process_export(ent, nil, true)).to eq 0
    end

    it "returns container count" do
      ent = create(:entry)
      2.times {|_i| create(:container, entry: ent)}
      ent.reload
      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_container_count', operator: 'eq', value: '2')
      expect(ss.result_keys).to eq [ent.id]

      # test in memory export value
      expect(mf.process_export(ent, nil, true)).to eq 2
    end
  end

  describe 'ent_entry_filer' do
    let :mf do
      ModelField.find_by_uid :ent_entry_filer
    end

    it "returns nil if no entry number" do
      ent = create(:entry, entry_number: nil)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_entry_filer', operator: 'null')
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to be_nil
    end

    it "returns first five characters of entry number if Canadian" do
      country = create(:country, iso_code: 'CA')
      ent = create(:entry, entry_number: '1324657980', import_country: country)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_entry_filer', operator: 'eq', value: '13246')
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq('13246')
    end

    it "returns first three characters of entry number if USA" do
      country = create(:country, iso_code: 'US')
      ent = create(:entry, entry_number: '1324657980', import_country: country)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_entry_filer', operator: 'eq', value: '132')
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq('132')
    end

    it "returns first three characters of entry number if no import country specified" do
      ent = create(:entry, entry_number: '1324657980', import_country: nil)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_entry_filer', operator: 'eq', value: '132')
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq('132')
    end
  end

  describe 'ent_total_miscellaneous_discount' do
    let :mf do
      ModelField.find_by_uid :ent_total_miscellaneous_discount
    end

    it "returns discount sum" do
      ent = create(:entry)
      inv = create(:commercial_invoice, entry: ent)
      create(:commercial_invoice_line, commercial_invoice: inv, miscellaneous_discount: 10.25)
      create(:commercial_invoice_line, commercial_invoice: inv, miscellaneous_discount: 5.50)
      ent.reload

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_total_miscellaneous_discount', operator: 'eq', value: '15.75')
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq 15.75
    end
  end

  describe 'ent_open_exception_codes' do
    let :mf do
      ModelField.find_by_uid :ent_open_exception_codes
    end

    it "returns concatenated exception codes" do
      ent = create(:entry)
      ent.entry_exceptions.create! code: "D", resolved_date: nil
      ent.entry_exceptions.create! code: "B", resolved_date: nil
      ent.entry_exceptions.create! code: "C", resolved_date: Date.new(2020, 1, 1)
      ent.entry_exceptions.create! code: "A", resolved_date: nil
      ent.entry_exceptions.create! code: "D", resolved_date: nil

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_open_exception_codes', operator: 'eq', value: "D\nB\nA")
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq "D\nB\nA"
    end
  end

  describe 'ent_resolved_exception_codes' do
    let :mf do
      ModelField.find_by_uid :ent_resolved_exception_codes
    end

    it "returns concatenated exception codes" do
      ent = create(:entry)
      ent.entry_exceptions.create! code: "D", resolved_date: Date.new(2020, 1, 1)
      ent.entry_exceptions.create! code: "B", resolved_date: Date.new(2020, 2, 2)
      ent.entry_exceptions.create! code: "C", resolved_date: nil
      ent.entry_exceptions.create! code: "A", resolved_date: Date.new(2020, 3, 3)
      ent.entry_exceptions.create! code: "D", resolved_date: Date.new(2020, 4, 4)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_resolved_exception_codes', operator: 'eq', value: "D\nB\nA")
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq "D\nB\nA"
    end
  end

  context 'pga_flag_fields' do
    ["AMS", "APH", "ATF", "DEA", "EPA", "FDA", "FSI", "FWS", "NHT", "NMF", "OMC", "TTB"].each do |agency_code|
      describe "ent_pga_#{agency_code.downcase}" do
        it "returns true when PGA summary for #{agency_code} is present" do
          uid = "ent_pga_#{agency_code.downcase}"
          mf = ModelField.find_by_uid(uid.to_sym)

          ent = create(:entry)
          ent.entry_pga_summaries.create!(agency_code: agency_code)

          ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
          ss.search_criterions.build(model_field_uid: uid, operator: "eq", value: true)
          expect(ss.result_keys).to eq [ent.id]

          expect(mf.process_export(ent, nil, true)).to eq true
        end

        it "returns false when PGA summary for #{agency_code} is not present" do
          uid = "ent_pga_#{agency_code.downcase}"
          mf = ModelField.find_by_uid(uid.to_sym)

          ent = create(:entry)

          ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
          ss.search_criterions.build(model_field_uid: uid, operator: "eq", value: false)
          expect(ss.result_keys).to eq [ent.id]

          expect(mf.process_export(ent, nil, true)).to eq false
        end
      end
    end
  end

  describe 'ent_exception_notes' do
    let :mf do
      ModelField.find_by_uid :ent_exception_notes
    end

    it "returns concatenated exception comments" do
      ent = create(:entry)
      ent.entry_exceptions.create! code: "A", comments: "Arguments, agreements, advice, answers, articulate announcements"
      ent.entry_exceptions.create! code: "A", comments: "Babble, burble, banter, bicker bicker bicker"
      ent.entry_exceptions.create! code: "A", comments: "   "
      ent.entry_exceptions.create! code: "A", comments: "Brouhaha, balderdash, ballyhoo"
      ent.entry_exceptions.create! code: "A", comments: "Brouhaha, balderdash, ballyhoo"
      ent.entry_exceptions.create! code: "A", comments: nil

      expected_val = "Arguments, agreements, advice, answers, articulate announcements\n" +
                     "Babble, burble, banter, bicker bicker bicker\n" +
                     "Brouhaha, balderdash, ballyhoo"

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_exception_notes', operator: 'eq', value: expected_val)
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq expected_val
    end
  end

  describe 'ent_lading_port_name' do
    let :mf do
      ModelField.find_by_uid :ent_lading_port_name
    end

    it "returns lading port name" do
      port = create(:port, schedule_k_code: "59687", name: "Innsmouth")
      ent = create(:entry, lading_port: port)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_lading_port_name', operator: 'eq', value: "Innsmouth")
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq "Innsmouth"
    end

    it "updates port code by name" do
      create(:port, schedule_k_code: "59687", name: "Innsmouth")
      ent = create(:entry)

      expect(mf.process_import(ent, "Innsmouth", create(:admin_user))).to eq "Lading Port set to Innsmouth"
      expect(ent.lading_port_code).to eq "59687"
    end

    it "returns error message on import when port not found" do
      ent = create(:entry)

      expect(mf.process_import(ent, "Innsmouth", create(:admin_user))).to eq "Port with name \"Innsmouth\" could not be found."
      expect(ent.lading_port_code).to be_nil
    end
  end

  describe 'ent_unlading_port_name' do
    let :mf do
      ModelField.find_by_uid :ent_unlading_port_name
    end

    it "returns unlading port name" do
      port = create(:port, schedule_d_code: "5968", name: "Innsmouth")
      ent = create(:entry, unlading_port: port)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_unlading_port_name', operator: 'eq', value: "Innsmouth")
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq "Innsmouth"
    end

    it "updates port code by name" do
      create(:port, schedule_d_code: "5968", name: "Innsmouth")
      ent = create(:entry)

      expect(mf.process_import(ent, "Innsmouth", create(:admin_user))).to eq "Unlading Port set to Innsmouth"
      expect(ent.unlading_port_code).to eq "5968"
    end

    it "returns error message on import when port not found" do
      ent = create(:entry)

      expect(mf.process_import(ent, "Innsmouth", create(:admin_user))).to eq "Port with name \"Innsmouth\" could not be found."
      expect(ent.unlading_port_code).to be_nil
    end
  end

  describe 'ent_entry_port_name' do
    let :mf do
      ModelField.find_by_uid :ent_entry_port_name
    end

    it "returns entry port name for Kewill" do
      port = create(:port, schedule_d_code: "5968", name: "Innsmouth")
      import_country = create(:country, iso_code: "US")
      ent = create(:entry, source_system: Entry::KEWILL_SOURCE_SYSTEM, us_entry_port: port, import_country: import_country)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_entry_port_name', operator: 'eq', value: "Innsmouth")
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq "Innsmouth"
    end

    it "returns entry port name for Fenix" do
      port = create(:port, cbsa_port: "5968", name: "Innsmouth")
      import_country = create(:country, iso_code: "CA")
      ent = create(:entry, source_system: Entry::FENIX_SOURCE_SYSTEM, ca_entry_port: port, import_country: import_country)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_entry_port_name', operator: 'eq', value: "Innsmouth")
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq "Innsmouth"
    end

    it "updates port code by name for Kewill" do
      create(:port, schedule_d_code: "5968", name: "Innsmouth")
      ent = create(:entry, source_system: Entry::KEWILL_SOURCE_SYSTEM)

      expect(mf.process_import(ent, "Innsmouth", create(:admin_user))).to eq "Entry Port set to Innsmouth"
      expect(ent.entry_port_code).to eq "5968"
    end

    it "updates port code by name for Fenix" do
      create(:port, cbsa_port: "5968", name: "Innsmouth")
      ent = create(:entry, source_system: Entry::FENIX_SOURCE_SYSTEM)

      expect(mf.process_import(ent, "Innsmouth", create(:admin_user))).to eq "Entry Port set to Innsmouth"
      expect(ent.entry_port_code).to eq "5968"
    end

    it "returns error message on import when port not found" do
      ent = create(:entry)

      expect(mf.process_import(ent, "Innsmouth", create(:admin_user))).to eq "Port with name \"Innsmouth\" could not be found."
      expect(ent.entry_port_code).to be_nil
    end
  end

  describe 'ent_ci_line_count' do
    let :mf do
      ModelField.find_by_uid :ent_ci_line_count
    end

    it "returns number of commercial invoice lines" do
      ent = create(:entry)
      ci_1 = create(:commercial_invoice, entry: ent)
      create(:commercial_invoice_line, commercial_invoice: ci_1)
      create(:commercial_invoice_line, commercial_invoice: ci_1)
      ci_2 = create(:commercial_invoice, entry: ent)
      create(:commercial_invoice_line, commercial_invoice: ci_2)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_ci_line_count', operator: 'eq', value: "3")
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq 3
    end
  end

  describe 'ent_pdf_count' do
    let :mf do
      ModelField.find_by_uid :ent_pdf_count
    end

    it "returns number of PDF attachments" do
      ent = create(:entry)
      create(:attachment, attachable_id: ent.id, attachable_type: "Entry", attached_content_type: "application/pdf", attached_file_name: "A.ZIP")
      create(:attachment, attachable_id: ent.id, attachable_type: "Entry", attached_content_type: "application/zip", attached_file_name: "A.PDF")
      # This attachment should not be included because its filename and content type don't match.
      create(:attachment, attachable_id: ent.id, attachable_type: "Entry", attached_content_type: "application/zip", attached_file_name: "A.ZIP")

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_pdf_count', operator: 'eq', value: "2")
      expect(ss.result_keys).to eq []

      # Results are shown for brokers only, for whatever reason.
      broker_user = create(:broker_user)
      ss.user_id = broker_user.id
      ent.update!(broker_id: broker_user.company.id)

      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq 2
    end
  end

  describe 'ent_user_notes' do
    let :mf do
      ModelField.find_by_uid :ent_user_notes
    end

    it "returns user notes, excluding system/etc. comments" do
      ent = create(:entry)
      ent.entry_comments.create!(username: "arf", generated_at: ActiveSupport::TimeZone['Eastern Time (US & Canada)'].parse('2020-08-31 10:37:06'), body: "Some text")
      ent.entry_comments.create!(username: "arg", body: "Some more text")
      ent.entry_comments.create!(username: "SYSTEM", body: "System comment")

      expected_val = "Some text (2020-08-31 14:37 - arf)\nSome more text (arg)"

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_user_notes', operator: 'eq', value: expected_val)
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq expected_val
    end
  end

  describe 'ent_first_sale_savings' do
    let :mf do
      ModelField.find_by_uid :ent_first_sale_savings
    end

    it "returns computed first sale savings" do
      ent = create(:entry)
      ci = create(:commercial_invoice, entry: ent)
      create(:commercial_invoice_line, contract_amount: 500, value: 200, commercial_invoice: ci,
                                        commercial_invoice_tariffs: [create(:commercial_invoice_tariff, duty_amount: 30, entered_value: 10),
                                                                    create(:commercial_invoice_tariff, duty_amount: 40, entered_value: 15)])
      create(:commercial_invoice_line, contract_amount: 300, value: 100, commercial_invoice: ci,
                                        commercial_invoice_tariffs: [create(:commercial_invoice_tariff, duty_amount: 50, entered_value: 20)])
      # Excluded because the line has no contract amount.
      create(:commercial_invoice_line, contract_amount: 0, value: 100, commercial_invoice: ci,
                                        commercial_invoice_tariffs: [create(:commercial_invoice_tariff, duty_amount: 50, entered_value: 20)])

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_first_sale_savings', operator: 'eq', value: 1400)
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq 1400
    end
  end

  describe 'ent_total_duty_taxes_fees_penalties' do
    let :mf do
      ModelField.find_by_uid :ent_total_duty_taxes_fees_penalties
    end

    it "returns sum of total duty, taxes, fees and penalties" do
      ent = create(:entry, total_duty: 1, total_taxes: 2, total_fees: 3, total_cvd: 4, total_add: 5)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_total_duty_taxes_fees_penalties', operator: 'eq', value: 15)
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq 15
    end

    it "handles nil values" do
      ent = create(:entry, total_duty: nil, total_taxes: nil, total_fees: nil, total_cvd: nil, total_add: nil)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_total_duty_taxes_fees_penalties', operator: 'eq', value: 0)
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq 0
    end
  end

  describe 'ent_post_summary_exists' do
    let :mf do
      ModelField.find_by_uid :ent_post_summary_exists
    end

    it "returns true when any line contains post summary correction date" do
      ent = create(:entry)
      ci = create(:commercial_invoice, entry: ent)
      create(:commercial_invoice_line, commercial_invoice: ci, psc_date: nil)
      create(:commercial_invoice_line, commercial_invoice: ci, psc_date: Date.new(2020, 8, 1))
      create(:commercial_invoice_line, commercial_invoice: ci, psc_date: nil)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_post_summary_exists', operator: 'eq', value: true)
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq true
    end

    it "returns false when no lines contain post summary correction date" do
      ent = create(:entry)
      ci = create(:commercial_invoice, entry: ent)
      create(:commercial_invoice_line, commercial_invoice: ci, psc_date: nil)

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_post_summary_exists', operator: 'eq', value: false)
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq false
    end
  end

  describe 'ent_currencies' do
    let :mf do
      ModelField.find_by_uid :ent_currencies
    end

    it "returns concatenated currencies" do
      ent = create(:entry)
      create(:commercial_invoice, entry: ent, currency: "USD")
      create(:commercial_invoice, entry: ent, currency: "CAD")
      create(:commercial_invoice, entry: ent, currency: "USD")

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_currencies', operator: 'eq', value: "USD\nCAD")
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq "USD\nCAD"
    end
  end

  describe 'ent_broker_invoice_list' do
    let :mf do
      ModelField.find_by_uid :ent_broker_invoice_list
    end

    it "returns concatenated broker invoice numbers" do
      ent = create(:entry)
      create(:broker_invoice, entry: ent, invoice_number: "123")
      create(:broker_invoice, entry: ent, invoice_number: "567")
      # Invoice numbers cannot be duplicated under an entry.

      ss = SearchSetup.new(module_type: 'Entry', user_id: create(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_broker_invoice_list', operator: 'eq', value: "123\n567")
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq "123\n567"
    end
  end

  describe 'ent_origin_airport_name' do
    let :mf do
      ModelField.find_by_uid :ent_origin_airport_name
    end

    it "returns origin airport name" do
      port = Factory(:port, iata_code: "INN", name: "Innsmouth")
      ent = Factory(:entry, origin_airport: port)

      ss = SearchSetup.new(module_type: 'Entry', user_id: Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid: 'ent_origin_airport_name', operator: 'eq', value: "Innsmouth")
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq "Innsmouth"
    end

    it "updates port code by name" do
      Factory(:port, iata_code: "INN", name: "Innsmouth")
      ent = Factory(:entry)

      expect(mf.process_import(ent, "Innsmouth", Factory(:admin_user))).to eq "Origin Airport set to Innsmouth"
      expect(ent.origin_airport_code).to eq "INN"
    end

    it "returns error message on import when port not found" do
      ent = Factory(:entry)

      expect(mf.process_import(ent, "Innsmouth", Factory(:admin_user))).to eq "Port with name \"Innsmouth\" could not be found."
      expect(ent.origin_airport_code).to be_nil
    end
  end

end
