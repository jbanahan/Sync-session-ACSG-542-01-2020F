describe OpenChain::CustomHandler::AnnInc::AnnProductApiSyncGenerator do

  subject { described_class.new api_client: true}

  describe "process_query_result" do

    let (:us_query_row) {
      [1, "UID", "US", 1, "1234567890", "9876543210", "2468101214", "", 0]
    }

    let (:ca_query_row) {
      [1, "UID", "CA", 1, "1357911131", nil, nil, "", 0]
    }

    it "handles query result, buffering results and returning nothing since this is first product seen" do
      expect(subject.process_query_result us_query_row, {}).to eq []
    end

    it "handles query result, returning the previous row since the id changed" do
      expect(subject.process_query_result us_query_row, {}).to eq []
      row = us_query_row.clone
      row[0] = 100

      result = subject.process_query_result row, {}

      expect(result.length).to eq 1

      api = result.first
      expect(api.syncable_id).to eq 1

      d = api.local_data

      expect(d).to eq({
        "id" => 1,
        "prod_imp_syscode" => "ATAYLOR",
        "prod_uid" => "UID",
        "prod_part_number" => "UID",
        "classifications" => [
          {
            "class_cntry_iso" => "US",
            "tariff_records" => [
              {
                "hts_line_number" => 1,
                "hts_hts_1" => "1234567890",
                "hts_hts_2" => "9876543210",
                "hts_hts_3" => "2468101214"
              }
            ]
          }
        ]
      })
    end

    it "buffers and builds multiple classificaitons for a single product" do
      expect(subject.process_query_result us_query_row, {}).to eq []
      expect(subject.process_query_result ca_query_row, {}).to eq []

      row = us_query_row.clone
      row[0] = 100

      result = subject.process_query_result row, {}

      expect(result.length).to eq 1

      api = result.first
      expect(api.syncable_id).to eq 1

      d = api.local_data

      expect(d).to eq({
        "id" => 1,
        "prod_imp_syscode" => "ATAYLOR",
        "prod_uid" => "UID",
        "prod_part_number" => "UID",
        "classifications" => [
          {
            "class_cntry_iso" => "US",
            "tariff_records" => [
              {
                "hts_line_number" => 1,
                "hts_hts_1" => "1234567890",
                "hts_hts_2" => "9876543210",
                "hts_hts_3" => "2468101214"
              }
            ]
          },
          {
            "class_cntry_iso" => "CA",
            "tariff_records" => [
              {
                "hts_line_number" => 1,
                "hts_hts_1" => "1357911131",
                "hts_hts_2" => nil,
                "hts_hts_3" => nil
              }
            ]
          }
        ]
      })
    end

    it "returns the row immediately if it's the last row" do
      result = subject.process_query_result us_query_row, {last_result: true}
      expect(result.length).to eq 1
    end

    it "creates multiple products for each related style" do
      us_query_row[7] = "UID2\nUID3"
      ca_query_row[7] = "UID2\nUID3"

      # Make sure we're also building up the classificaitons/tariffs as well for each related style
      subject.process_query_result us_query_row, {}
      result = subject.process_query_result ca_query_row, {last_result: true}

      expect(result.length).to eq 3

      # The syncable ids should be identical
      expect(result.map(&:syncable_id).uniq).to eq [1]

      expect(result[0].local_data["prod_uid"]).to eq "UID"
      expect(result[0].local_data["classifications"].length).to eq 2

      expect(result[1].local_data["prod_uid"]).to eq "UID2"
      expect(result[1].local_data["classifications"].length).to eq 2

      expect(result[2].local_data["prod_uid"]).to eq "UID3"
      expect(result[2].local_data["classifications"].length).to eq 2
    end

    it "handles multiple tariff rows by blanking the tariffs" do
      expect(subject.process_query_result us_query_row, {}).to eq []
      row = us_query_row.clone
      row[3] = 2
      row[4] = "6789012345"
      result = subject.process_query_result row, {last_result: true}

      expect(result.length).to eq 1

      d = result.first.local_data

      expect(d).to eq({
        "id" => 1,
        "prod_imp_syscode" => "ATAYLOR",
        "prod_uid" => "UID",
        "prod_part_number" => "UID",
        "classifications" => [
          {
            "class_cntry_iso" => "US",
            "tariff_records" => []
          }
        ]
      })
    end

    it "blanks tariffs of files listed as manual entry processing" do
      us_query_row[8] = true
      result = subject.process_query_result us_query_row, {last_result: true}

      expect(result.length).to eq 1

      d = result.first.local_data

      expect(d).to eq({
        "id" => 1,
        "prod_imp_syscode" => "ATAYLOR",
        "prod_uid" => "UID",
        "prod_part_number" => "UID",
        "classifications" => [
          {
            "class_cntry_iso" => "US",
            "tariff_records" => []
          }
        ]
      })
    end
  end

  describe "query" do
    let (:cdefs) {
      subject.cdefs
    }

    let! (:product) {
      p = Factory(:product, unique_identifier: "UID")
      c = p.classifications.create! country: Factory(:country, iso_code: "US")
      c.update_custom_value! cdefs[:manual_flag], false
      t = c.tariff_records.create! line_number: 1, hts_1: "1234567890", hts_2: "2468101214", hts_3: "1357911131"

      c2 = p.classifications.create! country: Factory(:country, iso_code: "CA")
      c2.update_custom_value! cdefs[:manual_flag], true
      t2 = c2.tariff_records.create! line_number: 1, hts_1: "9876543210"

      p.update_custom_value! cdefs[:related_styles], "ABC\nDEF"

      p
    }


    it "returns valid product query" do
      result = ActiveRecord::Base.connection.execute(subject.query).to_a

      expect(result.size).to eq 2

      expect(result.first).to eq [product.id, "UID", "CA", 1, "9876543210", nil, nil, "ABC\nDEF", 1]
      expect(result.second).to eq [product.id, "UID", "US", 1, "1234567890", "2468101214", "1357911131", "ABC\nDEF", 0]
    end

    it "returns nothing if everything is already synced" do
      product.sync_records.create! trading_partner: "vfitrack", sent_at: Time.zone.now, confirmed_at: Time.zone.now
      result = ActiveRecord::Base.connection.execute(subject.query).to_a
      expect(result.size).to eq 0
    end

    it "allows custom where" do
      c = described_class.new "custom_where" => "iso.iso_code = 'US'", api_client: true

      query = c.query
      result = ActiveRecord::Base.connection.execute(query).to_a

      expect(result.size).to eq 1
      expect(query).not_to include "LIMIT"
    end

    it "returns products that don't have related styles" do
      product.update_custom_value! cdefs[:related_styles], nil
      result = ActiveRecord::Base.connection.execute(subject.query).to_a

      expect(result.size).to eq 2
    end
  end
end
