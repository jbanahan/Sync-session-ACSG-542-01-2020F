# == Schema Information
#
# Table name: canadian_pga_lines
#
#  agency_code                :string(255)
#  batch_lot_number           :string(255)
#  brand_name                 :string(255)
#  commercial_invoice_line_id :integer
#  commodity_type             :string(255)
#  country_of_origin          :string(255)
#  created_at                 :datetime
#  exception_processes        :string(255)
#  expiry_date                :datetime
#  fda_product_code           :string(255)
#  file_name                  :string(255)
#  gtin                       :string(255)
#  id                         :integer          not null, primary key
#  importer_contact_email     :string(255)
#  importer_contact_name      :string(255)
#  importer_contact_phone     :string(255)
#  intended_use_code          :string(255)
#  lpco_number                :string(255)
#  lpco_type                  :string(255)
#  manufacture_date           :datetime
#  model_designation          :string(255)
#  model_label                :string(255)
#  model_number               :string(255)
#  product_name               :string(255)
#  program_code               :string(255)
#  purpose                    :string(255)
#  state_of_origin            :string(255)
#  unique_device_identifier   :string(255)
#  updated_at                 :datetime
#

class CanadianPgaLine < ActiveRecord::Base
  belongs_to :commercial_invoice_line
  has_many :canadian_pga_line_ingredients, dependent: :destroy, autosave: true, inverse_of: :canadian_pga_line

  attr_accessible :agency_code, :batch_lot_number, :brand_name, :commercial_invoice_line_id, :commodity_type, :country_of_origin,
                  :exception_processes, :expiry_date, :fda_product_code, :file_name, :gtin, :importer_contact_email,
                  :importer_contact_name, :importer_contact_phone, :intended_use_code, :lpco_number, :lpco_type, :manufacture_date,
                  :model_designation, :model_label, :model_number, :product_name, :program_code, :purpose, :state_of_origin,
                  :unique_device_identifier

  def fingerprint field_names
    self.attributes.values_at(*field_names.map(&:to_s)).join('~')
  end

end
