require 'open_chain/custom_handler/vfitrack_custom_definition_support'
module OpenChain
  module CustomHandler
    module Hm
      class HmI1Interface
        include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport
        extend OpenChain::IntegrationClientParser

        def initialize
           @cust_id = Company.where(alliance_customer_number: 'HENNE').first.id
           @cdefs = (self.class.prep_custom_definitions [:prod_po_numbers, :prod_sku_number, :prod_earliest_ship_date, :prod_earliest_arrival_date, 
            :prod_part_number, :prod_season, :prod_suggested_tariff, :prod_countries_of_origin])
        end

        def self.parse file_content, opts = {}
          self.new.process file_content
        end

        def process file_content
          CSV.parse(file_content, skip_blanks: true, :col_sep => ";") do |row|
            *, uid = get_part_number_and_uid(row[3])
            p = nil
            Lock.acquire("Product-#{uid}") { p = Product.where(unique_identifier: uid).first_or_create! }
            Lock.with_lock_retry(p) do 
              update_product p, row, @cdefs, @cust_id
              p.create_snapshot User.integration
            end
          end
        end

        def update_product product, row, cdefs, cust_id
          part_number, * = get_part_number_and_uid(row[3])
          
          product.importer_id = cust_id
          product.find_and_set_custom_value cdefs[:prod_part_number], part_number
          cv_concat product, :prod_po_numbers, row[0], cdefs
          assign_earlier product, :prod_earliest_ship_date, format_date(row[1]), cdefs
          assign_earlier product, :prod_earliest_arrival_date, format_date(row[2]), cdefs
          product.find_and_set_custom_value cdefs[:prod_sku_number], row[3]
          cv_concat product, :prod_season, row[4], cdefs
          product.name = row[5]
          product.find_and_set_custom_value cdefs[:prod_suggested_tariff], row[6]
          cv_concat product, :prod_countries_of_origin, row[7], cdefs
          product.save!
          product
        end

        def cv_concat product, cv_uid, str, cdefs
          old_str = (product.get_custom_value cdefs[cv_uid]).value
          arr = old_str.blank? ? [] : old_str.split("\n ")
          arr << str unless arr.include? str
          new_str = arr.join("\n ")
          product.find_and_set_custom_value cdefs[cv_uid], new_str unless new_str == old_str
          product
        end

        def assign_earlier product, cv_uid, date_str, cdefs
          current_date = (product.get_custom_value cdefs[cv_uid]).value
          parsed_date = Date.strptime(date_str,'%m/%d/%Y')
          product.find_and_set_custom_value(cdefs[cv_uid], parsed_date) if current_date.nil? || parsed_date < current_date
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
      end

    end 
  end 
end