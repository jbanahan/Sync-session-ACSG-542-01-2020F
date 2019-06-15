# == Schema Information
#
# Table name: invoices
#
#  consignee_id                :integer
#  country_import_id           :integer
#  country_origin_id           :integer
#  created_at                  :datetime         not null
#  currency                    :string(255)
#  customer_reference_number   :string(255)
#  customer_reference_number_2 :string(255)
#  description_of_goods        :text
#  exchange_rate               :decimal(8, 6)
#  factory_id                  :integer
#  gross_weight                :decimal(11, 2)
#  gross_weight_uom            :string(255)
#  id                          :integer          not null, primary key
#  importer_id                 :integer
#  invoice_date                :date
#  invoice_number              :string(255)
#  invoice_total_domestic      :decimal(13, 2)
#  invoice_total_foreign       :decimal(13, 2)
#  last_exported_from_source   :datetime
#  last_file_bucket            :string(255)
#  last_file_path              :string(255)
#  manually_generated          :boolean
#  net_invoice_total           :decimal(13, 2)
#  net_weight                  :decimal(11, 2)
#  net_weight_uom              :string(255)
#  ship_mode                   :string(255)
#  ship_to_id                  :integer
#  terms_of_payment            :string(255)
#  terms_of_sale               :string(255)
#  total_charges               :decimal(11, 2)
#  total_discounts             :decimal(12, 2)
#  updated_at                  :datetime         not null
#  vendor_id                   :integer
#  volume                      :decimal(11, 5)
#  volume_uom                  :string(255)
#
# Indexes
#
#  index_invoices_on_importer_id     (importer_id)
#  index_invoices_on_invoice_number  (invoice_number)
#

class Invoice < ActiveRecord::Base
  include CoreObjectSupport
  include IntegrationParserSupport

  attr_accessible :consignee_id, :country_import_id, :country_origin_id, :currency, 
    :customer_reference_number, :customer_reference_number_2, :description_of_goods, :exchange_rate, 
    :factory_id, :gross_weight, :gross_weight_uom, :importer_id, :importer, :invoice_date, 
    :invoice_number, :invoice_total_domestic, :invoice_total_foreign, 
    :last_exported_from_source, :last_file_bucket, :last_file_path, 
    :manually_generated, :net_invoice_total, :net_weight, :net_weight_uom, 
    :ship_mode, :ship_to_id, :terms_of_payment, :terms_of_sale, :total_charges, 
    :total_discounts, :vendor_id, :volume, :volume_uom
  
  belongs_to :country_origin, class_name: "Country"
  belongs_to :country_import, class_name: "Country"
  belongs_to :factory, class_name: "Company"
  belongs_to :importer, class_name: "Company"
  belongs_to :ship_to, class_name: "Address"
  belongs_to :vendor, class_name: "Company"
  belongs_to :consignee, class_name: "Company"

  has_many :invoice_lines, dependent: :destroy, autosave: true, inverse_of: :invoice

  def self.search_where user
    if user.company.master
      return "1=1"
    elsif user.company.importer
      "invoices.importer_id = #{user.company_id} or invoices.importer_id IN (select child_id from linked_companies where parent_id = #{user.company_id})"
    elsif user.company.factory
      "invoices.factory_id = #{user.company_id} or invoices.factory_id IN (select child_id from linked_companies where parent_id = #{user.company_id})"
    elsif user.company.vendor
      "invoices.vendor_id = #{user.company_id}"
    else
      "1=0"
    end
  end

  def self.search_secure user, base_object
    base_object.where search_where user
  end

  def can_view? user
    return user.view_commercial_invoices? &&
        (
          user.company.master ||
          (user.company_id == self.importer_id) ||
          (user.company_id == self.factory_id) ||
          (user.company_id == self.vendor_id)
        )
  end

  def calculate_and_set_invoice_totals
    discounts = BigDecimal("0")
    charges = BigDecimal("0")
    value_foreign = BigDecimal("0")
    value_domestic = BigDecimal("0")

    self.invoice_lines.each do |line|
      discounts += line.calculate_total_discounts
      charges += line.calculate_total_charges
      value_foreign += line.value_foreign unless line.value_foreign.nil?
      value_domestic += line.value_domestic unless line.value_domestic.nil?
    end

    self.invoice_total_foreign = value_foreign
    self.invoice_total_domestic = value_domestic
    self.total_charges = charges
    self.total_discounts = discounts

    # I'm not sure we can actually set the net_invoice_total in a generic fashion.
    # I THINK this might just be total value foreign minus the discounts.
    # .ie the Net Total is the amount the importer will actually pay the invoicer.

    # But that's based solely on my knowledge of how Ann Taylor calculates invoices,
    # and I'm not sure that actually fits across the board.  So I'm leaving the 
    # net_invoice_total blank

    nil
  end
end
