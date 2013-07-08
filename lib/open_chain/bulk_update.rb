require 'open_chain/field_logic'
module OpenChain
  class BulkUpdateClassification

    def self.go_serializable params_json, user_id
      u = User.find user_id
      params = ActiveSupport::JSON.decode params_json
      BulkUpdateClassification.go params, u
    end

    
    # find all of the classifications in the selcted products that have the same country & tariff for all products and build an equivalent classification/tariff in the base product.
    # selected_product can be either an array of product_ids or a SearchRun
    def self.build_common_classifications selected_products, base_product
      products = []
      if selected_products.is_a? SearchRun 
        products = selected_products.all_objects
      elsif selected_products.respond_to? :values
        products = Product.includes(:classifications=>:tariff_records).where("products.id in (?)",selected_products.values)
      else
        products = Product.includes(:classifications=>:tariff_records).where("products.id in (?)",selected_products)
      end
      classifications_by_country = {}
      products.each do |p|
        p.classifications.each do |c| 
          classifications_by_country[c.country_id] ||= []
          classifications_by_country[c.country_id] << c
        end
      end
      classifications_by_country.each do |country_id,classifications|
        if classifications.size == products.size
          tariffs_by_hts_set = {}
          classifications.each do |c|
            c.tariff_records.each do |t|
              hts = "#{t.hts_1}~#{t.hts_2}~#{t.hts_3}~#{t.line_number}"
              tariffs_by_hts_set[hts] ||= []
              tariffs_by_hts_set[hts] << t
            end
          end
          tariffs_by_hts_set.each do |key,tariffs|
            if tariffs.size == products.size
              tr = tariffs.first
              c = base_product.classifications.build(:country_id=>country_id)
              c.tariff_records.build(:hts_1=>tr.hts_1,:hts_2=>tr.hts_2,:hts_3=>tr.hts_3,:line_number=>tr.line_number)
            end
          end
        end
      end
    end

    def self.go params, current_user, options = {}
      User.current = current_user if User.current.nil? #set this in case we're not in a web environment (like delayed_job)
      good_count = nil
      error_messages = []
      error_count = 0
      messages = {}
      OpenChain::CoreModuleProcessor.bulk_objects(CoreModule::PRODUCT,params['sr_id'],params['pk']) do |gc, p|
        begin
          if p.can_classify?(current_user)
            Product.transaction do
              country_classification_map = {}
              good_count = gc if good_count.nil?
              #destroy all classifications for countries passed in the hash, preserving custom values
              params['product']['classifications_attributes'].each do |k,v|
                p.classifications.where(:country_id=>v['country_id']).each do |cls|
                  country_classification_map[cls.country_id] = {:cv=>[],:hts=>{}}
                  cls.custom_values.each {|cv| country_classification_map[cls.country_id][:cv] << cv unless cv.value.blank?}
                  cls.tariff_records.each do |tr|
                    vals = []
                    tr.custom_values.each {|cv| vals << cv unless cv.value.blank?}
                    country_classification_map[cls.country_id][:hts][tr.line_number] = vals
                  end
                  cls.destroy
                end
              end
              success = lambda {|o| }
              failure = lambda {|o,errors|
                good_count += -1
                errors.full_messages.each do |m| 
                  error_messages << "Error saving product #{o.unique_identifier}: #{m}"
                  error_count += 1
                end
                raise OpenChain::ValidationLogicError
              }
              before_validate = lambda {|o| 
                CustomFieldProcessor.new(params).save_classification_custom_fields(o,params['product'])
                o.classifications.each do |cls|
                  ccm = country_classification_map[cls.country_id]
                  if ccm 
                    apply_custom_values_to_object ccm[:cv], cls
                    cls.tariff_records.each_with_index do |tr|
                      apply_custom_values_to_object ccm[:hts][tr.line_number], tr unless ccm[:hts][tr.line_number].blank?
                    end
                  end
                end
                OpenChain::CoreModuleProcessor.update_status o
              }
              OpenChain::CoreModuleProcessor.validate_and_save_module(params,p,params['product'],success,failure,:before_validate=>before_validate)
            end
          else
            error_count += 1
            error_messages << "You do not have permission to classify product #{p.unique_identifier}."
            good_count = gc if good_count.nil?
            good_count += -1
          end
        rescue OpenChain::ValidationLogicError
          #ok to do nothing here
        end
      end
      title = "Classification Job Complete#{error_count>0 ? " ("+error_count.to_s+" Errors)" : ""}."
      begin
        body = "<p>Your classification job has completed.</p><p>Products saved: #{good_count}</p><p>Messages:<br>#{error_messages.join("<br />")}</p>"
        current_user.messages.create(:subject=>title, :body=>body)
      end unless options[:no_user_message]
      
      messages[:message] = title
      messages[:errors] = error_messages
      messages[:good_count] = good_count
      messages
    end
    private
    def self.apply_custom_values_to_object custom_values, obj
      to_write = []
      custom_values.each do |cv|
        new_cv = obj.get_custom_value(cv.custom_definition)
        if new_cv.value.blank? && !cv.value.blank?
          new_cv.value = cv.value
          to_write << new_cv
        end
      end
      CustomValue.batch_write! to_write unless to_write.blank?
      nil
    end
  end

  class BulkInstantClassify
    include ActiveSupport::Inflector 
    def self.go_serializable params_json, current_user_id
      u = User.find current_user_id
      params = ActiveSupport::JSON.decode params_json
      BulkInstantClassify.go params, u
    end
    def self.go params, current_user
      icr = InstantClassificationResult.create(:run_by_id=>current_user.id,:run_at=>0.seconds.ago)
      instant_classifications = InstantClassification.ranked #run this here to avoid calling inside the loop
      OpenChain::CoreModuleProcessor.bulk_objects(CoreModule::PRODUCT,params['sr_id'],params['pk']) do |gc, product|
        result_record = icr.instant_classification_result_records.build(:product_id=>product.id)
        ic_to_use = InstantClassification.find_by_product product, current_user, instant_classifications
        if ic_to_use
          result_record.entity_snapshot = product.create_snapshot(current_user) if product.replace_classifications ic_to_use.classifications.to_a
        end
        result_record.save
      end
      icr.update_attributes(:finished_at=>0.seconds.ago)
      current_user.messages.create(:subject=>"Instant Classification Complete",:body=>"Your instant classification is complete.<br /><br />#{icr.instant_classification_result_records.size} products were inspected.<br />#{icr.instant_classification_result_records.where_changed.count} products were updated.<br /><br />Click <a href='/instant_classification_results/#{icr.id}'>here</a> to see the results.")
    end
  end

  class CustomFieldProcessor
    def initialize p
      @params = p
    end
    def save_classification_custom_fields(product,product_params)
      return if product_params.nil? || product_params['classifications_attributes'].nil? || @params['classification_custom'].nil?
      product.classifications.each do |classification|
        unless classification.destroyed?
          product_params['classifications_attributes'].each do |k,v|
            if v['country_id'] == classification.country_id.to_s
              OpenChain::CoreModuleProcessor.update_custom_fields classification, @params['classification_custom'][k.to_s]['classification_cf']
            end  
          end
        end
        save_tariff_custom_fields(classification)
      end    
    end

    private
    def save_tariff_custom_fields(classification)
      return if @params['tariff_custom'].nil?
      classification.tariff_records.each do |tr|
        unless tr.destroyed?
          vs = tr.view_sequence
          custom_container = @params['tariff_custom'][vs]
          unless custom_container.blank?
            OpenChain::CoreModuleProcessor.update_custom_fields tr, custom_container['tariffrecord_cf']
          end
        end
      end
    end
  end
end
