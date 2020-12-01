describe OpenChain::TariffFinder do

  def build_entry hts, part, coo, imp_id, country_id, release_date, mid_code
    cit = FactoryBot(:commercial_invoice_tariff,
                  hts_code: hts,
                  commercial_invoice_line: FactoryBot(:commercial_invoice_line,
                                                   part_number: part,
                                                   country_origin_code: coo,
                                                   commercial_invoice: FactoryBot(:commercial_invoice,
                                                                               mfid: mid_code,
                                                                               entry: FactoryBot(:entry,
                                                                                              importer_id: imp_id,
                                                                                              import_country_id: country_id,
                                                                                              release_date: release_date))))
    cit.commercial_invoice_line.entry
  end

  describe "find_by_style" do
    let(:importer) { FactoryBot(:company) }
    let(:country) { FactoryBot(:country) }

    it "finds by style with nil country of origin" do
      build_entry '123456789', 'p1', 'ZZ', importer.id, country.id, 1.day.ago, 'q'
      build_entry '123456666', 'p1', 'ZA', importer.id, country.id, 2.days.ago, 'R'
      build_entry '123456777', 'p1', 'ZQ', importer.id + 1, country.id, 1.hour.ago, 'S'
      build_entry '123456790', 'p2', 'ZZ', importer.id, country.id, 1.hour.ago, 'q'
      r = described_class.new(country.iso_code, [importer]).by_style 'p1'
      expect(r.part_number).to eq 'p1'
      expect(r.country_origin_code).to eq 'ZZ'
      expect(r.mid).to eq 'q'
      expect(r.hts_code).to eq '123456789'
    end

    it "finds by style with country of origin filter" do
      build_entry '123456789', 'p1', 'ZZ', importer.id, country.id, 1.day.ago, 'q'
      build_entry '123456789', 'p1', 'ZA', importer.id, country.id, 1.hour.ago, 'q'
      r = described_class.new(country.iso_code, [importer]).by_style 'p1', 'ZZ'
      expect(r.part_number).to eq 'p1'
      expect(r.country_origin_code).to eq 'ZZ'
      expect(r.mid).to eq 'q'
      expect(r.hts_code).to eq '123456789'
    end

    it "skips entries with different origin country" do
      build_entry '123456789', 'p1', 'ZZ', importer.id, country.id, 1.day.ago, 'q'
      expect(described_class.new("NOTANISO", [importer]).by_style('p1', 'ZZ')).to be_nil
    end

    it "skips entries with wrong importer" do
      build_entry '123456789', 'p1', 'ZZ', importer.id, country.id, 1.day.ago, 'q'
      expect(described_class.new(country.iso_code, [FactoryBot(:company)]).by_style('p1', 'ZZ')).to be_nil
    end
  end
end
