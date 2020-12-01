describe OpenChain::CustomHandler::Ascena::AscenaInvoiceValidatorHelper do

  let(:validator) { described_class.new }

  describe "audit" do
    it "executes #gather_unrolled and :gather_entry" do
      ent = FactoryBot(:entry, importer_id: 1137, commercial_invoice_numbers: "123456789\n 987654321")
      unrolled_results = double("unrolled_results")
      fenix_results = double("fenix_results")
      unrolled_by_hts_coo = double("unrolled_by_hts_coo")
      fenix_by_hts_coo = double("fenix_by_hts_coo")
      style_list = ["styles"]
      expect(validator).to receive(:gather_unrolled).with("123456789, 987654321", 1137).and_return(unrolled_results)
      expect(validator).to receive(:gather_entry).with(ent).and_return(fenix_results)
      expect(validator).to receive(:sum_per_hts_coo).with(unrolled_results).and_return unrolled_by_hts_coo
      expect(validator).to receive(:arrange_by_hts_coo).with(fenix_results).and_return fenix_by_hts_coo
      expect(validator).to receive(:run_tests).with(unrolled_results, fenix_results, unrolled_by_hts_coo, fenix_by_hts_coo, style_list)
      validator.audit(ent, style_list)
    end
  end

  describe "run_tests" do
    before :each do
      @unrolled = double("unrolled qry results")
      @fenix = double("fenix qry results")
      @unrolled_by_hts_coo = double("unrolled_by_hts_coo")
      @fenix_by_hts_coo = double("fenix_by_hts_coo")
      @style_list = ["styles"]
    end

    it "returns empty if all seven tests succeed" do
      expect(validator).to receive(:invoice_list_diff).with(@unrolled, @fenix).and_return ""
      expect(validator).to receive(:total_per_hts_coo_diff).with(:value, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return ""
      expect(validator).to receive(:total_per_hts_coo_diff).with(:quantity, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return ""
      expect(validator).to receive(:total_diff).with(:value, @unrolled, @fenix).and_return ""
      expect(validator).to receive(:total_diff).with(:quantity, @unrolled, @fenix).and_return ""
      expect(validator).to receive(:hts_list_diff).with(@unrolled, @fenix, @fenix_by_hts_coo).and_return ""
      expect(validator).to receive(:style_list_match).with(@unrolled, @style_list).and_return ""

      error = validator.run_tests(@unrolled, @fenix, @unrolled_by_hts_coo, @fenix_by_hts_coo, @style_list)
      expect(error).to eq ""
    end

    it "returns error if any of the seven tests fails" do
      expect(validator).to receive(:invoice_list_diff).with(@unrolled, @fenix).and_return ""
      expect(validator).to receive(:total_per_hts_coo_diff).with(:value, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return "ERROR: total value per hts/coo"
      expect(validator).to receive(:total_per_hts_coo_diff).with(:quantity, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return ""
      expect(validator).to receive(:total_diff).with(:value, @unrolled, @fenix).and_return ""
      expect(validator).to receive(:total_diff).with(:quantity, @unrolled, @fenix).and_return ""
      expect(validator).to receive(:hts_list_diff).with(@unrolled, @fenix, @fenix_by_hts_coo).and_return ""
      expect(validator).to receive(:style_list_match).with(@unrolled, @style_list).and_return ""

      error = validator.run_tests(@unrolled, @fenix, @unrolled_by_hts_coo, @fenix_by_hts_coo, @style_list)
      expect(error).to eq "ERROR: total value per hts/coo"
    end

    it "produces multiple error messages if there are multiple failing tests" do
      expect(validator).to receive(:invoice_list_diff).with(@unrolled, @fenix).and_return ""
      expect(validator).to receive(:total_per_hts_coo_diff).with(:value, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return "ERROR: total value per hts/coo"
      expect(validator).to receive(:total_per_hts_coo_diff).with(:quantity, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return ""
      expect(validator).to receive(:total_diff).with(:value, @unrolled, @fenix).and_return "ERROR: total value"
      expect(validator).to receive(:total_diff).with(:quantity, @unrolled, @fenix).and_return ""
      expect(validator).to receive(:hts_list_diff).with(@unrolled, @fenix, @fenix_by_hts_coo).and_return ""
      expect(validator).to receive(:style_list_match).with(@unrolled, @style_list).and_return "ERROR: style set"

      error = validator.run_tests(@unrolled, @fenix, @unrolled_by_hts_coo, @fenix_by_hts_coo, @style_list)
      expect(error).to eq "ERROR: total value per hts/coo\nERROR: total value\nERROR: style set"
    end

    it "skips remaining validations if unrolled commercial invoices are missing" do
      expect(validator).to receive(:invoice_list_diff).with(@unrolled, @fenix).and_return "ERROR: missing unrolled invoices"
      allow(validator).to receive(:total_per_hts_coo_diff).with(:value, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return "ERROR: total value per hts/coo"
      allow(validator).to receive(:total_per_hts_coo_diff).with(:quantity, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return ""
      allow(validator).to receive(:total_diff).with(:value, @unrolled, @fenix).and_return "ERROR: total value"
      allow(validator).to receive(:total_diff).with(:quantity, @unrolled, @fenix).and_return ""
      allow(validator).to receive(:hts_list_diff).with(@unrolled, @fenix, @fenix_by_hts_coo).and_return ""
      allow(validator).to receive(:style_list_match).with(@unrolled, @style_list).and_return "ERROR: style set"

      error = validator.run_tests(@unrolled, @fenix, @unrolled_by_hts_coo, @fenix_by_hts_coo, @style_list)
      expect(error).to eq "ERROR: missing unrolled invoices"
    end

    it "skips style-list validation if list isn't included" do
      expect(validator).to receive(:invoice_list_diff).with(@unrolled, @fenix).and_return ""
      expect(validator).to receive(:total_per_hts_coo_diff).with(:value, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return ""
      expect(validator).to receive(:total_per_hts_coo_diff).with(:quantity, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return ""
      expect(validator).to receive(:total_diff).with(:value, @unrolled, @fenix).and_return ""
      expect(validator).to receive(:total_diff).with(:quantity, @unrolled, @fenix).and_return ""
      expect(validator).to receive(:hts_list_diff).with(@unrolled, @fenix, @fenix_by_hts_coo).and_return ""

      # workaround for Rspec 2.12 bug affecting #should_not_receive (https://github.com/rspec/rspec-mocks/issues/228)
      allow(validator).to receive(:style_list_match).with(@unrolled, @style_list).and_return "This method should not have been called!"

      error = validator.run_tests(@unrolled, @fenix, @unrolled_by_hts_coo, @fenix_by_hts_coo)
      expect(error).to eq ""
    end
  end

  describe "invoice_list_diff" do
    before do
      @ent = FactoryBot(:entry, importer_id: 1137, commercial_invoice_numbers: "123456789")

      fenix_ci = FactoryBot(:commercial_invoice, entry: @ent, invoice_number: '123456789', importer_id: 1137)
      fenix_cil = FactoryBot(:commercial_invoice_line, commercial_invoice: fenix_ci)
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: fenix_cil)

      unrolled_ci = FactoryBot(:commercial_invoice, entry: nil, invoice_number: '123456789', importer_id: 1137)
      unrolled_cil = FactoryBot(:commercial_invoice_line, commercial_invoice: unrolled_ci)
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: unrolled_cil)
    end

    it "returns empty if every invoice on the entry has at least one unrolled invoice" do
      unrolled = validator.send(:gather_unrolled, "123456789", @ent.importer_id)
      fenix = validator.send(:gather_entry, @ent)

      expect(validator.invoice_list_diff(unrolled, fenix)).to eq ""
    end

    it "returns list of missing unrolled invoices" do
      ci = FactoryBot(:commercial_invoice, entry: @ent, invoice_number: '111111111', importer_id: 1137)
      cil = FactoryBot(:commercial_invoice_line, commercial_invoice: ci)
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: cil)
      unrolled = validator.send(:gather_unrolled, "123456789", @ent.importer_id)
      fenix = validator.send(:gather_entry, @ent)

      expect(validator.invoice_list_diff(unrolled, fenix)).to eq "Missing unrolled invoices: 111111111"
    end
  end

  describe "total_per_hts_coo_diff" do
    before do
      @unrolled_by_hts_coo = double("unrolled_by_hts_coo")
      @fenix_by_hts_coo = double("fenix_by_hts_coo")
    end

    it "concatenates output of :check_fenix_against_unrolled and :check_unrolled_against_fenix" do
      expect(validator).to receive(:check_fenix_against_unrolled).with(:value, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return ["error message 1"]
      expect(validator).to receive(:check_unrolled_against_fenix).with(:value, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return ["error message 2"]
      error = validator.total_per_hts_coo_diff(:value, @unrolled_by_hts_coo, @fenix_by_hts_coo)

      expect(error).to eq "Total value per HTS/country-of-origin:\nerror message 1\nerror message 2\n"
    end

    it "returns empty if output of methods is empty" do
      expect(validator).to receive(:check_fenix_against_unrolled).with(:value, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return []
      expect(validator).to receive(:check_unrolled_against_fenix).with(:value, @unrolled_by_hts_coo, @fenix_by_hts_coo).and_return []
      error = validator.total_per_hts_coo_diff(:value, @unrolled_by_hts_coo, @fenix_by_hts_coo)

      expect(error).to eq ""
    end
  end

  describe "check_fenix_against_unrolled" do
    let(:unrolled_hts_coo) do
      {"6106200010" => {"US" => {quantity: 7, value: 5}}, "1206200010" => {"CN" => {quantity: 10, value: 20}}}
    end

    it "returns empty if fenix hash matches all hts/coo pairs from unrolled hash" do
      fenix_hts_coo = {"6106200010" => {"US" => {quantity: 7, value: 5}}, "1206200010" => {"CN" => {quantity: 10, value: 20}}}
      expect(validator.check_fenix_against_unrolled(:value, unrolled_hts_coo, fenix_hts_coo)).to eq []
    end

    it "returns error string if fenix hash contains one or more hts/coo pairs missing from unrolled hash" do
      fenix_hts_coo = {"6106200010" => {"US" => {quantity: 7, value: 5}},
                       "1206200010" => {"US" => {quantity: 10, value: 20, subheader_number: 1, customs_line_number: 2}}}
      expect(validator.check_fenix_against_unrolled(:value, unrolled_hts_coo, fenix_hts_coo)).to eq ["B3 Sub Hdr # 1 / B3 Line # 2 has $20.00 value for 1206.20.0010 / US. Unrolled Invoice has $0.00."]
    end

    it "returns error string if there is a mismatch between corresponding hts/coo pairs" do
      fenix_hts_coo = {"6106200010" => {"US" => {quantity: 7, value: 5}},
                       "1206200010" => {"CN" => {quantity: 10, value: 25, subheader_number: 1, customs_line_number: 2}}}

      expect(validator.check_fenix_against_unrolled(:value, unrolled_hts_coo, fenix_hts_coo)).to eq ["B3 Sub Hdr # 1 / B3 Line # 2 has $25.00 value for 1206.20.0010 / CN. Unrolled Invoice has $20.00."]
    end
  end

  describe "check_unrolled_against_fenix" do
    let(:fenix_hts_coo) do
      {"6106200010" => {"US" => {quantity: 7, value: 5}}, "1206200010" => {"CN" => {quantity: 10, value: 20}}}
    end

    it "returns empty if unrolled hash contains no hts/coo pairs missing from fenix hash" do
      unrolled_hts_coo = {"6106200010" => {"US" => {quantity: 7, value: 5}}, "1206200010" => {"CN" => {quantity: 10, value: 20}}}
      expect(validator.check_unrolled_against_fenix(:quantity, unrolled_hts_coo, fenix_hts_coo)).to eq []
    end

    it "returns error string if unrolled hash contains one or more hts/coo pairs missing from fenix hash" do
      unrolled_hts_coo = {"6106200010" => {"US" => {quantity: 7, value: 5}, "CN" => {quantity: 1, value: 2}},
                          "1206200010" => {"CN" => {quantity: 10, value: 20}}}
      expect(validator.check_unrolled_against_fenix(:quantity, unrolled_hts_coo, fenix_hts_coo)).to eq ["B3 has 0 quantity for 6106.20.0010 / CN. Unrolled Invoice has 1."]
    end
  end

  describe "total_diff" do
    before do
      @ent = FactoryBot(:entry, importer_id: 1137, commercial_invoice_numbers: "123456789")

      fenix_ci = FactoryBot(:commercial_invoice, entry: @ent, invoice_number: '123456789', importer_id: 1137)
      fenix_cil = FactoryBot(:commercial_invoice_line, commercial_invoice: fenix_ci, value: 10)
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: fenix_cil)

      unrolled_ci = FactoryBot(:commercial_invoice, entry: nil, invoice_number: '123456789', importer_id: 1137)
      unrolled_cil = FactoryBot(:commercial_invoice_line, commercial_invoice: unrolled_ci, value: 7)
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: unrolled_cil)
      @unrolled_cil_2 = FactoryBot(:commercial_invoice_line, commercial_invoice: unrolled_ci, value: 3)
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: @unrolled_cil_2)
    end

    it "returns empty if the summed field of the unrolled invoices matches that of the corresponding Fenix entry" do
      unrolled = validator.send(:gather_unrolled, "123456789", @ent.importer_id)
      fenix = validator.send(:gather_entry, @ent)

      expect(validator.total_diff(:value, unrolled, fenix)).to eq ""
    end

    it "compares the summed fields if the summed field of the unrolled invoices doesn't match that of the corresponding Fenix entry" do
      @unrolled_cil_2.update_attributes(value: 5)
      unrolled = validator.send(:gather_unrolled, "123456789", @ent.importer_id)
      fenix = validator.send(:gather_entry, @ent)

      expect(validator.total_diff(:value, unrolled, fenix)).to eq "B3 has total value of $10.00. Unrolled Invoices have $12.00.\n"
    end
  end

  describe "hts_list_diff" do
    before do
      @ent = FactoryBot(:entry, importer_id: 1137, commercial_invoice_numbers: '123456789')

      fenix_ci = FactoryBot(:commercial_invoice, entry: @ent, invoice_number: '123456789', importer_id: 1137)
      fenix_cil = FactoryBot(:commercial_invoice_line, commercial_invoice: fenix_ci, country_origin_code: "CA", subheader_number: 2, customs_line_number: 1)
      @fenix_cit = FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: fenix_cil, hts_code: '6106200010' )

      fenix_cil_2 = FactoryBot(:commercial_invoice_line, commercial_invoice: fenix_ci, country_origin_code: "US", subheader_number: 2, customs_line_number: 2)
      @fenix_cit_2 = FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: fenix_cil_2, hts_code: '6106200010' )

      unrolled_ci = FactoryBot(:commercial_invoice, entry: nil, invoice_number: '123456789', importer_id: 1137)
      unrolled_cil = FactoryBot(:commercial_invoice_line, commercial_invoice: unrolled_ci)
      @unrolled_cit = FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: unrolled_cil, hts_code: '6106200010')
    end

    it "returns empty if the unrolled invoices contain the same HTS numbers as the corresponding Fenix entry" do
      fenix = validator.send(:gather_entry, @ent)
      unrolled = validator.send(:gather_unrolled, "123456789", @ent.importer_id)
      fenix_by_hts_coo = validator.arrange_by_hts_coo(fenix)

      expect(validator.hts_list_diff(unrolled, fenix, fenix_by_hts_coo)).to eq ""
    end

    it "compares the HTS sets if the unrolled invoices don't contain the same HTS numbers as the corresponding Fenix entry" do
      @unrolled_cit.update_attributes(hts_code: "1111111111")
      @fenix_cit.update_attributes(hts_code: "2222222222")
      @fenix_cit_2.update_attributes(hts_code: "2222222222")

      fenix = validator.send(:gather_entry, @ent)
      fenix_by_hts_coo = validator.arrange_by_hts_coo(fenix)
      unrolled = validator.send(:gather_unrolled, "123456789", @ent.importer_id)

      expect(validator.hts_list_diff(unrolled, fenix, fenix_by_hts_coo)).to eq "B3 missing HTS code(s) on Unrolled Invoices: 1111.11.1111\nUnrolled Invoices missing HTS code(s) on B3: 2222.22.2222 (B3 Sub Hdr # 2 / B3 Line # 1; B3 Sub Hdr # 2 / B3 Line # 2)\n"
    end
  end

  describe "style_set_match" do
    before do
      @ent = FactoryBot(:entry, importer_id: 1137, commercial_invoice_numbers: "123456789")

      unrolled_ci = FactoryBot(:commercial_invoice, entry: nil, invoice_number: '123456789', importer_id: 1137)
      unrolled_cil = FactoryBot(:commercial_invoice_line, commercial_invoice: unrolled_ci, part_number: '1278-603-494')
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: unrolled_cil)
      @unrolled_cil_2 = FactoryBot(:commercial_invoice_line, commercial_invoice: unrolled_ci, part_number: '5847-603-494')
      FactoryBot(:commercial_invoice_tariff, commercial_invoice_line: @unrolled_cil_2)

      @unrolled = validator.send(:gather_unrolled, "123456789", @ent.importer_id)
    end

    it "returns empty if the unrolled invoices don't contain any of the specified styles" do
      style_list = ['1111']
      expect(validator.style_list_match(@unrolled, style_list)).to eq ""
    end

    it "returns list of if the unrolled invoices contain any of the specified styles" do
      style_list = ['1278', '5847']
      expect(validator.style_list_match(@unrolled, style_list)).to eq "Unrolled Invoices include flagged style(s): 1278, 5847\n"
    end
  end

  describe "arrange_by_hts_coo" do
    it "converts query output into a nested hash keyed by hts/coo" do
      fenix_results = [{"invoice_number"=>"123456789", "country_origin_code"=>"US", "hts_code"=>"6106200010", "quantity"=>7, "value"=>150, "subheader_number"=>1, "customs_line_number"=>2}]
      converted = {"6106200010" => {"US" => {invoice_number: "123456789", quantity: 7, value: 150, subheader_number: 1, customs_line_number: 2}}}
      expect(validator.arrange_by_hts_coo(fenix_results)).to eq converted
    end
  end

  describe "sum_per_hts_coo" do
    it "returns hash summing query output values and totals by hts/coo" do
      unrolled_results = [{"country_origin_code"=>"US", "hts_code"=>"1206200010", "quantity"=>2, "value"=>5},
                          {"country_origin_code"=>"CA", "hts_code"=>"1206200010", "quantity"=>4, "value"=>10},
                          {"country_origin_code"=>"CA", "hts_code"=>"1206200010", "quantity"=>6, "value"=>15},
                          {"country_origin_code"=>"US", "hts_code"=>"6106200010", "quantity"=>8, "value"=>20},
                          {"country_origin_code"=>"US", "hts_code"=>"6106200010", "quantity"=>10, "value"=>25}]
      result = {"1206200010" => {"US" => {quantity: 2, value: 5 }, "CA" => {quantity: 10, value: 25} },
                "6106200010" => {"US" => {quantity: 18, value: 45}}}
      expect(validator.sum_per_hts_coo(unrolled_results)).to eq result
    end
  end
end
