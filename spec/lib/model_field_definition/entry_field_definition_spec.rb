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
end
