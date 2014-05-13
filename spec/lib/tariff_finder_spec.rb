require 'spec_helper'

describe OpenChain::TariffFinder do
  def build_entry hts, part, coo, imp_id, country_id, release_date, mid_code
    cit = Factory(:commercial_invoice_tariff,
      hts_code:hts,
      commercial_invoice_line:Factory(:commercial_invoice_line,
        part_number:part,
        country_origin_code:coo,
        commercial_invoice:Factory(:commercial_invoice,
          mfid: mid_code,
          entry:Factory(:entry,
            importer_id:imp_id,
            import_country_id:country_id,
            release_date: release_date
          )
        )
      )
    )
    cit.commercial_invoice_line.entry
  end
  describe :find_by_style do
    before :each do
      @imp = Factory(:company)
      @c1 = Factory(:country)
    end
    it "should find by style with nil country of origin" do
      e1 = build_entry '123456789', 'p1', 'ZZ', @imp.id, @c1.id, 1.day.ago, 'q'
      too_old = build_entry '123456666', 'p1', 'ZA', @imp.id, @c1.id, 2.days.ago, 'R'
      wrong_importer = build_entry '123456777', 'p1', 'ZQ', @imp.id+1, @c1.id, 1.hour.ago, 'S'
      e1 = build_entry '123456790', 'p2', 'ZZ', @imp.id, @c1.id, 1.hour.ago, 'q'
      r = described_class.new(@c1,[@imp]).find_by_style 'p1'
      expect(r.part_number).to eq 'p1'
      expect(r.country_origin_code).to eq 'ZZ'
      expect(r.mid).to eq 'q'
      expect(r.hts_code).to eq '123456789'
    end

    it "should find by style with country of origin filter" do
      e1 = build_entry '123456789', 'p1', 'ZZ', @imp.id, @c1.id, 1.day.ago, 'q'
      wrong_coo = build_entry '123456789', 'p1', 'ZA', @imp.id, @c1.id, 1.hour.ago, 'q'
      r = described_class.new(@c1,[@imp]).find_by_style 'p1', 'ZZ'
      expect(r.part_number).to eq 'p1'
      expect(r.country_origin_code).to eq 'ZZ'
      expect(r.mid).to eq 'q'
      expect(r.hts_code).to eq '123456789'
    end
  end
end
