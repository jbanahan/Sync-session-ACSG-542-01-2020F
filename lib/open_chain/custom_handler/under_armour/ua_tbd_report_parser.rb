require 'open_chain/custom_handler/under_armour/under_armour_custom_definition_support'
require 'open_chain/xl_client'
require 'open_chain/s3'

#
# READ THIS!!!!
#
# The file that SAP sends ends in .xls, but it's really a tab separated file ('cause SAP sucks)
#
module OpenChain; module CustomHandler; module UnderArmour
  class UaTbdReportParser 
    include OpenChain::CustomHandler::UnderArmour::UnderArmourCustomDefinitionSupport
    
    def initialize custom_file
      @custom_file = custom_file 
      @cdefs = self.class.prep_custom_definitions [:colors,:plant_codes,:import_countries]
    end

    def can_view?(user)
      user.company.master? && user.edit_products? && MasterSetup.get.custom_feature?('UA SAP')
    end
    def process user 
      begin
        raise "User does not have permission to process this file." unless can_view?(user)
        tmp = OpenChain::S3.download_to_tempfile OpenChain::S3::BUCKETS[:production], @custom_file.attached.path
        last_style = nil
        collected_rows = []
        CSV.foreach(tmp.path,col_sep:"\t",encoding:"UTF-16LE:UTF-8",quote_char:"\0") do |r|
          next unless self.class.valid_row?(r)
          my_style = r[1].split('-').first
          if my_style!=last_style
            process_rows collected_rows, user unless collected_rows.empty?
            collected_rows = []
          end
          collected_rows << r
          last_style = my_style
        end
        process_rows collected_rows, user unless collected_rows.empty?
        user.messages.create(subject:"TBD File Processing Complete (#{@custom_file.attached_file_name})",
          body:"TBD file (#{@custom_file.attached_file_name}) processing is complete.")
      rescue
        user.messages.create(subject:"TBD File (#{@custom_file.attached_file_name}) Processing Failed (#{@custom_file.attached_file_name})",
          body:"TBD file (#{@custom_file.attached_file_name}) processing failed: #{$!.message}, please contact support.")
        raise $!
      end
      nil
    end

    def process_rows array_of_rows, user
      first_row = array_of_rows.first
      style = first_row[1].split('-').first
      desc = first_row[9].strip
      p = Product.where(unique_identifier:style).first_or_create!
      p.load_custom_values
      write_aggregate_values! p.get_custom_value(@cdefs[:colors]), array_of_rows, lambda {|r| r[1].split('-').last}
      write_aggregate_values! p.get_custom_value(@cdefs[:plant_codes]), array_of_rows, lambda {|r| r[2].blank? ? '' : self.class.prep_plant_code(r[2])}
      write_aggregate_values! p.get_custom_value(@cdefs[:import_countries]), array_of_rows, lambda {|r| 
        k = r[2]
        return nil if r[2].blank?
        DataCrossReference.find_ua_plant_to_iso self.class.prep_plant_code(k)
      }
      p.name = desc
      p.save!
      p.create_snapshot user
    end

    def self.valid_style? style
      return false if style.match /^9999999/
      style.match /^\d[\da-zA-Z]{6}-[\da-zA-Z]{3}$/
    end

    def self.valid_plant? plant_code
      return false if plant_code.blank?
      ['0052','0061','0068'].each {|i| return false if plant_code==i}
      plant_code.match(/^\d{4}$/) || plant_code.match(/^I\d{3}$/) 
    end

    def self.valid_material? material
      !material.match(/DELETE/) && !material.match(/ERROR/)
    end

    def self.valid_row? r
      return false unless r.size == 11
      return false unless r.first.blank?
      style = r[1]
      material = r[9]
      plant = r[2]
      [style,material,plant].each {|v| return false if v.blank?}
      plant = prep_plant_code plant
      return false unless valid_material?(material)
      return false unless valid_plant?(plant)
      return false unless valid_style?(style)
      true
    end

    def self.prep_plant_code c
      s = c.to_s
      s = clean_int s
      while s.length < 4
        s = "0#{s}"
      end
      s
    end

    private
    def write_aggregate_values! custom_value, rows, get_val_lambda
      my_vals = rows.collect {|r| get_val_lambda.call(r)}
      existing_vals = []
      unless custom_value.value.blank?
        existing_vals = custom_value.value.split("\n")
      end
      target_vals = (my_vals + existing_vals).compact.uniq.sort
      if target_vals!=existing_vals
        custom_value.value = target_vals.join("\n")
        custom_value.save!
      end
    end
    def self.clean_int num
      s = num.to_s
      s = s.split('.').first if s.match(/\./)
      s
    end
  end
end; end; end
