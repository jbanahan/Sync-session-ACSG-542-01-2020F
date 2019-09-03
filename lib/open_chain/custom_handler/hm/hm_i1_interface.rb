require 'open_chain/custom_handler/vfitrack_custom_definition_support'
module OpenChain; module CustomHandler; module Hm; class HmI1Interface
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
  include OpenChain::IntegrationClientParser

  def initialize
     @cust = Company.with_customs_management_number('HENNE').first
     @cdefs = (self.class.prep_custom_definitions [:prod_po_numbers, :prod_sku_number, :prod_earliest_ship_date, :prod_earliest_arrival_date,
      :prod_part_number, :prod_season, :prod_suggested_tariff, :prod_countries_of_origin, :prod_set, :prod_fabric_content, :prod_units_per_set])
  end

  def self.parse_file file_content, log, opts = {}
    self.new.process file_content, log
  end

  def process file_content, log
    log.company = @cust
    CSV.parse(file_content, skip_blanks: true, :col_sep => ";") do |row|
      part_number, uid = get_part_number_and_uid(row[3])
      p = nil
      Lock.acquire("Product-#{uid}") { p = Product.where(unique_identifier: uid).first_or_create! }
      Lock.with_lock_retry(p) do
        log.add_identifier InboundFileIdentifier::TYPE_ARTICLE_NUMBER, part_number, module_type:Product.to_s, module_id:p.id
        update_product p, row
        p.create_snapshot User.integration if p.changed_by_i1?
      end
    end
  end

  def update_product product, row
    self.class.add_custom_methods product
    part_number, * = get_part_number_and_uid(row[3])
    
    product.update_attr_with_flag :importer_id, @cust.id
    product.update_field_with_flag @cdefs[:prod_part_number], part_number
    cv_concat product, @cdefs[:prod_po_numbers], row[0]
    assign_earlier product, @cdefs[:prod_earliest_ship_date], format_date(row[1])
    assign_earlier product, @cdefs[:prod_earliest_arrival_date], format_date(row[2])
    cv_concat product, @cdefs[:prod_season], row[4]
    product.update_attr_with_flag :name, row[5], true
    product.update_field_with_flag @cdefs[:prod_suggested_tariff], row[6]
    cv_concat product, @cdefs[:prod_countries_of_origin], row[7]
    product.update_field_with_flag @cdefs[:prod_fabric_content], row[8].to_s.strip unless row[8].blank?
    product.update_field_with_flag @cdefs[:prod_units_per_set], row[9].to_s.strip.to_i unless row[9].blank?
    product.update_field_with_flag @cdefs[:prod_set], (row[10].to_s.strip.downcase == "yes") unless row[10].blank?

    product.save!
    product
  end

  def cv_concat product, cdef, str
    old_str = product.custom_value cdef
    arr = old_str.blank? ? [] : old_str.split("\n ")
    new_str = (arr << str).uniq.join("\n ")
    product.update_field_with_flag cdef, new_str
    product
  end

  def assign_earlier product, cdef, date_str
    old_date = product.custom_value cdef
    parsed_date = Date.strptime(date_str,'%m/%d/%Y')
    product.update_field_with_flag cdef, parsed_date if old_date.nil? || parsed_date < old_date
    product
  end   

  private

  def get_part_number_and_uid sku
    trunc_sku = sku[0..6]
    [trunc_sku, "HENNE-#{trunc_sku}"]
  end

  def format_date date
    if (date =~ /^\d{8}$/)
      year = date[0..3]
      month = date[4..5]
      day = date[6..7]
      "#{month}/#{day}/#{year}"
    else
      nil
    end
  end

  def self.add_custom_methods product
    def product.update_attr_with_flag attribute, value, skip_if_assigned=false
      return if skip_if_assigned && self.send(attribute).present?
      @changed_by_i1 = true if self.send(attribute) != value
      self.send "#{attribute}=", value
    end

    def product.update_field_with_flag field, value, skip_if_assigned=false
      cv = self.get_custom_value field
      return if skip_if_assigned && cv.value.present?
      if cv.value != value
        @changed_by_i1 = true
        cv.value = value
      end
    end

    def product.changed_by_i1?
      @changed_by_i1 == true
    end
  end
  
end; end; end; end
