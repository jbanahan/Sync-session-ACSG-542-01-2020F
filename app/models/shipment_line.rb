# == Schema Information
#
# Table name: shipment_lines
#
#  canceled_order_line_id  :integer
#  carton_qty              :integer
#  carton_set_id           :integer
#  cbms                    :decimal(13, 4)
#  container_id            :integer
#  created_at              :datetime         not null
#  fcr_number              :string(255)
#  gross_kgs               :decimal(13, 4)
#  id                      :integer          not null, primary key
#  invoice_number          :string(255)
#  line_number             :integer
#  manufacturer_address_id :integer
#  master_bill_of_lading   :string(255)
#  mid                     :string(255)
#  net_weight              :decimal(11, 2)
#  net_weight_uom          :string(255)
#  product_id              :integer
#  quantity                :decimal(13, 4)
#  shipment_id             :integer
#  updated_at              :datetime         not null
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

  attr_accessible :canceled_order_line_id, :carton_qty, :carton_set_id,
    :cbms, :container_id, :container, :fcr_number, :gross_kgs, :invoice_number,
    :line_number, :manufacturer_address_id, :master_bill_of_lading, :mid,
    :product_id, :product, :quantity, :shipment_id, :shipment, :variant_id,
    :variant, :linked_order_line_id, :net_weight, :net_weight_uom

  belongs_to :shipment, inverse_of: :shipment_lines
  belongs_to :container, inverse_of: :shipment_lines
  belongs_to :carton_set, inverse_of: :shipment_lines
  belongs_to :canceled_order_line, class_name: 'OrderLine'
  belongs_to :manufacturer_address, class_name: 'Address'
  belongs_to :variant
  after_save :clear_order_line

  validates_uniqueness_of :line_number, :scope => :shipment_id
  validates_with OpenChain::Validator::VariantLineIntegrityValidator

  dont_shallow_merge :ShipmentLine, ['id', 'created_at', 'updated_at', 'line_number']

  def related_orders
    s = Set.new
    self.piece_sets.each do |p|
      s.add p.order_line.order unless p.order_line.nil?
    end
    s
  end

  def find_same
    r = ShipmentLine.where(:shipment_id=>self.shipment_id, :line_number=>self.line_number)
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

  def order_line
    @var_order_line ||= self.order_lines.first
  end

  def dimensional_weight
    (self.cbms / BigDecimal("0.006")).round(2) if self.cbms
  end

  def chargeable_weight
    dm = dimensional_weight
    kgs = self.gross_kgs

    return nil if dm.nil? && kgs.nil?

    ((dm || 0) > (kgs || 0)) ? dm : kgs
  end

  private
  def parent_obj # supporting method for LinesSupport
    self.shipment
  end

  def parent_id_where # supporting method for LinesSupport
    return :shipment_id => self.shipment.id
  end

  def clear_order_line
    remove_instance_variable(:@var_order_line) if instance_variable_defined?(:@var_order_line)
  end

end
