describe OpenChain::CustomHandler::Crocs::CrocsDrawbackProcessor do
  describe "process_entries_by_arrival_date" do

    it "should find entries by customer and date range" do
      imp = with_customs_management_id(FactoryBot(:company), 'CROCS')
      e1 = FactoryBot(:entry, importer_id:imp.id, arrival_date:1.year.ago)
      e2 = FactoryBot(:entry, importer_id:imp.id, arrival_date:1.week.ago)
      e3 = FactoryBot(:entry, importer_id:imp.id, arrival_date:1.week.from_now)
      e4 = FactoryBot(:entry, importer_id:imp.id, arrival_date:1.year.from_now)
      e5 = FactoryBot(:entry, importer_id:FactoryBot(:company).id, arrival_date:1.week.from_now)
      expect(described_class).to receive(:process_entries) do |arg|
        expect(arg.to_a).to eq([e2, e3])
      end
      described_class.process_entries_by_arrival_date 1.month.ago, 1.month.from_now
    end
  end

  describe "find_shipment_lines" do
    before :each do
      @imp = with_customs_management_id(FactoryBot(:company), 'CROCS')
      @p = FactoryBot(:product, unique_identifier:'CROCS-S12345')
      @defs = described_class.prep_custom_definitions [:shpln_po, :shpln_received_date, :shpln_coo]
      s = FactoryBot(:shipment, importer:@imp)
      @s_line = s.shipment_lines.create!(product:@p, quantity:10)
      @s_line.update_custom_value! @defs[:shpln_po], '00022671OT00010'
      @s_line.update_custom_value! @defs[:shpln_received_date], Time.now.to_date
      @s_line.update_custom_value! @defs[:shpln_coo], 'CN'

      @c_line = FactoryBot(:commercial_invoice_line, po_number:'USA0022671', quantity:10, part_number:'S12345', country_origin_code:'CN')
      @c_line.entry.update_attributes(arrival_date:3.days.ago)

    end
    it "should find with po / style / date / coo match " do
      found = described_class.new.find_shipment_lines @c_line
      expect(found.size).to eq(1)
      expect(found.first).to eq(@s_line)
    end
    it "should not find receipts more than 60 days after arrival" do
      @s_line.update_custom_value! @defs[:shpln_received_date], 70.days.from_now
      expect(described_class.new.find_shipment_lines(@c_line)).to be_empty
    end
    it "should not find receipts before arrival" do
      @s_line.update_custom_value! @defs[:shpln_received_date], @c_line.entry.arrival_date - 1.day
      expect(described_class.new.find_shipment_lines(@c_line)).to be_empty
    end
    it "should not find wrong style for po" do
      @s_line.product.update_attributes(unique_identifier:'CROCS-SOMETHINGELSE')
      expect(described_class.new.find_shipment_lines(@c_line)).to be_empty
    end
    it "should not find wrong po" do
      @s_line.update_custom_value! @defs[:shpln_po], '05555555OT00010'
      expect(described_class.new.find_shipment_lines(@c_line)).to be_empty
    end
    it "should not find wrong customer" do
      shp = @s_line.shipment
      shp.importer = FactoryBot(:company)
      shp.save!
      r = described_class.new.find_shipment_lines(@c_line)
      expect(r).to be_empty
    end
    it "should not find wrong country of origin" do
      @s_line.update_custom_value! @defs[:shpln_coo], 'JP'
      expect(described_class.new.find_shipment_lines(@c_line)).to be_empty
    end
  end

  describe "get_part_number" do
    it 'should be sku-coo' do
      defs = described_class.prep_custom_definitions [:shpln_coo, :shpln_sku]
      s_line = FactoryBot(:shipment_line)
      s_line.update_custom_value! defs[:shpln_coo], 'CN'
      s_line.update_custom_value! defs[:shpln_sku], 'MYSKU'
      p = described_class.new.get_part_number s_line, nil # commercial invoice line shouldn't be used
      expect(p).to eq('MYSKU-CN')
    end
  end

  describe "get_country_of_origin" do
    it 'should pull from shipment line' do
      # not pulling from commercial invoice line to stay consistent with get_part_number
      defs = described_class.prep_custom_definitions [:shpln_coo]
      s_line = FactoryBot(:shipment_line)
      s_line.update_custom_value! defs[:shpln_coo], 'CN'
      expect(described_class.new.get_country_of_origin(s_line, nil)).to eq('CN')
    end
  end

  describe "get_received_date" do
    it 'should pull from shipment line custom value' do
      defs = described_class.prep_custom_definitions [:shpln_received_date]
      s_line = FactoryBot(:shipment_line)
      s_line.update_custom_value! defs[:shpln_received_date], Date.new(2013, 10, 11)
      expect(described_class.new.get_received_date(s_line).to_date).to eq(Date.new(2013, 10, 11))
    end
  end

  describe "format_po_number" do
    it "should format po number from all the crap formats" do
      pos = [
        '1234567', # simple
        'USA1234567', # country format
        'USA 1234567', # country format w/ space
        '01234567OT00010', # warehouse format
        '01234567_OT_00010', # warehouse format w/ underscores
        '1234567_OT_00010', # warehouse format w/ underscores, no leading zero
        '00010_1234567_O8', # reversed format
        '1234567 OD', # space format
      ]
      pos.each {|p| expect(described_class.new.format_po_number(p)).to eq('1234567')}
    end
  end
end
