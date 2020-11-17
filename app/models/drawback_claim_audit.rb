# == Schema Information
#
# Table name: drawback_claim_audits
#
#  created_at          :datetime         not null
#  drawback_claim_id   :integer
#  export_date         :date
#  export_part_number  :string(255)
#  export_ref_1        :string(255)
#  id                  :integer          not null, primary key
#  import_date         :date
#  import_entry_number :string(255)
#  import_part_number  :string(255)
#  import_ref_1        :string(255)
#  quantity            :decimal(13, 4)
#  updated_at          :datetime         not null
#
# Indexes
#
#  export_idx                                        (export_part_number,export_ref_1,export_date)
#  import_idx                                        (import_part_number,import_entry_number,import_ref_1)
#  index_drawback_claim_audits_on_drawback_claim_id  (drawback_claim_id)
#

class DrawbackClaimAudit < ActiveRecord::Base
  belongs_to :drawback_claim, inverse_of: :drawback_claim_audits

  def self.bulk_insert objects, opts={}
    DrawbackClaimAudit.import objects
  end
end
