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

        def self.parse file_content
          self.new.process file_content
        end

        def process file_content
          header = true
          ActiveRecord::Base.transaction do
            CSV.parse(file_content, skip_blanks: true) do |row|
              if header
                header = false
                next
              end
              *, uid = get_part_number_and_uid(row[3])
              p = nil
              Lock.acquire("Product-#{uid}") { p = Product.where(unique_identifier: uid).first_or_create! }
              Lock.with_lock_retry(p) do 
                update_product p, row, @cdefs, @cust_id
                p.create_snapshot User.integration
              end
            end
          end        
        end

        def update_product product, row, cdefs, cust_id
          valid = HmI1Validator.new row
          unless product.name == row[5]
            product.name = row[5]
            product.save!
          end
          part_number, * = (valid.check(3) ? get_part_number_and_uid(row[3]) : nil)
          product.find_and_set_custom_value cdefs[:prod_part_number], part_number
          product.importer_id = cust_id
          product.save!

          cv_concat product, :prod_po_numbers, valid.filter(0, row[0]), cdefs
          assign_earlier product, :prod_earliest_ship_date, valid.filter(1, row[1]), cdefs
          assign_earlier product, :prod_earliest_arrival_date, valid.filter(2, row[2]), cdefs
          product.update_custom_value! cdefs[:prod_sku_number], valid.filter(3, row[3])
          cv_concat product, :prod_season, valid.filter(4, row[4]), cdefs
          product.update_custom_value! cdefs[:prod_suggested_tariff], valid.filter(6, row[6])
          cv_concat product, :prod_countries_of_origin, valid.filter(7, row[7]), cdefs
          product
        end

        def cv_concat product, cv_uid, str, cdefs
          old_str = (product.get_custom_value cdefs[cv_uid]).value
          arr = old_str.blank? ? [] : old_str.split("\n ")
          arr << str unless arr.include? str
          new_str = arr.join("\n ")
          product.update_custom_value! cdefs[cv_uid], new_str unless new_str == old_str
          product
        end

        def assign_earlier product, cv_uid, date_str, cdefs
          current_date = (product.get_custom_value cdefs[cv_uid]).value
          parsed_date = Date.strptime(date_str,'%m/%d/%Y')
          product.update_custom_value!(cdefs[cv_uid], parsed_date) if current_date.nil? || parsed_date < current_date
          product
        end   
      
        private

        def get_part_number_and_uid sku
          trunc_sku = sku[0..6]
          [trunc_sku, "HENNE-#{trunc_sku}"]
        end
      end

      class HmI1Validator
        def initialize row
          @valid_arr = validate_row row
        end
        
        def filter index, new_val
          @valid_arr[index] ? new_val : nil
        end

        def check index
          @valid_arr[index]
        end

        private
        
        def validate_row row
          date_pattern = /^\d{2}\/\d{2}\/\d{4}$/
          arr = []
          arr << (row[0] =~ /^\d{6}$/ ? true : false)
          arr << (row[1] =~ date_pattern ? true : false)
          arr << (row[2] =~ date_pattern ? true : false)
          arr << (row[3] =~ /^\d{13}$/ ? true : false)
          arr << (row[4] =~ /^\d{6}$/ ? true : false)
          arr << true #placeholder to keep indexing consistent
          arr << (row[6] =~ /^\d{8}$/ ? true : false)
          arr << (row[7] =~ /^[A-Z]{2}$/ ? true : false)
        end
      end
    
    end 
  end 
end