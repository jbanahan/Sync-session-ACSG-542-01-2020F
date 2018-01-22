# == Schema Information
#
# Table name: drawback_claim_audits
#
#  id                  :integer          not null, primary key
#  export_part_number  :string(255)
#  export_ref_1        :string(255)
#  export_date         :date
#  import_part_number  :string(255)
#  import_ref_1        :string(255)
#  import_date         :date
#  import_entry_number :string(255)
#  quantity            :decimal(13, 4)
#  drawback_claim_id   :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  export_idx                                        (export_part_number,export_ref_1,export_date)
#  import_idx                                        (import_part_number,import_entry_number,import_ref_1)
#  index_drawback_claim_audits_on_drawback_claim_id  (drawback_claim_id)
#

class DrawbackClaimAudit < ActiveRecord::Base
  attr_accessible :drawback_claim_id, :export_date, :export_part_number, :export_ref_1, :import_date, :import_entry_number, :import_part_number, :import_ref_1, :quantity

  belongs_to :drawback_claim, inverse_of: :drawback_claim_audits

  def self.bulk_insert objects, opts={}
    inner_opts = {group_size: 500}.merge opts
    objects.to_a.in_groups_of(inner_opts[:group_size],false) do |grp|
      qry = <<QRY 
INSERT INTO `drawback_claim_audits` 
(`drawback_claim_id`, `export_date`, `export_part_number`, 
  `export_ref_1`, `import_date`,`import_entry_number`, `import_part_number`,
  `import_ref_1`, `quantity`, `created_at`,`updated_at`) VALUES 
QRY
      qry << grp.collect { |deh|
        v = [
          num_to_sql(deh.drawback_claim_id),
          date_to_sql(deh.export_date),
          str_to_sql(deh.export_part_number),
          str_to_sql(deh.export_ref_1),
          date_to_sql(deh.import_date),
          str_to_sql(deh.import_entry_number),
          str_to_sql(deh.import_part_number),
          str_to_sql(deh.import_ref_1),
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
