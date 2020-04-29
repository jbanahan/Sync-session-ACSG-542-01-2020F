describe OpenChain::CustomHandler::EntryParserSupport do

  subject {
    Class.new do
      extend OpenChain::CustomHandler::EntryParserSupport
    end
  }

  describe 'process_special_tariffs' do
    let!(:entry) do
      entry = Factory(:entry, import_date:Date.new(2017, 10, 19))
      ci = entry.commercial_invoices.create!
      cil = ci.commercial_invoice_lines.create!
      cil.commercial_invoice_tariffs.create!(hts_code:1234567890)
      entry
    end

    it "assigns header and tariff-level flags" do
      SpecialTariffCrossReference.create! import_country_iso: "US", special_hts_number: "1234567890", effective_date_start: Date.new(2017, 10, 15), effective_date_end: Date.new(2017, 10, 20)
      subject.process_special_tariffs entry
      entry.save!
      expect(entry.special_tariff).to eq true
      expect(entry.commercial_invoice_tariffs.first.special_tariff).to eq true
    end

    context "without matching cross reference" do
      it "doesn't assign header-level flag if range too late" do
        SpecialTariffCrossReference.create! import_country_iso: "US", special_hts_number: "1234567890", effective_date_start: Date.new(2017, 10, 20), effective_date_end: Date.new(2017, 10, 20)
        subject.process_special_tariffs entry
        entry.save!
        expect(entry.special_tariff).to be_nil
        expect(entry.commercial_invoice_tariffs.first.special_tariff).to be_nil
      end

      it "doesn't assign header-level flag if range is too early" do
        SpecialTariffCrossReference.create! import_country_iso: "US", special_hts_number: "1234567890", effective_date_start: Date.new(2017, 10, 18), effective_date_end: Date.new(2017, 10, 18)
        subject.process_special_tariffs entry
        entry.save!
        expect(entry.special_tariff).to be_nil
        expect(entry.commercial_invoice_tariffs.first.special_tariff).to be_nil
      end

      it "doesn't assign header-level flag if hts doesn't match" do
        SpecialTariffCrossReference.create! import_country_iso: "US", special_hts_number: "0123456789", effective_date_start: Date.new(2017, 10, 15), effective_date_end: Date.new(2017, 10, 20)
        subject.process_special_tariffs entry
        entry.save!
        expect(entry.special_tariff).to be_nil
        expect(entry.commercial_invoice_tariffs.first.special_tariff).to be_nil
      end

      it "doesn't assign header-level flag if import country isn't 'US'" do
        SpecialTariffCrossReference.create! import_country_iso: "CA", special_hts_number: "1234567890", effective_date_start: Date.new(2017, 10, 15), effective_date_end: Date.new(2017, 10, 20)
        subject.process_special_tariffs entry
        entry.save!
        expect(entry.special_tariff).to be_nil
        expect(entry.commercial_invoice_tariffs.first.special_tariff).to be_nil
      end
    end
  end

  describe "calculate_duty_rates" do
    it "calculates duty rates for tariff" do
      inv_line = CommercialInvoiceLine.new
      tar = inv_line.commercial_invoice_tariffs.build

      expect(subject).to receive(:calculate_primary_duty_rate).with(tar, BigDecimal.new("100"))
      expect(subject).to receive(:calculate_classification_related_rates).with(tar, inv_line, Date.new(2019, 6, 1))

      expect(subject.calculate_duty_rates tar, inv_line, Date.new(2019, 6, 1), BigDecimal.new("100")).to be_nil
    end
  end

  describe "calculate_primary_duty_rate" do
    it "calculates duty rate for tariff" do
      tar = CommercialInvoiceTariff.new(duty_amount:BigDecimal.new("37.79"))

      expect(subject.calculate_primary_duty_rate tar, BigDecimal.new("100")).to be_nil

      expect(tar.duty_rate).to eq BigDecimal.new("0.378")
    end

    it "handles no customs value (i.e. no divide by zero)" do
      tar = CommercialInvoiceTariff.new(duty_amount:BigDecimal.new("37.79"))

      expect(subject.calculate_primary_duty_rate tar, BigDecimal.new(0)).to be_nil

      expect(tar.duty_rate).to eq BigDecimal.new(0)
    end

    it "handles nil duty amount" do
      tar = CommercialInvoiceTariff.new(duty_amount:nil)

      expect(subject.calculate_primary_duty_rate tar, BigDecimal.new("100")).to be_nil

      expect(tar.duty_rate).to eq BigDecimal.new(0)
    end
  end

  describe "calculate_classification_related_rates" do
    let!(:us_country) { Factory(:country, iso_code:"US") }

    it "calculates duty rates for tariff" do
      inv_line = CommercialInvoiceLine.new(country_origin_code:"CN")
      tar = inv_line.commercial_invoice_tariffs.build(hts_code:"555333", duty_amount:BigDecimal.new("37.79"), spi_primary:"X")

      tar_class = double("TariffClassification_1")
      expect(TariffClassification).to receive(:find_effective_tariff).with(us_country, Date.new(2019, 6, 1), "555333").and_return(tar_class)
      expect(tar_class).to receive(:extract_tariff_rate_data).with("CN", "X").and_return({ advalorem_rate:BigDecimal.new("11.11"), specific_rate:BigDecimal.new("22.22"), specific_rate_uom:"EA", additional_rate:BigDecimal.new("33.33"), additional_rate_uom:"EB" })

      expect(subject.calculate_classification_related_rates tar, inv_line, Date.new(2019, 6, 1)).to be_nil

      expect(tar.advalorem_rate).to eq BigDecimal.new("11.11")
      expect(tar.specific_rate).to eq BigDecimal.new("22.22")
      expect(tar.specific_rate_uom).to eq "EA"
      expect(tar.additional_rate).to eq BigDecimal.new("33.33")
      expect(tar.additional_rate_uom).to eq "EB"
    end

    it "handles missing classification" do
      inv_line = CommercialInvoiceLine.new(country_origin_code:"CN")
      tar = inv_line.commercial_invoice_tariffs.build(hts_code:"555333", duty_amount:BigDecimal.new("5.55"), spi_primary:"X")

      # There is no classification record that matches this HTS code.

      expect(subject.calculate_classification_related_rates tar, inv_line, Date.new(2019, 6, 1)).to be_nil

      expect(tar.advalorem_rate).to be_nil
      expect(tar.specific_rate).to be_nil
      expect(tar.specific_rate_uom).to be_nil
      expect(tar.additional_rate).to be_nil
      expect(tar.additional_rate_uom).to be_nil
    end

    it "handles missing HTS code" do
      inv_line = CommercialInvoiceLine.new(country_origin_code:"CN")
      # This one will not be classified because it has no HTS code.  Probably not possible in reality, but the code handles it.
      tar = inv_line.commercial_invoice_tariffs.build(hts_code:"  ", duty_amount:BigDecimal.new("5.55"), spi_primary:"Z")

      expect(subject.calculate_classification_related_rates tar, inv_line, Date.new(2019, 6, 1)).to be_nil

      expect(tar.advalorem_rate).to be_nil
      expect(tar.specific_rate).to be_nil
      expect(tar.specific_rate_uom).to be_nil
      expect(tar.additional_rate).to be_nil
      expect(tar.additional_rate_uom).to be_nil
    end

    it "handles nil effective date" do
      inv_line = CommercialInvoiceLine.new(country_origin_code:"CN")
      # This one will not be classified because no effective date is provided.
      tar = inv_line.commercial_invoice_tariffs.build(hts_code:"555333", duty_amount:BigDecimal.new("37.79"), spi_primary:"X")

      expect(subject.calculate_classification_related_rates tar, inv_line, nil).to be_nil

      expect(tar.advalorem_rate).to be_nil
      expect(tar.specific_rate).to be_nil
      expect(tar.specific_rate_uom).to be_nil
      expect(tar.additional_rate).to be_nil
      expect(tar.additional_rate_uom).to be_nil
    end
  end

  describe "tariff_effective_date" do
    it "determines best effective date from entry data" do
      entry = Entry.new(first_it_date:Date.new(2019, 6, 1), import_date:Date.new(2019, 6, 2))
      expect(subject.tariff_effective_date entry).to eq Date.new(2019, 6, 1)

      entry.first_it_date = nil
      expect(subject.tariff_effective_date entry).to eq Date.new(2019, 6, 2)

      entry.import_date = nil
      expect(subject.tariff_effective_date entry).to be_nil
    end
  end

  describe "multi_value_separator" do
    it "gets default separator" do
      expect(subject.multi_value_separator).to eq "\n "
    end
  end

  describe "HoldReleaseSetter" do
    describe "set_any_hold_date" do
      it "sets a hold date and clears corresponding release date" do
        entry = Factory(:entry, fda_hold_date:Date.new(2019, 12, 7), fda_hold_release_date:Date.new(2019, 12, 8))
        setter = described_class::HoldReleaseSetter.new entry
        setter.updated_before_one_usg[:fda_hold_release_date] = Date.new(2019, 12, 12)
        setter.updated_before_one_usg[:cbp_hold_release_date] = Date.new(2019, 12, 12)
        setter.updated_after_one_usg[:fda_hold_release_date] = Date.new(2019, 12, 12)
        setter.updated_after_one_usg[:cbp_hold_release_date] = Date.new(2019, 12, 12)
        setter.set_any_hold_date Date.new(2019, 12, 9), :fda_hold_date
        expect(entry.fda_hold_date).to eq Date.new(2019, 12, 9)
        expect(entry.fda_hold_release_date).to be_nil
        expect(setter.updated_before_one_usg.length).to eq 1
        expect(setter.updated_after_one_usg.length).to eq 1
      end

      it "clears a hold date and doesn't mess with release dates" do
        entry = Factory(:entry, fda_hold_date:Date.new(2019, 12, 7), fda_hold_release_date:Date.new(2019, 12, 8))
        setter = described_class::HoldReleaseSetter.new entry
        setter.updated_before_one_usg[:fda_hold_release_date] = Date.new(2019, 12, 12)
        setter.updated_before_one_usg[:cbp_hold_release_date] = Date.new(2019, 12, 12)
        setter.updated_after_one_usg[:fda_hold_release_date] = Date.new(2019, 12, 12)
        setter.updated_after_one_usg[:cbp_hold_release_date] = Date.new(2019, 12, 12)
        setter.set_any_hold_date nil, :fda_hold_date
        expect(entry.fda_hold_date).to be_nil
        # These are not cleared.
        expect(entry.fda_hold_release_date).to eq(Date.new(2019, 12, 8))
        expect(setter.updated_before_one_usg.length).to eq 2
        expect(setter.updated_after_one_usg.length).to eq 2
      end

      it "sets a hold date and updates corresponding release date to one USG date if one USG date is later" do
        entry = Factory(:entry, one_usg_date:Date.new(2019, 12, 10))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_any_hold_date Date.new(2019, 12, 9), :fda_hold_date
        expect(entry.fda_hold_date).to eq Date.new(2019, 12, 9)
        expect(entry.fda_hold_release_date).to eq Date.new(2019, 12, 10)
      end

      it "sets a hold date and leaves corresponding release date blank if one USG date is earlier" do
        entry = Factory(:entry, one_usg_date:Date.new(2019, 12, 8))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_any_hold_date Date.new(2019, 12, 9), :fda_hold_date
        expect(entry.fda_hold_date).to eq Date.new(2019, 12, 9)
        expect(entry.fda_hold_release_date).to be_nil
      end
    end

    describe "set_any_hold_release_date" do
      it "sets one USG date and release dates for all active holds when date has a value" do
        entry = Factory(:entry, fda_hold_date:Date.new(2019, 12, 8), usda_hold_date:Date.new(2019, 12, 7))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_any_hold_release_date Date.new(2019, 12, 9), :one_usg_date
        expect(entry.one_usg_date).to eq Date.new(2019, 12, 9)
        expect(entry.fda_hold_release_date).to eq Date.new(2019, 12, 9)
        expect(entry.usda_hold_release_date).to eq Date.new(2019, 12, 9)
      end

      it "clears one USG date and doesn't mess with other release dates when date does not have a value" do
        entry = Factory(:entry, fda_hold_date:Date.new(2019, 12, 8), usda_hold_date:Date.new(2019, 12, 7), usda_hold_release_date:Date.new(2019, 12, 9))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_any_hold_release_date nil, :one_usg_date
        expect(entry.one_usg_date).to be_nil
        expect(entry.fda_hold_release_date).to be_nil
        expect(entry.usda_hold_release_date).to eq Date.new(2019, 12, 9)
      end

      it "sets release date when there is a matching hold, after one USG date" do
        entry = Factory(:entry, fda_hold_date:Date.new(2019, 12, 7), one_usg_date:Date.new(2019, 12, 8))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_any_hold_release_date Date.new(2019, 12, 9), :fda_hold_release_date
        expect(entry.fda_hold_release_date).to eq Date.new(2019, 12, 9)
        expect(setter.updated_before_one_usg.length).to eq 0
        expect(setter.updated_after_one_usg.length).to eq 1
        expect(setter.updated_after_one_usg[:fda_hold_release_date]).to eq Date.new(2019, 12, 9)
      end

      it "sets release date when there is a matching hold, before one USG date" do
        entry = Factory(:entry, fda_hold_date:Date.new(2019, 12, 7), one_usg_date:Date.new(2019, 12, 12))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_any_hold_release_date Date.new(2019, 12, 9), :fda_hold_release_date
        expect(entry.fda_hold_release_date).to eq Date.new(2019, 12, 9)
        expect(setter.updated_before_one_usg.length).to eq 1
        expect(setter.updated_before_one_usg[:fda_hold_release_date]).to eq Date.new(2019, 12, 9)
        expect(setter.updated_after_one_usg.length).to eq 0
      end

      it "does not set release date when there is no matching hold" do
        entry = Factory(:entry, one_usg_date:Date.new(2019, 12, 8))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_any_hold_release_date Date.new(2019, 12, 9), :fda_hold_release_date
        expect(entry.fda_hold_release_date).to be_nil
        expect(setter.updated_before_one_usg.length).to eq 0
        expect(setter.updated_after_one_usg.length).to eq 0
      end

      it "clears release date with a nil value" do
        entry = Factory(:entry, fda_hold_date:Date.new(2019, 12, 7), fda_hold_release_date:Date.new(2019, 12, 8), one_usg_date:Date.new(2019, 12, 8))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_any_hold_release_date nil, :fda_hold_release_date
        expect(entry.fda_hold_release_date).to be_nil
        expect(setter.updated_before_one_usg.length).to eq 0
        expect(setter.updated_after_one_usg.length).to eq 0
      end
    end

    describe "set_on_hold" do
      it "sets on hold flag to true if holds are present" do
        entry = Factory(:entry, fda_hold_date:Date.new(2019, 12, 9))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_on_hold
        expect(entry.on_hold?).to eq true
      end

      it "sets on hold flag to false if no holds are present" do
        entry = Factory(:entry)
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_on_hold
        expect(entry.on_hold?).to eq false
      end
    end

    describe "set_summary_hold_date" do
      it "sets the summary hold date to the earliest active hold date" do
        # USDA hold is still chosen even though there's a release date.  This method doesn't care about that.
        entry = Factory(:entry, fda_hold_date:Date.new(2019, 12, 9), ams_hold_date:Date.new(2019, 12, 10),
                        usda_hold_date:Date.new(2019, 12, 8), usda_hold_release_date:Date.new(2019, 12, 9))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_summary_hold_date
        expect(entry.hold_date).to eq Date.new(2019, 12, 8)
      end

      it "clears the summary hold date when there are no holds" do
        entry = Factory(:entry, usda_hold_release_date:Date.new(2019, 12, 9))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_summary_hold_date
        expect(entry.hold_date).to be_nil
      end
    end

    describe "set_summary_hold_release_date" do
      it "clears the summary hold release date when the entry is on hold" do
        entry = Factory(:entry, usda_hold_date:Date.new(2019, 12, 9), hold_release_date:Date.new(2019, 12, 10))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_summary_hold_release_date
        expect(entry.hold_release_date).to be_nil
      end

      it "sets the summary hold release date to one USG date when the entry has a one USG release date and there are no later release dates" do
        entry = Factory(:entry, usda_hold_date:Date.new(2019, 12, 9), usda_hold_release_date:Date.new(2019, 12, 10), one_usg_date:Date.new(2019, 12, 11))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_summary_hold_release_date
        expect(entry.hold_release_date).to eq Date.new(2019, 12, 11)
      end

      it "sets the summary hold release date to one USG date when the entry has a one USG release date and there is a later release date" do
        entry = Factory(:entry, usda_hold_date:Date.new(2019, 12, 9), usda_hold_release_date:Date.new(2019, 12, 12), one_usg_date:Date.new(2019, 12, 11))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_summary_hold_release_date
        # This result seems a little iffy.  It is pulling the one USG date because the hashes this method uses are not loaded by the method.
        expect(entry.hold_release_date).to eq Date.new(2019, 12, 11)
      end

      it "overrides one USG release date when there is a later release date in the 'updated after' hash" do
        entry = Factory(:entry, fda_hold_date:Date.new(2019, 12, 9), fda_hold_release_date:Date.new(2019, 12, 12), one_usg_date:Date.new(2019, 12, 11))
        setter = described_class::HoldReleaseSetter.new entry
        setter.updated_after_one_usg[:usda_hold_release_date] = Date.new(2019, 12, 13)
        setter.updated_after_one_usg[:cbp_hold_release_date] = Date.new(2019, 12, 12)
        setter.set_summary_hold_release_date
        expect(entry.hold_release_date).to eq Date.new(2019, 12, 13)
      end

      it "clears the summary hold release date when the 'updated before' hash is empty and there is no one USG date" do
        entry = Factory(:entry, usda_hold_date:Date.new(2019, 12, 9), usda_hold_release_date:Date.new(2019, 12, 10), hold_release_date:Date.new(2019, 12, 10), one_usg_date:nil)
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_summary_hold_release_date
        # This result seems a little iffy.  It is clearing the field rather than using the USDA hold release date because the hashes this method uses are not loaded by the method.
        expect(entry.hold_release_date).to be_nil
      end

      it "sets the summary hold release date to the latest date in the 'updated before' hash when there is no one USG date" do
        entry = Factory(:entry, usda_hold_date:Date.new(2019, 12, 9), usda_hold_release_date:Date.new(2019, 12, 10), hold_release_date:Date.new(2019, 12, 10), one_usg_date:nil)
        setter = described_class::HoldReleaseSetter.new entry
        setter.updated_before_one_usg[:fda_hold_release_date] = Date.new(2019, 12, 13)
        setter.updated_before_one_usg[:cbp_hold_release_date] = Date.new(2019, 12, 12)
        setter.set_summary_hold_release_date
        expect(entry.hold_release_date).to eq Date.new(2019, 12, 13)
      end

      it "clears the summary hold release date when there are no hold/release pairings" do
        entry = Factory(:entry, hold_release_date:Date.new(2019, 12, 10), one_usg_date:Date.new(2019, 12, 11))
        setter = described_class::HoldReleaseSetter.new entry
        setter.set_summary_hold_release_date
        expect(entry.hold_release_date).to be_nil
      end
    end
  end

end
