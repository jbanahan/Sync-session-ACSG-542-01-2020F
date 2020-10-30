describe SearchQuery do
  let(:search_setup) do
    ss = SearchSetup.new(module_type: "Product")
    ss.search_columns.build(model_field_uid: 'prod_uid', rank: 0)
    ss.search_columns.build(model_field_uid: 'prod_name', rank: 1)
    ss.sort_criterions.build(model_field_uid: 'prod_name', rank: 0)
    ss.search_criterions.build(model_field_uid: 'prod_name', operator: 'in', value: "A\nB")
    ss
  end

  let!(:search_query) { described_class.new search_setup, User.new }
  let!(:product_1) { Factory(:product, name: 'B') }
  let!(:product_2) { Factory(:product, name: 'A') }
  let!(:product_3) { Factory(:product, name: 'C') }

  before do
    allow(Product).to receive(:search_where).and_return("1=1")
  end

  describe "execute" do
    it "returns array of arrays" do
      r = search_query.execute(per_page: 1000)
      expect(r.size).to eq(2)
      expect(r[0][:row_key]).to eq(product_2.id)
      expect(r[0][:result][0]).to eq(product_2.unique_identifier)
      expect(r[0][:result][1]).to eq(product_2.name)
      expect(r[1][:row_key]).to eq(product_1.id)
      expect(r[1][:result][0]).to eq(product_1.unique_identifier)
      expect(r[1][:result][1]).to eq(product_1.name)
    end

    it "adds extra_where clause" do
      search_query = described_class.new search_setup, User.new, extra_where: "products.id = #{product_1.id}"
      r = search_query.execute
      expect(r.size).to eq(1)
      expect(r[0][:row_key]).to eq(product_1.id)
    end

    it "yields with loop of arrays and return nil" do
      r = []
      expect(search_query.execute(per_page: 1000) {|row_hash| r << row_hash}).to be_nil
      expect(r[0][:row_key]).to eq(product_2.id)
      expect(r[0][:result][0]).to eq(product_2.unique_identifier)
      expect(r[0][:result][1]).to eq(product_2.name)
      expect(r[1][:row_key]).to eq(product_1.id)
      expect(r[1][:result][0]).to eq(product_1.unique_identifier)
      expect(r[1][:result][1]).to eq(product_1.name)
    end

    it "processes values via ModelField#process_query_result" do
      Factory(:tariff_record, hts_1: '1234567890', classification: Factory(:classification, product: product_1))
      search_setup.search_columns.build(model_field_uid: 'hts_hts_1', rank: 2)
      r = search_query.execute per_page: 1000
      expect(r[1][:result][2]).to eq("1234.56.7890")
    end

    it "prevents DISTINCT from combining child level values in a multi-level query" do
      Factory(:tariff_record, hts_1: '1234567890', classification: Factory(:classification, product: product_1))
      Factory(:tariff_record, hts_1: '1234567890', classification: Factory(:classification, product: product_1))

      search_setup.search_columns.build(model_field_uid: 'hts_hts_1', rank: 2)
      r = search_query.execute per_page: 1000
      expect(r[1][:result][2]).to eq("1234.56.7890")
      expect(r[1][:row_key]).to eq(r[2][:row_key])
      expect(r[2][:result][2]).to eq("1234.56.7890")
    end

    it "combines child level values in a multi-level query if no child level column is selected" do
      search_setup.search_criterions.first.value = product_1.name.to_s
      Factory(:tariff_record, hts_1: '1234567890', classification: Factory(:classification, product: product_1))
      Factory(:tariff_record, hts_1: '1234567890', classification: Factory(:classification, product: product_1))
      r = search_query.execute per_page: 1000
      expect(r.size).to eq(1)
      expect(r[0][:result][1]).to eq(product_1.name)
      expect(r[0][:row_key]).to eq(product_1.id)
    end

    it "shows a blank value for null child values when a column is selected for it by the user" do
      search_setup.search_columns.build(model_field_uid: 'class_cntry_iso', rank: 2)
      search_setup.search_criterions.first.value = product_1.name.to_s
      r = search_query.execute per_page: 1000
      expect(r.size).to eq(1)
      expect(r[0][:row_key]).to eq(product_1.id)
      expect(r[0][:result][2]).to eq("")
    end

    it "handles _blank columns" do
      search_setup.search_columns.build(model_field_uid: '_blank', rank: 2)
      r = search_query.execute
      expect(r[1][:result][2]).to eq("")
    end

    it "secures query" do
      allow(Product).to receive(:search_where).and_return("products.name = 'B'")
      r = search_query.execute per_page: 1000
      expect(r.size).to eq(1)
      expect(r[0][:row_key]).to eq(product_1.id)
    end

    it "sorts at multiple levels" do
      # When multi level sorting, if the parent level doesn't have a sort
      # use the id column to ensure that lines are always grouped together
      # by their parent level

      search_setup.sort_criterions.first.model_field_uid = 'hts_hts_1'
      search_setup.sort_criterions.build(model_field_uid: 'class_cntry_iso', rank: 2)
      search_setup.search_columns.build(model_field_uid: 'class_cntry_iso', rank: 2)
      search_setup.search_columns.build(model_field_uid: 'hts_hts_1', rank: 3)

      country_ax = Factory(:country, iso_code: 'AX')
      country_bx = Factory(:country, iso_code: 'BX')
      # building these in a jumbled order so the test can properly sort them
      tr2_a_3 = Factory(:tariff_record, hts_1: '311111111', classification: Factory(:classification, country: country_ax, product: product_2))
      tr1_b_9 = Factory(:tariff_record, hts_1: '911111111', classification: Factory(:classification, country: country_bx, product: product_1))
      Factory(:tariff_record, hts_1: '511111111', classification: tr1_b_9.classification, line_number: 2)
      tr1_a_9 = Factory(:tariff_record, hts_1: '911111111', classification: Factory(:classification, country: country_ax, product: product_1))
      Factory(:tariff_record, hts_1: '511111111', classification: tr1_a_9.classification, line_number: 2)
      Factory(:tariff_record, hts_1: '111111111', classification: tr2_a_3.classification, line_number: 2)

      r = search_query.execute per_page: 1000
      expect(r.size).to eq(6)
      4.times { |i| expect(r[i][:row_key]).to eq(product_1.id) }
      (4..5).each { |i| expect(r[i][:row_key]).to eq(product_2.id) }
      (0..1).each { |i| expect(r[i][:result][2]).to eq('AX') }
      (2..3).each { |i| expect(r[i][:result][2]).to eq('BX') }
      (4..5).each { |i| expect(r[i][:result][2]).to eq('AX') }
      expect(r[0][:result][3]).to start_with '5'
      expect(r[1][:result][3]).to start_with '9'
      expect(r[2][:result][3]).to start_with '5'
      expect(r[3][:result][3]).to start_with '9'
      expect(r[4][:result][3]).to start_with '1'
      expect(r[5][:result][3]).to start_with '3'
    end

    it "does not bomb on IN lists with blank values" do
      product_3.update name: ""
      search_setup.search_criterions[0].value = ""
      r = search_query.execute per_page: 1000
      expect(r.size).to eq(1)

      expect(r[0][:row_key]).to eq(product_3.id)
    end

    it "does not bomb on IN lists with slashes in a value" do
      product_3.update name: "testing"
      search_setup.search_criterions[0].value = "test\\\ntesting"
      r = search_query.execute per_page: 1000
      expect(r.size).to eq(1)

      expect(r[0][:row_key]).to eq(product_3.id)
    end

    it "handles relative fields referencing different core modules" do
      # Make sure that the search criterion's value is the only thing referencing a different module level so
      # that we're sure that we're testing the code that handles collecting this field's core module
      classification = Factory(:classification, product: product_1)
      classification.update_column :updated_at, 1.day.from_now # rubocop:disable Rails/SkipsModelValidations

      search_setup.search_criterions.clear
      search_setup.search_criterions.build(model_field_uid: 'prod_created_at', operator: 'bfld', value: "class_updated_at")
      r = search_query.execute per_page: 1000
      expect(r[0][:result][0]).to eq(product_1.unique_identifier)
    end

    it "adds an inner join optimization when pagination options exist" do
      expect(search_query.to_sql(per_page: 100)).to include "AS inner_opt ON "
    end

    it "defaults to using the max_results from search_setup as the query LIMIT for a normal user" do
      search_query.user.sys_admin = false
      expect(search_query.to_sql).to include "LIMIT 25000"
    end

    it "defaults to using the max_results from search_setup as the query LIMIT for a sysadmin" do
      search_query.user.sys_admin = true
      expect(search_query.to_sql).to include "LIMIT 100000"
    end

    it "handles search_columns that have been removed/disabled" do
      # We can simulate a disabled column by just using a bogus model field uid
      search_setup.search_columns.build(model_field_uid: 'prod_not_a_field', rank: 2)

      r = search_query.execute(per_page: 1000)
      expect(r.size).to eq 2
      expect(r[0][:result][2]).to eq ""
    end

    it "handles search_criterions that have been removed/disabled" do
      # We can simulate a disabled column by just using a bogus model field uid
      search_setup.search_criterions.build(model_field_uid: 'prod_not_a_field', operator: 'in', value: "A\nB")

      r = search_query.execute(per_page: 1000)
      expect(r.size).to eq 0
    end

    it "handles sorts that have been removed/disabled" do
      search_setup.sort_criterions.build(model_field_uid: 'prod_not_a_field', rank: 0)
      r = search_query.execute(per_page: 1000)
      expect(r.size).to eq 2
    end

    context "excessive results" do
      it "raises an error if the maximum number of results is exceeded and the 'raise max results error' flag is true" do
        allow(search_query.search_setup).to receive(:max_results).and_return 1
        expect {search_query.execute(per_page: 1000, raise_max_results_error: true)}
          .to raise_error SearchExceedsMaxResultsError, "Your query returned 1+ results.  Please adjust your parameter settings to reduce the amount of results."
      end

      it "raises an error if the maximum number of results is reached and the 'raise max results error' flag is true" do
        allow(search_query.search_setup).to receive(:max_results).and_return 2
        expect {search_query.execute(per_page: 1000, raise_max_results_error: true)}
          .to raise_error SearchExceedsMaxResultsError, "Your query returned 2+ results.  Please adjust your parameter settings to reduce the amount of results."
      end

      it "does not raise an error if the maximum number of results is exceeded but the 'raise max results error' flag is false" do
        allow(search_query.search_setup).to receive(:max_results).and_return 1
        r = search_query.execute(per_page: 1000, raise_max_results_error: false)
        expect(r.size).to eq 2
      end

      it "does not raise an error if the maximum number of results is exceeded with no 'raise max results error' flag value provided" do
        allow(search_query.search_setup).to receive(:max_results).and_return 1
        r = search_query.execute(per_page: 1000)
        expect(r.size).to eq 2
      end
    end

    context "custom_values" do
      let!(:custom_definition) { Factory(:custom_definition, module_type: "Product", data_type: :string) }

      before do
        product_1.update_custom_value! custom_definition, "MYVAL"
      end

      it "supports columns" do
        search_setup.search_columns.build(model_field_uid: "*cf_#{custom_definition.id}", rank: 2)
        r = search_query.execute
        expect(r[0][:result][2]).to eq("")
        expect(r[1][:result][2]).to eq("MYVAL")
      end

      it "supports criterions" do
        search_setup.search_criterions.build(model_field_uid: "*cf_#{custom_definition.id}", operator: "eq", value: "MYVAL")
        r = search_query.execute
        expect(r.size).to eq(1)
        expect(r[0][:row_key]).to eq(product_1.id)
      end

      it "supports sorts" do
        product_2.update_custom_value! custom_definition, "AVAL"
        search_setup.sort_criterions.first.model_field_uid = "*cf_#{custom_definition.id}"
        r = search_query.execute
        expect(r.size).to eq(2)
        expect(r[0][:row_key]).to eq(product_2.id)
        expect(r[1][:row_key]).to eq(product_1.id)
      end
    end

    context "pagination" do
      it "paginates" do
        crit = search_setup.search_criterions.first
        crit.operator = "sw"
        crit.value = "D"
        10.times do |i|
          Factory(:product, name: "D#{i}")
        end
        r = search_query.execute per_page: 2, page: 2
        expect(r.size).to eq(2)
        expect(r[0][:result][1]).to eq("D2")
        expect(r[1][:result][1]).to eq("D3")
      end

      it "paginates child items across multiple pages" do
        search_setup.search_columns.build(model_field_uid: 'class_cntry_iso', rank: 2)
        search_setup.sort_criterions.build(model_field_uid: 'class_cntry_iso', rank: 1)

        crit = search_setup.search_criterions.first
        crit.operator = "eq"
        crit.value = product_1.name

        6.times do |_i|
          product_1.classifications.create! country: Factory(:country)
        end

        c = product_1.classifications.joins(:country).order("countries.iso_code ASC")

        r = search_query.execute per_page: 2, page: 2
        expect(r.size).to eq(2)
        expect(r[0][:row_key]).to eq(product_1.id)
        expect(r[0][:result][2]).to eq(c[2].country.iso_code)
        expect(r[1][:row_key]).to eq(product_1.id)
        expect(r[1][:result][2]).to eq(c[3].country.iso_code)

        r = search_query.execute per_page: 2, page: 3
        expect(r.size).to eq(2)
        expect(r[0][:row_key]).to eq(product_1.id)
        expect(r[0][:result][2]).to eq(c[4].country.iso_code)
        expect(r[1][:row_key]).to eq(product_1.id)
        expect(r[1][:result][2]).to eq(c[5].country.iso_code)
      end
    end

    it "distributes reads by default" do
      expect(search_query).to receive(:distribute_reads).and_yield
      search_query.execute
    end

    it "does not distribute reads if instructed" do
      expect(search_query).not_to receive(:distribute_reads)
      search_query.execute use_replica: false
    end
  end

  describe "count" do
    it "returns row count for multi level query" do
      Factory(:tariff_record, hts_1: '1234567890', classification: Factory(:classification, product: product_1))
      search_setup.search_columns.build(model_field_uid: 'hts_hts_1', rank: 2)
      expect(search_query.count).to eq(2)
    end

    it "handles multiple blanks" do
      search_setup.search_columns.build(model_field_uid: '_blank', rank: 10)
      search_setup.search_columns.build(model_field_uid: '_blank', rank: 11)
      expect(search_query.count).to eq(2)
    end

    it "distributes reads by default" do
      expect(search_query).to receive(:distribute_reads).and_yield
      search_query.count
    end

    it "does not distribute reads if instructed" do
      expect(search_query).not_to receive(:distribute_reads)
      search_query.count use_replica: false
    end
  end

  describe "result_keys" do
    it "returns unique key list for multi level query" do
      tr = Factory(:tariff_record, hts_1: '1234567890', classification: Factory(:classification, product: product_1))
      Factory(:tariff_record, hts_1: '9876543210', line_number: 2, classification: tr.classification)
      search_setup.search_columns.build(model_field_uid: 'hts_hts_1', rank: 2)
      keys = search_query.result_keys
      expect(keys).to eq([product_2.id, product_1.id])
    end

    it "distributes reads by default" do
      expect(search_query).to receive(:distribute_reads).and_yield
      search_query.result_keys
    end

    it "does not distribute reads if instructed" do
      expect(search_query).not_to receive(:distribute_reads)
      search_query.result_keys use_replica: false
    end
  end

  describe "unique_parent_count" do
    it "returns parent count when there are details" do
      search_setup.search_columns.build(model_field_uid: 'class_cntry_iso', rank: 2)
      2.times {|_i| Factory(:classification, product: product_1)}
      expect(search_query.count).to eq(3) # confirming we're setup properly
      expect(search_query.unique_parent_count).to eq(2) # the real test
    end

    it "distributes reads by default" do
      expect(search_query).to receive(:distribute_reads).and_yield
      search_query.unique_parent_count
    end

    it "does not distribute reads if instructed" do
      expect(search_query).not_to receive(:distribute_reads)
      search_query.unique_parent_count use_replica: false
    end
  end
end
