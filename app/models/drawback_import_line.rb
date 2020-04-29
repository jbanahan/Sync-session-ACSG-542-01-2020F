# == Schema Information
#
# Table name: drawback_import_lines
#
#  box_37_duty            :decimal(10, 2)
#  box_40_duty            :decimal(10, 2)
#  color_description      :string(255)
#  compute_code           :string(255)
#  country_of_export_code :string(255)
#  country_of_origin_code :string(255)
#  created_at             :datetime         not null
#  description            :string(255)
#  duty_per_unit          :decimal(16, 9)
#  entered_value_7501     :integer
#  entry_number           :string(255)
#  exchange_rate          :decimal(8, 6)
#  hts_code               :string(255)
#  hts_duty               :decimal(12, 2)
#  hts_quantity           :decimal(12, 2)
#  id                     :integer          not null, primary key
#  import_date            :date
#  importer_id            :integer
#  line_number            :integer
#  liquidation_date       :date
#  ocean                  :boolean
#  part_number            :string(255)
#  port_code              :string(255)
#  product_id             :integer
#  quantity               :decimal(13, 4)
#  quantity_2             :decimal(12, 2)
#  rate                   :decimal(12, 8)
#  receipt_quantity       :decimal(8, 6)
#  received_date          :date
#  ref_1                  :string(255)
#  ref_2                  :string(255)
#  single_line            :boolean
#  size_description       :string(255)
#  spi_primary            :string(255)
#  style                  :string(255)
#  summary_line_count     :integer
#  total_invoice_value    :decimal(10, 2)
#  total_mpf              :decimal(10, 2)
#  total_taxes            :decimal(12, 2)
#  unit_of_measure        :string(255)
#  unit_price             :decimal(16, 7)
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_drawback_import_lines_on_importer_id  (importer_id)
#  index_drawback_import_lines_on_part_number  (part_number)
#  index_drawback_import_lines_on_product_id   (product_id)
#

class DrawbackImportLine < ActiveRecord::Base
  include LinesSupport

  attr_accessible :box_37_duty, :box_40_duty, :compute_code,
    :country_of_origin_code, :description, :duty_per_unit, :entry_number,
    :hts_code, :import_date, :importer_id, :line_number, :ocean, :part_number,
    :port_code, :product_id, :product, :quantity, :rate, :received_date,
    :total_invoice_value, :total_mpf, :unit_of_measure, :unit_price,
    :color_description, :size_description, :exchange_rate, :receipt_quantity,
    :hts_duty, :hts_quantity, :quantity_2, :entered_value_7501, :total_taxes,
    :spi_primary, :summary_line_count, :liquidation_date, :ref_1, :ref_2,
    :country_of_export_code, :style, :single_line, :importer

  belongs_to :importer, :class_name=>"Company"
  has_many :duty_calc_import_file_lines, :dependent=>:destroy
  has_many :drawback_allocations, dependent: :destroy, inverse_of: :drawback_import_line

  scope :not_in_duty_calc_file, -> { joins("left outer join duty_calc_import_file_lines on drawback_import_lines.id = duty_calc_import_file_lines.drawback_import_line_id").where("duty_calc_import_file_lines.id is null") }

  scope :unallocated, -> { where("drawback_import_lines.quantity > (select ifnull(sum(drawback_allocations.quantity),0) FROM drawback_allocations WHERE drawback_import_lines.id = drawback_allocations.drawback_import_line_id)") }

  def unallocated_quantity
    self.quantity - self.drawback_allocations.sum(:quantity)
  end

  # return an array suitable for passing to duty calc
  # This is, as of 2018, considered a legacy format.
  def duty_calc_line_array_legacy
    [
      self.entry_number,
      self.import_date.blank? ? "" : self.import_date.strftime("%m/%d/%Y"),
      self.received_date.blank? ? "" : self.received_date.strftime("%m/%d/%Y"),
      "",
      self.port_code,
      "%0.2f" % float_or_zero(self.box_37_duty),
      "%0.2f" % float_or_zero(self.box_40_duty),
      "",
      "%0.2f" % float_or_zero(self.total_invoice_value),
      "%0.2f" % float_or_zero(self.total_mpf),
      "1",
      "",
      self.id.to_s,
      "",
      "",
      self.country_of_origin_code,
      "",
      "",
      self.part_number,
      self.part_number,
      self.hts_code,
      self.description,
      self.unit_of_measure,
      "",
      "%0.9f" % float_or_zero(self.quantity), # quantity imported
      "%0.9f" % float_or_zero(self.quantity), # quantity available
      "",
      "%0.7f" % float_or_zero(self.unit_price),
      "",
      "",
      "",
      "%0.9f" % float_or_zero(self.rate),
      "",
      "",
      "",
      "%0.9f" % float_or_zero(self.duty_per_unit),
      "7",
      "",
      (self.ocean? ? "Y" : "")
    ]
  end

  # Output a string matching the DutyCalc ASCII import format
  def duty_calc_line_legacy
    duty_calc_line_array_legacy.to_csv
  end

  # Returns an array suitable for passing to duty calc.
  # This is a new format for 2018.
  def duty_calc_line_array_standard
    [
        self.entry_number,
        self.import_date.blank? ? "" : self.import_date.strftime("%m/%d/%Y"),
        self.port_code,
        "%0.2f" % float_or_zero(self.box_37_duty),
        "%0.2f" % float_or_zero(self.box_40_duty),
        self.liquidation_date.nil? ? "" : self.liquidation_date.strftime("%m/%d/%Y"),
        "%0.2f" % float_or_zero(self.total_invoice_value),
        "%0.2f" % float_or_zero(self.total_mpf),
        self.importer.nil? ? "" : self.importer.customs_identifier,
        self.ref_1,
        self.ref_2,
        "",
        self.country_of_origin_code,
        self.country_of_export_code,
        self.part_number,
        self.hts_code,
        self.description,
        self.unit_of_measure,
        "%0.9f" % float_or_zero(self.quantity),
        "",
        "%0.9f" % float_or_zero(self.rate),
        "",
        (self.ocean? ? "Y" : "")
    ]
  end

  private

    def float_or_zero val
      val.blank? ? 0 : val
    end

    def fix_width str, length, ljust=true
      r = ""
      unless str.blank?
        r = str
        r = r[0, length] if r.length > length
      end
      if ljust
        r = r.ljust(length)
      else
        r = r.rjust(length)
      end
      r
    end
end
