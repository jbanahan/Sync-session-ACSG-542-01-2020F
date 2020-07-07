describe OpenChain::ModelFieldDefinition::EntryFieldDefinition do
  describe 'ent_first_billed_date' do
    let :mf do
      ModelField.find_by_uid :ent_first_billed_date
    end
    it "should be first billed date when multiple bills" do
      bi = Factory(:broker_invoice, invoice_date:Date.new(2016, 10, 1))
      Factory(:broker_invoice, invoice_date:Date.new(2016, 10, 2), entry:bi.entry)

      ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_first_billed_date', operator:'eq', value:'2016-10-01')
      expect(ss.result_keys).to eq [bi.entry.id]

      # test in memory export value
      expect(mf.process_export(bi.entry, nil, true)).to eq Date.new(2016, 10, 1)
    end
    it "should be nil when no bills" do
      ent = Factory(:entry)

      ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_first_billed_date', operator:'null')
      expect(ss.result_keys).to eq [ent.id]

      # test in memory export value
      expect(mf.process_export(ent, nil, true)).to be_nil
    end
    it "should be read only" do
      expect(mf.read_only?).to be_truthy
    end
  end
  describe 'ent_container_count' do
    let :mf do
      ModelField.find_by_uid :ent_container_count
    end
    it "should return 0 if no containers" do
      ent = Factory(:entry)
      ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_container_count', operator:'eq', value:'0')
      expect(ss.result_keys).to eq [ent.id]

      # test in memory export value
      expect(mf.process_export(ent, nil, true)).to eq 0
    end
    it "should return container count" do
      ent = Factory(:entry)
      2.times {|i| Factory(:container, entry:ent)}
      ent.reload
      ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_container_count', operator:'eq', value:'2')
      expect(ss.result_keys).to eq [ent.id]

      # test in memory export value
      expect(mf.process_export(ent, nil, true)).to eq 2
    end
  end

  describe 'ent_entry_filer' do
    let :mf do
      ModelField.find_by_uid :ent_entry_filer
    end

    it "should return nil if no entry number" do
      ent = Factory(:entry, entry_number:nil)

      ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_entry_filer', operator:'null')
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to be_nil
    end

    it "should return first five characters of entry number if Canadian" do
      country = Factory(:country, iso_code:'CA')
      ent = Factory(:entry, entry_number:'1324657980', import_country:country)

      ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_entry_filer', operator:'eq', value:'13246')
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq('13246')
    end

    it "should return first three characters of entry number if USA" do
      country = Factory(:country, iso_code:'US')
      ent = Factory(:entry, entry_number:'1324657980', import_country:country)

      ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_entry_filer', operator:'eq', value:'132')
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq('132')
    end

    it "should return first three characters of entry number if no import country specified" do
      ent = Factory(:entry, entry_number:'1324657980', import_country:nil)

      ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_entry_filer', operator:'eq', value:'132')
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq('132')
    end
  end

  describe 'ent_total_miscellaneous_discount' do
    let :mf do
      ModelField.find_by_uid :ent_total_miscellaneous_discount
    end

    it "should return discount sum" do
      ent = Factory(:entry)
      inv = Factory(:commercial_invoice, entry:ent)
      cil1 = Factory(:commercial_invoice_line, commercial_invoice:inv, miscellaneous_discount:10.25)
      cil2 = Factory(:commercial_invoice_line, commercial_invoice:inv, miscellaneous_discount:5.50)
      ent.reload

      ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_total_miscellaneous_discount', operator:'eq', value:'15.75')
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq 15.75
    end
  end

  describe 'ent_open_exception_codes' do
    let :mf do
      ModelField.find_by_uid :ent_open_exception_codes
    end

    it "should return concatenated exception codes" do
      ent = Factory(:entry)
      ent.entry_exceptions.create! code: "D", resolved_date: nil
      ent.entry_exceptions.create! code: "B", resolved_date: nil
      ent.entry_exceptions.create! code: "C", resolved_date: Date.new(2020, 1, 1)
      ent.entry_exceptions.create! code: "A", resolved_date: nil
      ent.entry_exceptions.create! code: "D", resolved_date: nil

      ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_open_exception_codes', operator:'eq', value:"D\nB\nA")
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq "D\nB\nA"
    end
  end

  describe 'ent_resolved_exception_codes' do
    let :mf do
      ModelField.find_by_uid :ent_resolved_exception_codes
    end

    it "should return concatenated exception codes" do
      ent = Factory(:entry)
      ent.entry_exceptions.create! code: "D", resolved_date: Date.new(2020, 1, 1)
      ent.entry_exceptions.create! code: "B", resolved_date: Date.new(2020, 2, 2)
      ent.entry_exceptions.create! code: "C", resolved_date: nil
      ent.entry_exceptions.create! code: "A", resolved_date: Date.new(2020, 3, 3)
      ent.entry_exceptions.create! code: "D", resolved_date: Date.new(2020, 4, 4)

      ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
      ss.search_criterions.build(model_field_uid:'ent_resolved_exception_codes', operator:'eq', value:"D\nB\nA")
      expect(ss.result_keys).to eq [ent.id]

      expect(mf.process_export(ent, nil, true)).to eq "D\nB\nA"
    end
  end

  context 'pga_flag_fields' do
    ["AMS", "APH", "ATF", "DEA", "EPA", "FDA", "FSI", "FWS", "NHT", "NMF", "OMC", "TTB"].each do |agency_code|
      describe "ent_pga_#{agency_code.downcase}" do
        it "should return true when PGA summary for #{agency_code} is present" do
          uid = "ent_pga_#{agency_code.downcase}"
          mf = ModelField.find_by_uid(uid.to_sym)

          ent = Factory(:entry)
          ent.entry_pga_summaries.create!(agency_code: agency_code)

          ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
          ss.search_criterions.build(model_field_uid: uid, operator: "eq", value: true)
          expect(ss.result_keys).to eq [ent.id]

          expect(mf.process_export(ent, nil, true)).to eq true
        end

        it "should return false when PGA summary for #{agency_code} is not present" do
          uid = "ent_pga_#{agency_code.downcase}"
          mf = ModelField.find_by_uid(uid.to_sym)

          ent = Factory(:entry)

          ss = SearchSetup.new(module_type:'Entry', user_id:Factory(:admin_user).id)
          ss.search_criterions.build(model_field_uid: uid, operator: "eq", value: false)
          expect(ss.result_keys).to eq [ent.id]

          expect(mf.process_export(ent, nil, true)).to eq false
        end
      end
    end
  end
end
