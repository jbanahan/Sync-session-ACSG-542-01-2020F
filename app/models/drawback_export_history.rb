# == Schema Information
#
# Table name: drawback_export_histories
#
#  id                    :integer          not null, primary key
#  part_number           :string(255)
#  export_ref_1          :string(255)
#  export_date           :date
#  quantity              :decimal(13, 4)
#  claim_amount_per_unit :decimal(13, 4)
#  claim_amount          :decimal(13, 4)
#  drawback_claim_id     :integer
#  created_at            :datetime         not null
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
    inner_opts = {group_size: 500}.merge opts
    objects.to_a.in_groups_of(inner_opts[:group_size],false) do |grp|
      qry = <<QRY 
INSERT INTO `drawback_export_histories` 
(`claim_amount`, `claim_amount_per_unit`, `drawback_claim_id`, 
  `export_date`, `export_ref_1`, `part_number`, `quantity`,`created_at`,`updated_at`) VALUES 
QRY
      qry << grp.collect { |deh|
        v = [
          num_to_sql(deh.claim_amount),
          num_to_sql(deh.claim_amount_per_unit),
          num_to_sql(deh.drawback_claim_id),
          date_to_sql(deh.export_date),
          str_to_sql(deh.export_ref_1),
          str_to_sql(deh.part_number),
          num_to_sql(deh.quantity),
          'now()',
          'now()'
        ].join(',')
        "(#{v})"
      }.join(',')
      self.connection.execute(qry)
    end
  end
  private
  def self.str_to_sql s
    s.nil? ? 'null' : "\"#{s.to_s}\""
  end
  def self.num_to_sql i
    i.nil? ? 'null' : i.to_s
  end
  def self.date_to_sql d
    d.nil? ? 'null' : "\"#{d.to_s}\""
  end
end
