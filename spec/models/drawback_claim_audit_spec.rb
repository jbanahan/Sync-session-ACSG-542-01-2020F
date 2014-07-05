require 'spec_helper'

describe DrawbackClaimAudit do
  describe :bulk_insert do
    it "should insert multiple records" do
      d1 = DrawbackClaimAudit.new(
        export_part_number:'123',
        export_ref_1:'ER1',
        export_date:Date.new(2014,7,5),
        import_date:Date.new(2014,7,4),
        import_entry_number:'ENT123',
        import_part_number:'ABC',
        import_ref_1:'IR1',
        quantity:10,
        drawback_claim_id: 1
      )
      d2 = DrawbackClaimAudit.new(
        export_part_number:'124',
        export_ref_1:'ER2',
        export_date:Date.new(2014,7,6),
        import_date:Date.new(2014,7,3),
        import_entry_number:'ENT124',
        import_part_number:'ABCD',
        import_ref_1:'IR2',
        quantity:11,
        drawback_claim_id: 2
      )
      DrawbackClaimAudit.bulk_insert [d1,d2]
      f1 = DrawbackClaimAudit.first
      expect(f1.export_part_number).to eq d1.export_part_number
      expect(f1.export_ref_1).to eq d1.export_ref_1
      expect(f1.export_date).to eq d1.export_date
      expect(f1.import_date).to eq d1.import_date
      expect(f1.import_entry_number).to eq d1.import_entry_number
      expect(f1.import_part_number).to eq d1.import_part_number
      expect(f1.import_ref_1).to eq d1.import_ref_1
      expect(f1.quantity).to eq d1.quantity
      expect(f1.drawback_claim_id).to eq d1.drawback_claim_id
      f2 = DrawbackClaimAudit.last
      expect(f2.export_part_number).to eq d2.export_part_number
      expect(f2.export_ref_1).to eq d2.export_ref_1
      expect(f2.export_date).to eq d2.export_date
      expect(f2.import_date).to eq d2.import_date
      expect(f2.import_entry_number).to eq d2.import_entry_number
      expect(f2.import_part_number).to eq d2.import_part_number
      expect(f2.import_ref_1).to eq d2.import_ref_1
      expect(f2.quantity).to eq d2.quantity
      expect(f2.drawback_claim_id).to eq d2.drawback_claim_id
    end
  end
end
