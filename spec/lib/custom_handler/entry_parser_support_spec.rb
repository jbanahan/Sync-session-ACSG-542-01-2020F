describe OpenChain::CustomHandler::EntryParserSupport do

  subject { 
    Class.new do
      extend OpenChain::CustomHandler::EntryParserSupport
    end
  }

  describe 'process_special_tariffs' do
    let!(:entry) do
      entry = Factory(:entry, import_date:Date.new(2017,10,19))
      ci = entry.commercial_invoices.create!
      cil = ci.commercial_invoice_lines.create!
      cil.commercial_invoice_tariffs.create!(hts_code:1234567890)
      entry
    end

    it "assigns header and tariff-level flags" do
      SpecialTariffCrossReference.create! import_country_iso: "US", special_hts_number: "1234567890", effective_date_start: Date.new(2017,10,15), effective_date_end: Date.new(2017,10,20)
      subject.process_special_tariffs entry
      entry.save!
      expect(entry.special_tariff).to eq true
      expect(entry.commercial_invoice_tariffs.first.special_tariff).to eq true
    end

    context "without matching cross reference" do
      it "doesn't assign header-level flag if range too late" do
        SpecialTariffCrossReference.create! import_country_iso: "US", special_hts_number: "1234567890", effective_date_start: Date.new(2017,10,20), effective_date_end: Date.new(2017,10,20)
        subject.process_special_tariffs entry
        entry.save!
        expect(entry.special_tariff).to be_nil
        expect(entry.commercial_invoice_tariffs.first.special_tariff).to be_nil
      end

      it "doesn't assign header-level flag if range is too early" do
        SpecialTariffCrossReference.create! import_country_iso: "US", special_hts_number: "1234567890", effective_date_start: Date.new(2017,10,18), effective_date_end: Date.new(2017,10,18)
        subject.process_special_tariffs entry
        entry.save!
        expect(entry.special_tariff).to be_nil
        expect(entry.commercial_invoice_tariffs.first.special_tariff).to be_nil
      end

      it "doesn't assign header-level flag if hts doesn't match" do
        SpecialTariffCrossReference.create! import_country_iso: "US", special_hts_number: "0123456789", effective_date_start: Date.new(2017,10,15), effective_date_end: Date.new(2017,10,20)
        subject.process_special_tariffs entry
        entry.save!
        expect(entry.special_tariff).to be_nil
        expect(entry.commercial_invoice_tariffs.first.special_tariff).to be_nil
      end

      it "doesn't assign header-level flag if import country isn't 'US'" do
        SpecialTariffCrossReference.create! import_country_iso: "CA", special_hts_number: "1234567890", effective_date_start: Date.new(2017,10,15), effective_date_end: Date.new(2017,10,20)
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
      expect(subject).to receive(:calculate_classification_related_rates).with(tar, inv_line, Date.new(2019,6,1))

      expect(subject.calculate_duty_rates tar, inv_line, Date.new(2019,6,1), BigDecimal.new("100")).to be_nil
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
      expect(TariffClassification).to receive(:find_effective_tariff).with(us_country, Date.new(2019,6,1), "555333").and_return(tar_class)
      expect(tar_class).to receive(:extract_tariff_rate_data).with("CN", "X").and_return({ advalorem_rate:BigDecimal.new("11.11"), specific_rate:BigDecimal.new("22.22"), specific_rate_uom:"EA", additional_rate:BigDecimal.new("33.33"), additional_rate_uom:"EB" })

      expect(subject.calculate_classification_related_rates tar, inv_line, Date.new(2019,6,1)).to be_nil

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

      expect(subject.calculate_classification_related_rates tar, inv_line, Date.new(2019,6,1)).to be_nil

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

      expect(subject.calculate_classification_related_rates tar, inv_line, Date.new(2019,6,1)).to be_nil

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
      entry = Entry.new(first_it_date:Date.new(2019,6,1), import_date:Date.new(2019,6,2))
      expect(subject.tariff_effective_date entry).to eq Date.new(2019,6,1)

      entry.first_it_date = nil
      expect(subject.tariff_effective_date entry).to eq Date.new(2019,6,2)

      entry.import_date = nil
      expect(subject.tariff_effective_date entry).to be_nil
    end
  end

  describe "multi_value_separator" do
    it "gets default separator" do
      expect(subject.multi_value_separator).to eq "\n "
    end
  end
end
