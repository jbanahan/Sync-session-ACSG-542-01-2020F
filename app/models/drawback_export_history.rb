# == Schema Information
#
# Table name: drawback_export_histories
#
#  claim_amount          :decimal(13, 4)
#  claim_amount_per_unit :decimal(13, 4)
#  created_at            :datetime         not null
#  drawback_claim_id     :integer
#  export_date           :date
#  export_ref_1          :string(255)
#  id                    :integer          not null, primary key
#  part_number           :string(255)
#  quantity              :decimal(13, 4)
#  updated_at            :datetime         not null
#
# Indexes
#
#  export_idx                                            (part_number,export_ref_1,export_date)
#  index_drawback_export_histories_on_drawback_claim_id  (drawback_claim_id)
#

class DrawbackExportHistory < ActiveRecord::Base
  attr_accessible :claim_amount, :claim_amount_per_unit, :drawback_claim_id, :export_date, :export_ref_1, :part_number, :quantity

  belongs_to :drawback_claim, inverse_of: :drawback_export_histories

  def self.bulk_insert objects, opts={}
    DrawbackExportHistory.import objects
  end
end
