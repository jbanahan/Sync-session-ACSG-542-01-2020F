describe ValidationRuleEntrySpecialTariffsNotClaimed do

  describe "run_validation" do
    let (:entry) {
      e = Factory(:entry, origin_country_codes: "CN\nVN", release_date: "2018-10-10 12:00", import_country: Factory(:country, iso_code: "US"))
      invoice = e.commercial_invoices.create! invoice_number: "INV1"
      line = invoice.commercial_invoice_lines.create! country_origin_code: "CN", line_number: 1
      tariff = line.commercial_invoice_tariffs.create! hts_code: "1234567980"
      e
    }

    let! (:special_tariff) { 
      SpecialTariffCrossReference.create! hts_number: "1234567980", special_hts_number: "9999999999", special_tariff_type: "MTB", import_country_iso: "US", country_origin_iso: "CN", effective_date_start: '2018-10-10'
    }

    it "reports if special tariff is not used" do
      expect(subject.run_validation entry).to eq "Invoice # INV1 / Line # 1 / HTS # 1234.56.7980 may be able to claim MTB HTS # 9999.99.9999."
    end

    it "does not report error if special tariff is utilized" do
      entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.create! hts_code: "9999999999"
      expect(subject.run_validation entry).to be_nil
    end

    it "handles multiple special tariff lookups" do
      SpecialTariffCrossReference.create! hts_number: "1234567980", special_hts_number: "8888888888", special_tariff_type: "301", import_country_iso: "US", country_origin_iso: "CN", effective_date_start: '2018-10-10'
      expect(subject.run_validation entry).to eq "Invoice # INV1 / Line # 1 / HTS # 1234.56.7980 may be able to claim MTB HTS # 9999.99.9999.\nInvoice # INV1 / Line # 1 / HTS # 1234.56.7980 may be able to claim 301 HTS # 8888.88.8888."
    end

    it "does not error if all special tariffs are claimed" do
      SpecialTariffCrossReference.create! hts_number: "1234567980", special_hts_number: "8888888888", special_tariff_type: "301", import_country_iso: "US", country_origin_iso: "CN", effective_date_start: '2018-10-10'
      entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.create! hts_code: "9999999999"
      entry.commercial_invoices.first.commercial_invoice_lines.first.commercial_invoice_tariffs.create! hts_code: "8888888888"
      expect(subject.run_validation entry).to be_nil
    end

    it "does not error if release date is prior to the special tariff's effective_date_start" do
      # The dates are the same, but since this is UTC, in Eastern timezone it's still 10/09...so this should not use the special tariff
      entry.update_attributes! release_date: ActiveSupport::TimeZone["UTC"].parse("2018-10-10 01:00")

      expect(subject.run_validation entry).to be_nil
    end
  end
end