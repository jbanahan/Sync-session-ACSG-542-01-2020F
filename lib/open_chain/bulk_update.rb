require 'open_chain/field_logic'
module OpenChain
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
  class BulkUpdateClassification

    def self.go_serializable params_json, user_id
      u = User.find user_id
      params = ActiveSupport::JSON.decode params_json
      BulkUpdateClassification.go params, u
    end
    def self.go params, current_user
      good_count = nil
      msgs = []
      error_count = 0
      OpenChain::CoreModuleProcessor.bulk_objects(params['sr_id'],params['pk']) do |gc, p|
        begin
          if p.can_classify?(current_user)
            Product.transaction do
              good_count = gc if good_count.nil?
              #reset classifications
              p.classifications.destroy_all
              success = lambda {|o| }
              failure = lambda {|o,errors|
                good_count += -1
                errors.full_messages.each do |m| 
                  msgs << "Error saving product #{o.unique_identifier}: #{m}"
                  error_count += 1
                end
                raise OpenChain::ValidationLogicError
              }
              before_validate = lambda {|o| 
                CustomFieldProcessor.new(params).save_classification_custom_fields(o,params['product'])
                OpenChain::CoreModuleProcessor.update_status o
              }
              OpenChain::CoreModuleProcessor.validate_and_save_module(p,params['product'],success,failure,:before_validate=>before_validate)
            end
          else
            error_count += 1
            msgs << "You do not have permission to classify product #{p.unique_identifier}."
            good_count += -1
          end
        rescue OpenChain::ValidationLogicError
          #ok to do nothing here
        end
      end
      body = "<p>Your classification job has completed.</p><p>Products saved: #{good_count}</p><p>Messages:<br>#{msgs.join("<br />")}</p>"
      current_user.messages.create(:subject=>"Classification Job Complete #{error_count>0 ? "("+error_count.to_s+" Errors)" : ""}", :body=>body)
      good_count
    end
  end
end
