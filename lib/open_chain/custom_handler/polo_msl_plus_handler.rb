require 'open_chain/xl_client'
module OpenChain
  module CustomHandler
    class PoloMslPlusHandler
      
      def initialize(custom_file)
        @custom_file = custom_file
      end

      def can_view? user
        user.edit_products?
      end

      def process user
        errors = []
        @custom_file.update_attributes(:module_type=>CoreModule::PRODUCT.class_name)
        @custom_file.custom_file_records.delete_all #not worrying about callbacks here
        x = OpenChain::XLClient.new(@custom_file.attached.path)
        last_row_number = x.last_row_number 0
        (4..last_row_number).each do |n|
          row = x.get_row 0, n
          cell_map = {}
          row.each do |c|
            v = c['cell']['value']
            case c['position']['column']
            when  9
              cell_map[:season] = v
            when 11
              cell_map[:style] = v
            when 12
              cell_map[:board] = v
            when 20
              cell_map[:name] = v
            when 21
              cell_map[:fiber] = v
            when 28
              cell_map[:gcc] = v
            end
          end
          if cell_map[:style].blank?
            errors << "Row #{n+1} skipped, missing style number."
          else
            Product.transaction do
              p = Product.find_or_create_by_unique_identifier(cell_map[:style].strip)
              p.name = cell_map[:name] if p.name.blank?
              p.save!
              set_custom_value p, 'Board Number', cell_map[:board]
              set_custom_value p, 'Season', cell_map[:season]
              set_custom_value p, 'Fiber Content %s', cell_map[:fiber]
              set_custom_value p, 'GCC Description', cell_map[:gcc]
              @custom_file.custom_file_records.create!(:linked_object=>p)
              p.create_snapshot user
            end
          end
        end
        msg_body ="File #{@custom_file.attached_file_name} has completed.<br/><br/>" 
        msg_body << "There were #{errors.size} errors.<br/><br/>" unless errors.blank?
        msg_body << "Click <a href='/custom_features/msl_plus/#{@custom_file.id}'>here</a> to see the results."
        user.messages.create(:subject=>"MSL+ File Complete #{errors.blank? ? "" : "#{errors.size} ERRORS"}",
          :body=>msg_body)
        errors
      end

      def make_updated_file user
        x = OpenChain::XLClient.new(@custom_file.attached.path)
        iso_codes = ['HK','CN','MO','MY','SG','TW','PH','JP','KR']
        countries = []
        iso_codes.each {|c| countries << Country.where(:iso_code=>c).first}
        fiber_cd = CustomDefinition.where(:label => "Fiber Content %s").first
        raise "Cannot find custom field with description \"Fiber Content %s\"" unless fiber_cd
        width_cd = CustomDefinition.where(:label=>"Width (cm)").first
        raise "Cannot find custom field with description \"Width (cm)\"" unless width_cd
        length_cd = CustomDefinition.where(:label=>"Length (cm)").first
        raise "Cannot find custom field with description \"Length (cm)\"" unless length_cd
        height_cd = CustomDefinition.where(:label=>"Height (cm)").first
        raise "Cannot find custom field with description \"Height (cm)\"" unless height_cd
        last_row_number = x.last_row_number 0
        (4..last_row_number).each do |n|
          style = x.get_cell(0,n,11)['cell']['value']
          next if style.blank? #skip if row doesn't have style
          p = Product.where(:unique_identifier=>style.strip).first
          next unless p #skip if product not found
          x.set_cell(0,n,29,mp1_value?(p) ? 'YES' : '')
          x.set_cell(0,n,44,p.name)
          x.set_cell(0,n,45,p.get_custom_value(fiber_cd).value)
          x.set_cell(0,n,119,p.get_custom_value(height_cd).value)
          x.set_cell(0,n,120,p.get_custom_value(length_cd).value)
          x.set_cell(0,n,121,p.get_custom_value(width_cd).value)
          countries.each_with_index do |c,i|
            classification = p.classifications.where(:country_id=>c.id).first
            next unless classification
            tr = classification.tariff_records.first
            next unless tr
            x.set_cell(0,n,35+i,tr.hts_1)
            x.set_cell(0,n,48+i,tr.hts_2)
            x.set_cell(0,n,61+i,tr.hts_3)
          end
        end
        target = "#{MasterSetup.get.uuid}/updated_msl_plus_files/#{user.id}/#{Time.now.to_i}.#{@custom_file.attached_file_name.split('.').last}" 
        x.save target
        target
      end

      private
      def mp1_value? product
        @tw ||= Country.where(:iso_code=>'TW').first
        @tw_tariff_hash ||= {}
        tw_classification = product.classifications.where(:country_id=>@tw.id).first
        return false unless tw_classification
        tw_classification.tariff_records.each do |tr|
          hts_recs = [tr.hts_1,tr.hts_2,tr.hts_3]
          hts_recs.each do |h|
            ot = @tw_tariff_hash[h]
            ot = OfficialTariff.where(:hts_code=>h,:country_id=>@tw.id).first unless ot
            return true if ot && ot.import_regulations.include?("MP1")
          end
        end
        false
      end
      def set_custom_value object, field_label, value
        klass = object.class.to_s
        @defs ||= {}
        if @defs[klass].nil?
          @defs[klass] = CustomDefinition.cached_find_by_module_type klass
        end
        cd = nil
        @defs[klass].each do |d|
          if d.label == field_label
            cd = d
            break
          end
        end
        raise "Custom definition could not be found for label \"#{field_label}\"" if cd.nil?
        cv = object.get_custom_value(cd)
        if cv.value.blank?
          cv.value = value
          cv.save!
        end
      end
    end
  end
end
