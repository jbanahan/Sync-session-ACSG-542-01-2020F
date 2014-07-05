require 'spec_helper'

describe DrawbackExportHistory do
  describe :bulk_insert do
    it "should insert multiple records" do
      d1 = DrawbackExportHistory.new(part_number:'123',
        export_ref_1:'ER1',
        export_date:Date.new(2014,7,5),
        quantity:10,
        claim_amount_per_unit:1.25,
        claim_amount: 12.50,
        drawback_claim_id: 1
      )
      d2 = DrawbackExportHistory.new(part_number:'1234',
        export_ref_1:'ER2',
        export_date:Date.new(2014,7,6),
        quantity:100,
        claim_amount_per_unit:1.24,
        claim_amount: 124.00,
        drawback_claim_id: 2
      )
      DrawbackExportHistory.bulk_insert [d1,d2]
      f1 = DrawbackExportHistory.first
      expect(f1.part_number).to eq d1.part_number
      expect(f1.export_ref_1).to eq d1.export_ref_1
      expect(f1.export_date).to eq d1.export_date
      expect(f1.quantity).to eq d1.quantity
      expect(f1.claim_amount_per_unit).to eq d1.claim_amount_per_unit
      expect(f1.claim_amount).to eq d1.claim_amount
      expect(f1.drawback_claim_id).to eq d1.drawback_claim_id
      f2 = DrawbackExportHistory.last
      expect(f2.part_number).to eq d2.part_number
      expect(f2.export_ref_1).to eq d2.export_ref_1
      expect(f2.export_date).to eq d2.export_date
      expect(f2.quantity).to eq d2.quantity
      expect(f2.claim_amount_per_unit).to eq d2.claim_amount_per_unit
      expect(f2.claim_amount).to eq d2.claim_amount
      expect(f2.drawback_claim_id).to eq d2.drawback_claim_id
    end
  end
end
