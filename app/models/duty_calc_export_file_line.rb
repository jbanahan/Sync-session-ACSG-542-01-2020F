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
      imp_lines = DrawbackImportLine.unallocated.where(importer_id:self.importer_id,part_number:self.part_number).where("import_date <= ?",self.export_date).order("import_date #{inner_opts[:lifo] ? "DESC" : "ASC"}")
      remaining_to_allocate = self.unallocated_quantity
      imp_lines.each do |il|
        imp_unallocated = il.unallocated_quantity
        to_allocate = imp_unallocated >= remaining_to_allocate ? remaining_to_allocate : imp_unallocated
        r << self.drawback_allocations.create!(drawback_import_line_id:il.id,quantity:to_allocate)
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
  def make_line_array
    r = []
    [:export_date,:ship_date,:part_number,:carrier,:ref_1,:ref_2,:ref_3,
    :ref_4,:destination_country,:quantity,:schedule_b_code,:description,
    :uom,:exporter,:status,:action_code,:nafta_duty,:nafta_us_equiv_duty,:nafta_duty_rate
    ].each do |v|
      r << val(self[v])
    end
    r[10] = val(self.hts_code) if r[10].blank? && !self.hts_code.blank?
    r
  end

  private 
  def val v
    return "" if v.blank?
    return v.strftime("%m/%d/%Y") if v.respond_to?(:strftime)
    v.to_s
  end
end
