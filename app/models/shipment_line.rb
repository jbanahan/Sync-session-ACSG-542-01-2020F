# == Schema Information
#
# Table name: shipment_lines
#
#  id                      :integer          not null, primary key
#  line_number             :integer
#  created_at              :datetime
#  updated_at              :datetime
#  shipment_id             :integer
#  product_id              :integer
#  quantity                :decimal(13, 4)
#  container_id            :integer
#  gross_kgs               :decimal(13, 4)
#  cbms                    :decimal(13, 4)
#  carton_qty              :integer
#  carton_set_id           :integer
#  fcr_number              :string(255)
#  canceled_order_line_id  :integer
#  manufacturer_address_id :integer
#  variant_id              :integer
#
# Indexes
#
#  index_shipment_lines_on_carton_set_id  (carton_set_id)
#  index_shipment_lines_on_container_id   (container_id)
#  index_shipment_lines_on_fcr_number     (fcr_number)
#  index_shipment_lines_on_product_id     (product_id)
#  index_shipment_lines_on_shipment_id    (shipment_id)
#  index_shipment_lines_on_variant_id     (variant_id)
#

require 'open_chain/validator/variant_line_integrity_validator'
class ShipmentLine < ActiveRecord::Base
  include LinesSupport
  include CustomFieldSupport
  include ShallowMerger
  belongs_to :shipment, inverse_of: :shipment_lines
  belongs_to :container, inverse_of: :shipment_lines
  belongs_to :carton_set, inverse_of: :shipment_lines
  belongs_to :canceled_order_line, class_name: 'OrderLine'
  belongs_to :manufacturer_address, class_name: 'Address'
  belongs_to :variant

  validates_uniqueness_of :line_number, :scope => :shipment_id
  validates_with OpenChain::Validator::VariantLineIntegrityValidator

  dont_shallow_merge :ShipmentLine, ['id','created_at','updated_at','line_number']

  def related_orders
    s = Set.new
    self.piece_sets.each do |p|
      s.add p.order_line.order unless p.order_line.nil?
    end
    s
  end

  def find_same
    r = ShipmentLine.where(:shipment_id=>self.shipment_id,:line_number=>self.line_number)
    raise "Multiple shipment lines found for shipment #{self.shipment_id} and line #{self.line_number}" if r.size > 1
    r.empty? ? nil : r.first
  end

  # override the locked? method from LinesSupport to lock lines included on Commercial Invoices
  def locked?
    (self.shipment && self.shipment.locked?) || !self.commercial_invoice_lines.blank?
  end

  def country_of_origin
    order_lines.limit(1).pluck(:country_of_origin).first
  end

  def us_hts_number
    Classification.joins(:country).where(product_id: product_id, countries: {iso_code: 'US'}).joins(:tariff_records).order('tariff_records.line_number ASC').limit(1).pluck(:hts_1).first
  end

  private
  def parent_obj #supporting method for LinesSupport
    self.shipment
  end

  def parent_id_where #supporting method for LinesSupport
    return :shipment_id => self.shipment.id
  end

end
