describe ValidationRuleEntrySpecialTariffsClaimed do

  describe "run_validation" do
    let (:entry) {
      e = Factory(:entry, origin_country_codes: "CN\nVN", release_date: "2018-10-10 12:00", import_country: Factory(:country, iso_code: "US"))
      invoice = e.commercial_invoices.create! invoice_number: "INV1"
      line = invoice.commercial_invoice_lines.create! country_origin_code: "CN", line_number: 1
      tariff = line.commercial_invoice_tariffs.create! hts_code: "1234567980"
      tariff_2 = line.commercial_invoice_tariffs.create! hts_code: "9999999999"
      e
    }

    let! (:special_tariff) { 
      SpecialTariffCrossReference.create! hts_number: "1234567980", special_hts_number: "9999999999", special_tariff_type: "MTB", import_country_iso: "US", country_origin_iso: "CN", effective_date_start: '2018-10-10'
    }

    it "reports if special tariff is not used" do
      expect(subject.run_validation entry).to eq ["Please review the following lines to ensure the special tariffs were applied correctly:", "Invoice # INV1 / Line # 1 / HTS # 9999.99.9999 is a MTB HTS #."].join("\n")
    end

    it "does not report error if special tariff is not utilized" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.last.destroy
      expect(subject.run_validation entry).to be_nil
    end

    it "does not error if release date is prior to the special tariff's effective_date_start" do
      # The dates are the same, but since this is UTC, in Eastern timezone it's still 10/09...so this should not use the special tariff
      entry.update_attributes! release_date: ActiveSupport::TimeZone["UTC"].parse("2018-10-10 01:00")

      expect(subject.run_validation entry).to be_nil
    end

    it "does not error if the special tariff is not part of the specified program" do
      subject.rule_attributes_json = {special_tariff_types: ["BLAH"]}.to_json
      expect(subject.run_validation entry).to be_nil
    end

    it "does not error if the tariff number is set up to be skipped" do
      subject.rule_attributes_json = {skip_hts_numbers: ["12345"]}.to_json

      expect(subject.run_validation entry).to be_nil
    end

    it "does not error if the tariff number is not part of the inclusion setup" do
      subject.rule_attributes_json = {only_hts_numbers: ["99999"]}.to_json

      expect(subject.run_validation entry).to be_nil
    end

    it "does error if the tariff number IS part of the inclusion" do
      subject.rule_attributes_json = {only_hts_numbers: ["12345"]}.to_json
      expect(subject.run_validation entry).not_to be_blank
    end

  end
end