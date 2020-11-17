# == Schema Information
#
# Table name: duty_calc_export_file_lines
#
#  action_code              :string(255)
#  carrier                  :string(255)
#  color_description        :string(255)
#  created_at               :datetime         not null
#  customs_line_number      :integer
#  description              :string(255)
#  destination_country      :string(255)
#  duty_calc_export_file_id :integer
#  export_date              :date
#  exporter                 :string(255)
#  hts_code                 :string(255)
#  id                       :integer          not null, primary key
#  importer_id              :integer
#  nafta_duty               :decimal(10, )
#  nafta_duty_rate          :decimal(10, )
#  nafta_us_equiv_duty      :decimal(10, )
#  part_number              :string(255)
#  quantity                 :decimal(10, )
#  ref_1                    :string(255)
#  ref_2                    :string(255)
#  ref_3                    :string(255)
#  ref_4                    :string(255)
#  ref_5                    :string(255)
#  ref_6                    :string(255)
#  schedule_b_code          :string(255)
#  ship_date                :date
#  size_description         :string(255)
#  status                   :string(255)
#  style                    :string(255)
#  uom                      :string(255)
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_duty_calc_export_file_lines_on_duty_calc_export_file_id  (duty_calc_export_file_id)
#  index_duty_calc_export_file_lines_on_export_date               (export_date)
#  index_duty_calc_export_file_lines_on_importer_id               (importer_id)
#  index_duty_calc_export_file_lines_on_part_number               (part_number)
#  index_duty_calc_export_file_lines_on_ref_1                     (ref_1)
#  index_duty_calc_export_file_lines_on_ref_2                     (ref_2)
#  unique_refs                                                    (ref_1,ref_2,ref_3,ref_4,part_number,importer_id)
#

class DutyCalcExportFileLine < ActiveRecord::Base
  belongs_to :importer, :class_name=>"Company"
  belongs_to :duty_calc_export_file, :inverse_of=>:duty_calc_export_file_lines
  has_many :drawback_allocations, inverse_of: :duty_calc_export_file_line, dependent: :destroy

  scope :not_in_imports, lambda {
    joins("LEFT OUTER JOIN drawback_import_lines on duty_calc_export_file_lines.part_number = drawback_import_lines.part_number AND duty_calc_export_file_lines.export_date > drawback_import_lines.import_date AND duty_calc_export_file_lines.importer_id = drawback_import_lines.importer_id").
    where("drawback_import_lines.id is null")
  }

  # allocate the export vs an import for a claim
  def allocate! opts = {}
    inner_opts = {lifo:false}.merge(opts)
    r = []
    self.class.transaction do
      imp_lines = DrawbackImportLine.unallocated.where(importer_id:self.importer_id, part_number:self.part_number).where("import_date <= ?", self.export_date).order("import_date #{inner_opts[:lifo] ? "DESC" : "ASC"}")
      remaining_to_allocate = self.unallocated_quantity
      imp_lines.each do |il|
        imp_unallocated = il.unallocated_quantity
        to_allocate = imp_unallocated >= remaining_to_allocate ? remaining_to_allocate : imp_unallocated
        r << self.drawback_allocations.create!(drawback_import_line_id:il.id, quantity:to_allocate)
        remaining_to_allocate += -to_allocate
        break if remaining_to_allocate == 0
      end
    end
    r
  end

  def unallocated_quantity
    self.quantity - self.drawback_allocations.sum(:quantity)
  end

  # returns an array of strings that can be used to make the duty calc csv file
  def make_line_array duty_calc_format: :legacy
    r = []
    get_fields(duty_calc_format).each do |v|
      line_val = val(self[v])
      # Substitute HTS Code for Schedule B Code if there's no Schedule B and there is an HTS.
      if v == :schedule_b_code && line_val.blank? && !self.hts_code.blank?
        line_val = val(self.hts_code)
      end
      r << line_val
    end
    r
  end

  private
    def val v
      return "" if v.blank?
      return v.strftime("%m/%d/%Y") if v.respond_to?(:strftime)
      v.to_s
    end

    def get_fields duty_calc_format
      get_legacy_format_fields
    end

    def get_legacy_format_fields
      [:export_date, :ship_date, :part_number, :carrier, :ref_1, :ref_2, :ref_3,
       :ref_4, :destination_country, :quantity, :schedule_b_code, :description,
       :uom, :exporter, :status, :action_code, :nafta_duty, :nafta_us_equiv_duty, :nafta_duty_rate
      ]
    end

end
