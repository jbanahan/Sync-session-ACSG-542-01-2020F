describe DrawbackImportLine do
  describe "unallocated" do
    it "should return if no allocations" do
      d = FactoryBot(:drawback_import_line, quantity:10)
      expect(DrawbackImportLine.unallocated.to_a).to eql([d])
    end

    it "should return if unallocated quantity" do
      d = FactoryBot(:drawback_import_line, quantity:10)
      d.drawback_allocations.create!(quantity:9)
      expect(DrawbackImportLine.unallocated.to_a).to eql([d])
    end

    it "should not return if fully allocated" do
      d = FactoryBot(:drawback_import_line, quantity:10)
      d.drawback_allocations.create!(quantity:10)
      expect(DrawbackImportLine.unallocated.to_a).to be_empty
    end
  end

  describe "unallocated_quantity" do
    it "should return difference between quantities and allocations" do
      d = FactoryBot(:drawback_import_line, quantity:10)
      d.drawback_allocations.create!(quantity:9)
      expect(d.unallocated_quantity).to eql(1)
    end
  end

  describe "not_in_duty_calc_file" do
    it "should find line not linked" do
      d1 = FactoryBot(:drawback_import_line)
      d2 = FactoryBot(:drawback_import_line)
      dcl = DutyCalcImportFileLine.create!(:drawback_import_line_id=>d2.id)

      expect(DrawbackImportLine.not_in_duty_calc_file.all).to eq([d1])
    end
  end

  describe "duty_calc_line_legacy" do
    it "should generate line" do
      d = DrawbackImportLine.create!(
        :product=>FactoryBot(:product, :unique_identifier=>"123456"),
        :entry_number=>'12345678901',
        :quantity=>BigDecimal("10.04"),
        :part_number=>"123456",
        :hts_code=>"1234567890",
        :import_date=>Date.new(2010, 4, 1),
        :received_date=>Date.new(2010, 4, 2),
        :port_code=>"4601",
        :box_37_duty=>BigDecimal("100.10"),
        :box_40_duty=>BigDecimal("101.10"),
        :total_invoice_value=>BigDecimal("5000.01"),
        :total_mpf=>BigDecimal("485.00"),
        :country_of_origin_code=>"CN",
        :description=>"MERCH DESC",
        :unit_of_measure=>"EA",
        :unit_price=>BigDecimal("2.045"),
        :rate=>BigDecimal("0.03"),
        :duty_per_unit=>BigDecimal(".153"),
        :compute_code=>"7",
        :ocean=>true
      )
      line = d.duty_calc_line_legacy
      csv = CSV.parse(line).first
      [d.entry_number, "04/01/2010", "04/02/2010", "", "4601", "100.10", "101.10", "", "5000.01", "485.00", "1", "", d.id.to_s, "", "", d.country_of_origin_code, "", "",
      d.part_number, d.part_number, d.hts_code, d.description, d.unit_of_measure, "", "10.040000000", "10.040000000", "", "2.0450000", "", "", "", "0.030000000", "", "", "", "0.153000000", "7", "", "Y"].each_with_index do |v, i|
        expect(csv[i]).to eq(v)
      end
    end
  end

  describe "duty_calc_line_array_standard" do
    it "should generate array" do
      d = DrawbackImportLine.create!(
          :product=>FactoryBot(:product, :unique_identifier=>"123456"),
          :importer=>with_customs_management_id(FactoryBot(:company), '555666'),
          :entry_number=>'12345678901',
          :quantity=>BigDecimal("10.04"),
          :part_number=>"123456",
          :hts_code=>"1234567890",
          :import_date=>Date.new(2010, 4, 1),
          :liquidation_date=>Date.new(2010, 4, 3),
          :port_code=>"4601",
          :box_37_duty=>BigDecimal("100.10"),
          :box_40_duty=>BigDecimal("101.10"),
          :total_invoice_value=>BigDecimal("5000.01"),
          :total_mpf=>BigDecimal("485.00"),
          :country_of_origin_code=>"CN",
          :country_of_export_code=>"IN",
          :description=>"MERCH DESC",
          :unit_of_measure=>"EA",
          :rate=>BigDecimal("0.03"),
          :ref_1=>'ABCDE',
          :ref_2=>'FGHIJ',
          :ocean=>true
      )

      arr = d.duty_calc_line_array_standard
      expect(arr.length).to eq(23)
      expect(arr[0]).to eq('12345678901')
      expect(arr[1]).to eq('04/01/2010')
      expect(arr[2]).to eq('4601')
      expect(arr[3]).to eq('100.10')
      expect(arr[4]).to eq('101.10')
      expect(arr[5]).to eq('04/03/2010')
      expect(arr[6]).to eq('5000.01')
      expect(arr[7]).to eq('485.00')
      expect(arr[8]).to eq('555666')
      expect(arr[9]).to eq('ABCDE')
      expect(arr[10]).to eq('FGHIJ')
      expect(arr[11]).to eq('')
      expect(arr[12]).to eq('CN')
      expect(arr[13]).to eq('IN')
      expect(arr[14]).to eq('123456')
      expect(arr[15]).to eq('1234567890')
      expect(arr[16]).to eq('MERCH DESC')
      expect(arr[17]).to eq('EA')
      expect(arr[18]).to eq('10.040000000')
      expect(arr[19]).to eq('')
      expect(arr[20]).to eq('0.030000000')
      expect(arr[21]).to eq('')
      expect(arr[22]).to eq('Y')
    end

    it "handles nils when generating array" do
      d = DrawbackImportLine.create!(
          :product=>FactoryBot(:product, :unique_identifier=>"123456")
      )

      arr = d.duty_calc_line_array_standard
      expect(arr.length).to eq(23)
      expect(arr[1]).to eq('') # import_date
      expect(arr[5]).to eq('') # liquidation_date
      expect(arr[8]).to eq('') # importer.alliance_customer_number
      expect(arr[22]).to eq('') # ocean
    end
  end

end