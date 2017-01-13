require 'spec_helper'

describe OpenChain::Report::HmStatisticsReport do
  let!(:day_before) {DateTime.new(2016,01,14)}
  let!(:assigned_day) {DateTime.new(2016,01,15)}
  let!(:day_after) {DateTime.new(2016,01,16)}
  let!(:report) { described_class.new }

  describe "run_report" do
    after { @temp.close! if @temp }

    it "runs report with basic info" do
      u = Factory(:user, time_zone: "Eastern Time (US & Canada)")
      ent = Factory(:entry, entry_number: "ent num", export_country_codes: "US", master_bills_of_lading: "master", house_bills_of_lading: "house", release_date: assigned_day, customer_number: "HENNE", transport_mode_code: "40")
      ci = Factory(:commercial_invoice, entry: ent, invoice_number: "123456")
      cil = Factory(:commercial_invoice_line, commercial_invoice: ci, hmf: 1, prorated_mpf: 2, cotton_fee: 3)
      cit = Factory(:commercial_invoice_tariff, commercial_invoice_line: cil, entered_value: 1, duty_amount: 2)

      ent_2 = Factory(:entry, entry_number: "ent num", export_country_codes: "US", master_bills_of_lading: "master", house_bills_of_lading: "house", release_date: assigned_day, customer_number: "HENNE", transport_mode_code: "10")
      ci_2 = Factory(:commercial_invoice, entry: ent_2, invoice_number: "123456")
      cil_2 = Factory(:commercial_invoice_line, commercial_invoice: ci_2, hmf: 1, prorated_mpf: 2, cotton_fee: 3)
      cit_2 = Factory(:commercial_invoice_tariff, commercial_invoice_line: cil_2, entered_value: 1, duty_amount: 2)
      con = Factory(:container, entry: ent_2, container_number: "cont num")

      @temp = described_class.run_report(u, {'start_date' => '2016-01-01', 'end_date' => '2016-02-01'})
      wb = Spreadsheet.open @temp.path

      stats = wb.worksheets[0]
      expect(stats.name).to eq "Statistics"
      expect(stats.row(0)).to eq [nil, "Order", nil, nil, nil, "Transport Units"]
      expect(stats.row(1)).to eq ["Export Country", "AIR", "OCEAN", "Total Orders", nil, "AIR", "OCEAN", "Total TU"]
      expect(stats.row(2)).to eq ["US", 1, 1, 2, nil, 1, 1, 2]
      expect(stats.row(3)).to eq ["Total Result", 1, 1, 2, nil, 1, 1, 2]
      expect(stats.row(5)).to eq ["Total Duty", 16]
      expect(stats.row(6)).to eq ["Total Entered Value", 2]

      ocean = wb.worksheets[1]
      expect(ocean.name).to eq "Ocean"
      expect(ocean.row(0)).to eq ["Export Country Codes", "Transport Mode Code", "Release Date", "Invoice No.", "Container No.", "Entry No."]
      expect(ocean.row(1)[0..5]).to eq [ "US", "10", assigned_day, "123456", "cont num", "ent num"] #for some reason datetime doesn't evaluate properly without '[0..5]'
      
      air = wb.worksheets[2]
      expect(air.name).to eq "Air"
      expect(air.row(0)).to eq ["Export Country Codes", "House Bills", "Master Bills", "Transport Mode Code", "Release Date", "Invoice No.", "Entry No."]
      expect(air.row(1)[0..6]).to eq ["US", "house", "master", "40", assigned_day, "123456", "ent num"] #for some reason datetime doesn't evaluate properly without '[0..6]'
    end
  end

  describe "run" do
    it "makes timezone conversions" do
      u = Factory(:user, time_zone: "Eastern Time (US & Canada)")
      wb = double("spreadsheet")
      adjusted_start = "2016-01-01 05:00:00"
      adjusted_end = "2016-02-01 05:00:00"
      expect(Spreadsheet::Workbook).to receive(:new).and_return wb
      expect(report).to receive(:add_summary_sheet).with(wb, adjusted_start, adjusted_end)
      expect(report).to receive(:add_ocean_sheet).with(wb, adjusted_start, adjusted_end)
      expect(report).to receive(:add_air_sheet).with(wb, adjusted_start, adjusted_end)
      expect(report).to receive(:workbook_to_tempfile)
      report.run(u, {'start_date' => '2016-01-01', 'end_date' => '2016-02-01'})
    end
  end

  describe "raw_air_query" do
    let!(:ent) {Factory(:entry, customer_number: "HENNE", export_country_codes: "DE", house_bills_of_lading: "house", master_bills_of_lading: "master", transport_mode_code: "40", release_date: assigned_day, entry_number: "entry num")}
    let!(:ci) {Factory(:commercial_invoice, entry: ent, invoice_number: "123456")}

    it "returns ecc, hbols, mbols, transport code, release date, inv num, entry num" do
      query = described_class.new.raw_air_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 1
      row = results.first
      expect(row[0]).to eq 'DE'
      expect(row[1]).to eq 'house'
      expect(row[2]).to eq 'master'
      expect(row[3]).to eq "40"
      expect(row[4]).to eq assigned_day
      expect(row[5]).to eq "123456"
      expect(row[6]).to eq "entry num"
    end

    it "only includes customer_number 'HENNE'" do
      check_system_code(:raw_air_query, ent, 0)
    end

    it "only includes invoice numbers of six or seven digits not including an optional hyphen" do
      check_invoice_number_format(report, :raw_air_query, ci, day_before, day_after)
    end

    it "only includes entries with release date in specified range" do
      ent.update_attributes(release_date: DateTime.new(2015,01,01))
      query = described_class.new.raw_air_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 0
    end

    it "only includes entries with transport_mode_code 40 or 41" do
      ent.update_attributes(transport_mode_code: "41")
      query = described_class.new.raw_air_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 1

      ent.update_attributes(transport_mode_code: "30")
      query = described_class.new.raw_air_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 0
    end
  end

  describe "raw_ocean_query" do
    let!(:ent) {Factory(:entry, customer_number: "HENNE", export_country_codes: "DE", transport_mode_code: "10", release_date: assigned_day, entry_number: "entry num")}
    let!(:ci) {Factory(:commercial_invoice, entry: ent, invoice_number: "123456")}
    let!(:con) {Factory(:container, entry: ent, container_number: "cont num")}

    it "returns ecc, transport mode code, release date, invoice number, container number, entry number" do
      query = described_class.new.raw_ocean_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 1
      row = results.first
      expect(row[0]).to eq 'DE'
      expect(row[1]).to eq '10'
      expect(row[2]).to eq assigned_day
      expect(row[3]).to eq "123456"
      expect(row[4]).to eq "cont num"
      expect(row[5]).to eq "entry num"
    end

    it "only includes customer_number 'HENNE'" do
      check_system_code(:raw_ocean_query, ent, 0)
    end

    it "only includes invoice numbers of six or seven digits not including an optional hyphen" do
      check_invoice_number_format(report, :raw_ocean_query, ci, day_before, day_after)
    end

    it "only includes entries with release date in specified range" do
      ent.update_attributes(release_date: DateTime.new(2015,01,01))
      query = described_class.new.raw_ocean_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 0
    end

    it "only includes entries with transport_mode_code 10 or 11" do
      ent.update_attributes(transport_mode_code: "11")
      query = described_class.new.raw_ocean_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 1

      ent.update_attributes(transport_mode_code: "30")
      query = described_class.new.raw_ocean_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 0
    end
  end

  describe "ocean_tu_query" do
    let!(:ent) {Factory(:entry, customer_number: "HENNE", export_country_codes: "DE", transport_mode_code: "10", release_date: assigned_day, entry_number: "entry num")}
    let!(:ci) {Factory(:commercial_invoice, entry: ent, invoice_number: "123456")}
    let!(:con_1) {Factory(:container, entry: ent, container_number: "cont num 1")}
    let!(:con_2) {Factory(:container, entry: ent, container_number: "cont num 2")}
    let!(:con_3) {Factory(:container, entry: ent, container_number: "cont num 2")}

    it "returns ecc, total distinct container numbers" do
      query = described_class.new.ocean_tu_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 1
      row = results.first
      expect(row[0]).to eq 'DE'
      expect(row[1]).to eq 2
    end

    it "only includes customer_number 'HENNE'" do
      check_system_code(:ocean_tu_query, ent, 0)
    end

    it "only includes invoice numbers of six or seven digits not including an optional hyphen" do
      check_invoice_number_format(report, :ocean_tu_query, ci, day_before, day_after)
    end

    it "only includes entries with release date in specified range" do
      ent.update_attributes(release_date: DateTime.new(2015,01,01))
      query = described_class.new.ocean_tu_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 0
    end

    it "only includes entries with transport_mode_code 10 or 11" do
      ent.update_attributes(transport_mode_code: "11")
      query = described_class.new.ocean_tu_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 1

      ent.update_attributes(transport_mode_code: "30")
      query = described_class.new.ocean_tu_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 0
    end
  end

  describe "orders_query" do
    let!(:ent_1) {Factory(:entry, customer_number: "HENNE", export_country_codes: "DE", transport_mode_code: "10", release_date: assigned_day)}
    let!(:ent_2) {Factory(:entry, customer_number: "HENNE", export_country_codes: "DE", transport_mode_code: "11", release_date: assigned_day)}
    let!(:ent_3) {Factory(:entry, customer_number: "HENNE", export_country_codes: "DE", transport_mode_code: "40", release_date: assigned_day)}
    let!(:ent_4) {Factory(:entry, customer_number: "HENNE", export_country_codes: "DE", transport_mode_code: "41", release_date: assigned_day)}
    let!(:ent_5) {Factory(:entry, customer_number: "HENNE", export_country_codes: "US", transport_mode_code: "10", release_date: assigned_day)}
    let!(:ci_1) {Factory(:commercial_invoice, entry: ent_1, invoice_number: "123456")}
    let!(:ci_2) {Factory(:commercial_invoice, entry: ent_2, invoice_number: "1234567")}
    let!(:ci_3) {Factory(:commercial_invoice, entry: ent_3, invoice_number: "1234568")}
    let!(:ci_4) {Factory(:commercial_invoice, entry: ent_4, invoice_number: "123456-7")}
    let!(:ci_5) {Factory(:commercial_invoice, entry: ent_5, invoice_number: "1234567-8")}

    it "returns ecc, mode, total invoices" do
      query = described_class.new.orders_query(day_before, day_after)
      results = []
      results = ActiveRecord::Base.connection.execute(query).each {|r| results << r}
      expect(results.count).to eq 3
      row_1 = results[0]
      expect(row_1[0]).to eq 'DE'
      expect(row_1[1]).to eq 'AIR'
      expect(row_1[2]).to eq 2

      row_2 = results[1]
      expect(row_2[0]).to eq 'DE'
      expect(row_2[1]).to eq 'OCEAN'
      expect(row_2[2]).to eq 2

      row_3 = results[2]
      expect(row_3[0]).to eq 'US'
      expect(row_3[1]).to eq 'OCEAN'
      expect(row_3[2]).to eq 1
    end

    it "only includes customer_number 'HENNE'" do
      check_system_code(:orders_query, ent_5, 2)
    end

    it "only includes invoice numbers of six or seven digits not including an optional hyphen" do
      ci_5.update_attributes(invoice_number: "12345")
      query = described_class.new.orders_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 2
    end

    it "only includes entries with release date in specified range" do
      ent_5.update_attributes(release_date: DateTime.new(2015,01,01))
      query = described_class.new.orders_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 2
    end
  end

  describe "totals_query" do
    let!(:ent) {Factory(:entry, release_date: assigned_day, customer_number: "HENNE")}
    let!(:ci) {Factory(:commercial_invoice, entry: ent, invoice_number: "123456")}
    let!(:cil) {Factory(:commercial_invoice_line, commercial_invoice: ci, hmf: 1, prorated_mpf: 2, cotton_fee: 3)}
    let!(:cit) {Factory(:commercial_invoice_tariff, commercial_invoice_line: cil, entered_value: 1, duty_amount: 2)}
    let!(:cil_2) {Factory(:commercial_invoice_line, commercial_invoice: ci, hmf: 4, prorated_mpf: 5, cotton_fee: 6)}
    let!(:cit_2) {Factory(:commercial_invoice_tariff, commercial_invoice_line: cil_2, entered_value: 3, duty_amount: 4)}

    it "sums tariff entered_value, fees" do
      query = described_class.new.totals_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.count).to eq 1
      expect(results.first[0]).to eq 4
      expect(results.first[1]).to eq 27
    end

    it "only includes customer_number 'HENNE'" do
      ent.update_attributes(customer_number: 'ACME')
      query = described_class.new.totals_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.first[0]).to be_nil
      expect(results.first[1]).to be_nil
    end

    it "only includes invoice numbers of six or seven digits not including an optional hyphen" do
      ci.update_attributes(invoice_number: '123456-7')
      query = report.totals_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.first[0]).not_to be_nil
      expect(results.first[1]).not_to be_nil

      ci.update_attributes(invoice_number: '1234567-8')
      query = report.totals_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.first[0]).not_to be_nil
      expect(results.first[1]).not_to be_nil

      ci.update_attributes(invoice_number: '12345')
      query = report.totals_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.first[0]).to be_nil
      expect(results.first[1]).to be_nil

      ci.update_attributes(invoice_number: '12345678')
      query = report.totals_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.first[0]).to be_nil
      expect(results.first[1]).to be_nil
    end

    it "only includes entries with release date in specified range" do
      ent.update_attributes(release_date: DateTime.new(2015,01,01))
      query = described_class.new.totals_query(day_before, day_after)
      results = ActiveRecord::Base.connection.execute query
      expect(results.first[0]).to be_nil
      expect(results.first[1]).to be_nil
    end
  end

  describe "load_air_tu_dh" do
    let!(:report) {described_class.new}
    let!(:mh) { Hash.new }

    it "loads master hash, doesn't count duplicate house bills" do
      results = [["US", "house 1\n house 2\n house 3\n house 1", "master 1\n master 2", "10", assigned_day.to_s, "inv num", "ent num"]]
      report.data_holder(mh, "US")
      mh["US"].total_unit = 1
      report.load_air_tu_dh results, mh
      
      expect(mh["US"].air_unit).to eq 3
      expect(mh["US"].total_unit).to eq 4
    end

    it "counts master bills if there are no house bills, omits duplicates" do
      results = [["US", "", "master 1\n master 2\n master 1", "10", assigned_day.to_s, "inv num", "ent num"]]
      report.data_holder(mh, "US")
      mh["US"].total_unit = 1
      report.load_air_tu_dh results, mh
      
      expect(mh["US"].air_unit).to eq 2
      expect(mh["US"].total_unit).to eq 3
    end
  end

  describe "load_ocean_tu_dh" do
    it "loads master hash" do
      mh = Hash.new
      results = [["US", 1]]

      report.data_holder(mh, "US")
      mh["US"].total_unit = 1
      report.load_ocean_tu_dh results, mh

      expect(mh["US"].ocean_unit).to eq 1
      expect(mh["US"].total_unit).to eq 2
    end
  end

  describe "load_order_dh" do
    it "loads master hash" do
      mh = Hash.new
      results = [["US", "OCEAN", 1], ["US", "AIR", 2]]
      report.load_order_dh results, mh

      expect(mh["US"].ocean_order).to eq 1
      expect(mh["US"].air_order).to eq 2
      expect(mh["US"].total_order).to eq 3
    end
  end

end

def check_system_code query, entry, expected_count
  entry.update_attributes(customer_number: 'ACME')
  report = described_class.new
  qry = report.send(query, day_before, day_after)
  results = ActiveRecord::Base.connection.execute qry
  expect(results.count).to eq expected_count
end

def check_invoice_number_format report, query, invoice, day_before, day_after
  invoice.update_attributes(invoice_number: '123456-7')
  qry = report.send(query, day_before, day_after)
  results = ActiveRecord::Base.connection.execute qry
  expect(results.count).to eq 1

  invoice.update_attributes(invoice_number: '1234567-8')
  qry = report.send(query, day_before, day_after)
  results = ActiveRecord::Base.connection.execute qry
  expect(results.count).to eq 1

  invoice.update_attributes(invoice_number: '12345')
  qry = report.send(query, day_before, day_after)
  results = ActiveRecord::Base.connection.execute qry
  expect(results.count).to eq 0

  invoice.update_attributes(invoice_number: '12345678')
  qry = report.send(query, day_before, day_after)
  results = ActiveRecord::Base.connection.execute qry
  expect(results.count).to eq 0
end