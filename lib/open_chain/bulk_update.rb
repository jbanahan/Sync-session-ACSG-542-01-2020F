require 'open_chain/field_logic'
module OpenChain
  class BulkUpdateClassification

    def self.go_serializable params_json, user_id
      u = User.find user_id
      params = ActiveSupport::JSON.decode params_json
      BulkUpdateClassification.go params, u
    end

    def self.tariff_record_key t
      "#{t.hts_1}~#{t.hts_2}~#{t.hts_3}~#{t.line_number}~#{t.schedule_b_1}~#{t.schedule_b_2}~#{t.schedule_b_3}"
    end
    private_class_method :tariff_record_key

    
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

      first_record = true
      classifications_by_country = {}
      products.each do |p|
        # Since we ONLY want to prefill fields where every product shares the same data, we can build our
        # classification map based off the very first product record and then work forwards from there,
        # subtracting out any tariff or country records that any subsequent products are missing.

        # This should mean we end up looping over far fewer records than the previous algorithm
        # in the general case, and the worst case will mean the same number.
        if first_record
          first_record = false
          p.classifications.each do |c| 
            classifications_by_country[c.country_id] ||= {}
            c.tariff_records.each do |t|
              classifications_by_country[c.country_id][tariff_record_key(t)] = t
            end 
          end

        else
          #If we've removed all the classifications, then we can stop looping
          break if classifications_by_country.size == 0

          classifications_by_country.each do |country_id, tariff_records_hash|
            # If the classification from the first product isn't found in a subsequent product
            # it means it's not common to all products.  Remove it.
            product_classification = p.classifications.find {|c| c.country_id == country_id}
            if product_classification
              tariff_records_hash.each do |key, tariff_record|
                # If the tariff records from the first product aren't found in subsequent products
                # it means they're not common to all products.  Remove it.
                unless product_classification.tariff_records.find {|t| tariff_record_key(t) == key}
                  tariff_records_hash.delete key
                end
              end
            else
              classifications_by_country.delete country_id
            end
          end
        end
      end

      # We've now whittled the data down to only those values that are in common to all records.
      # Add this data to the base_product object.
      classifications_by_country.each do |country_id, tariffs|
        next unless tariffs.size > 0

        classification = base_product.classifications.build(:country_id=>country_id)
        tariffs.each do |key, tr|
          classification.tariff_records.build(hts_1: tr.hts_1, hts_2: tr.hts_2, hts_3: tr.hts_3, 
                                              line_number: tr.line_number, schedule_b_1: tr.schedule_b_1, 
                                              schedule_b_2: tr.schedule_b_2, schedule_b_3: tr.schedule_b_3)
        end
      end

      base_product
    end

    # This method works similar to the standard bulk update, but it DOES NOT delete and recreate 
    # any classification or tariff objects.  It merely takes HTS values from the params and places them into
    # existing products.  It does not clear ANY data from existing products, it is ONLY additive.
    def self.quick_classify params, current_user, options = {}
      
      # This handles the case where we're running from delayed job, ensuring
      # that current user is set. Won't hurt to run from web either.
      User.run_with_user_settings current_user do 
        # This is to support the delay'ed case where we're serializing parameters as json
        # because there's issues with directly marshalling the request params
        if params.is_a? String
          params = ActiveSupport::JSON.decode params
        end

        good_count = nil
        error_count = 0
        total_objects = 0

        # We don't want to modify the actual request params here, so the only way we can really handle that
        # is via a deep_dup (deep clone) operation.
        params = params.deep_dup

        # delete all non classification parameter values, just in case...this method should ONLY update
        # classfication data.
        params.each do |k, v|
          unless ['sr_id', 'pk', 'product'].include? k
            params.delete k
          end

          if k == 'product'
            params[k].each do |class_key, class_value|
              unless class_key == 'classifications_attributes'
                params[k].delete class_key
              end
            end
          end
        end

        log = BulkProcessLog.create! user: current_user, started_at: Time.zone.now, bulk_type: BulkProcessLog::BULK_TYPES[:classify]
        record_sequence = 0
        OpenChain::CoreModuleProcessor.bulk_objects(CoreModule::PRODUCT,params['sr_id'],params['pk']) do |gc, p|
          record_sequence += 1
          begin
            good_count = total_objects = gc if good_count.nil?

            if p.can_classify? current_user
              Product.transaction do 
                # When quick classify is run for a single product, the classification attributes
                # will contain the id of the classification that should be updated.

                # The params here are standard rack/rails query params that may or may not have
                # an id indicating the classification record to update.  If a param for a 
                # classification does not have an id (id's are only present when quick classifying 
                # a single product), then we'll use the country_id to find which
                # classification to append the data to.  If it doesn't exist then we can leave the 
                # parameters alone and they will append a new classification to the product.

                # deep_dup is required because if clone/dup is used the 'classification_attributes' hash will
                # be a reference to the same object for each bulk object iteration
                classification_params = params.deep_dup
                classification_params['product']['classifications_attributes'].each do |index, class_attr|

                  # Because of the way rail's update_attributes method will create new child objects
                  # when no id values are present, we don't have to worry at all about cases where
                  # the classification record isn't present or the tariff record isn't found.
                  # Rails will create those records for us.
                  classification = nil
                  if class_attr['id']
                    id = class_attr['id'].to_i
                    classification = p.classifications.find {|c| c.id == id}
                  else
                    country_id = class_attr['country_id'].to_i
                    classification = p.classifications.find {|c| c.country_id == country_id}

                    if classification
                      class_attr['id'] = classification.id
                    end
                  end

                  # We'll now set the tariff record's id if it's not already set.  We'll use the index value 
                  # as the indicator for which tariff row we're going to update if there is no id value.
                  # This also allows for expansion of the quick classify to support sending multiple tariff lines
                  # should we want to implement that in the future.
                  if classification
                    class_attr['tariff_records_attributes'].each do |index, tariff_attr|

                      unless tariff_attr['id']
                        tariff = classification.tariff_records[index.to_i]
                        if tariff
                          tariff_attr['id'] = tariff.id
                        end
                      end
                    end
                  end
                end

                success = lambda {|o, snapshot| 
                  snapshot.bulk_process_log = log
                  log.change_records.create! recordable: o, record_sequence_number: record_sequence, failed: false, entity_snapshot: snapshot
                }
                failure = lambda {|o,errors|
                  raise OpenChain::ValidationLogicError.new(nil, o)
                }
                before_validate = lambda {|o| OpenChain::CoreModuleProcessor.update_status(o)}

                # Purposefully NOT sending all params to avoid any external processing since we're really ONLY expecting
                # classification values to be set.
                OpenChain::CoreModuleProcessor.validate_and_save_module(nil,p,classification_params['product'],success,failure, before_validate: before_validate, parse_custom_fields: false)
              end
            else
              error_count += 1
              log.change_records.create!(recordable: p, record_sequence_number: record_sequence, failed: true).add_message("You do not have permission to classify product #{p.unique_identifier}.", true).save!
              good_count -= 1
            end
          rescue OpenChain::ValidationLogicError => e
            # This ends up needing to be done outside of the failure lambda due to how that lambda must throw the 
            # logic error to force a rollback.
            o = e.base_object
            good_count -= 1
            cr = log.change_records.create! recordable: o, record_sequence_number: record_sequence, failed: true
            o.errors.full_messages.each do |m| 
              cr.add_message "Error saving product #{o.unique_identifier}: #{m}", true
              error_count += 1
            end
            cr.save!
          end
        end
        log.update_attributes total_object_count: total_objects, changed_object_count: good_count, finished_at: Time.zone.now
        create_bulk_user_message current_user, good_count, error_count, log, options
      end
    end

    def self.go params, current_user, options = {}
      User.current = current_user if User.current.nil? #set this in case we're not in a web environment (like delayed_job)
      good_count = nil
      error_count = 0
      total_objects = nil

      log = BulkProcessLog.create! user: current_user, started_at: Time.zone.now, bulk_type: BulkProcessLog::BULK_TYPES[:update]
      record_sequence = 0
    
      has_classifications = !params['product']['classifications_attributes'].nil?

      # clear all product, classification and tariff attributes that are blank..if they're blank, the user didn't input any
      # value into the fields and they shouldn't update any of values setting them to blank
      params['product'].each do |p_key, p_value|
        if p_key == 'classifications_attributes'
          p_value.each_value do |class_attrs|
            class_attrs.each do |c_key, c_value|
              if c_key == 'tariff_records_attributes'
                c_value.each_value do |tariff_attrs|
                  tariff_attrs.each do |t_key, t_value|
                    tariff_attrs.delete(t_key) if t_value.blank?
                  end
                end
              else
                class_attrs.delete(c_key) if c_value.blank?
              end
            end 
          end
        else
          params['product'].delete(p_key) if p_value.blank?
        end
      end
      # Clearing classification / tariff level custom fields are handled in the classification custom values setter below
      params['product_cf'].each do |id, value|
        params['product_cf'].delete(id) if value.blank?
      end if params['product_cf']

      OpenChain::CoreModuleProcessor.bulk_objects(CoreModule::PRODUCT,params['sr_id'],params['pk']) do |gc, p|
        record_sequence += 1
        good_count = total_objects = gc if good_count.nil?

        begin
          
          if p.can_edit?(current_user) && (!has_classifications || p.can_classify?(current_user))
            dup_params = params.deep_dup
            Product.transaction do
              country_classification_map = {}

              # classification attributes won't be present if the user didn't set any classification or tariff level
              # values on screen.
              if has_classifications

                # Each classifications_attributes is going to have a country id, what we're going to
                # do is find which specific classification record for the product matches that country id
                # and then set that classification back into the dup_params hash.  This will allow the
                # update_attributes call done from the validate_and_save_module to know exactly which 
                # classification / tariff record should be updated.

                dup_params['product']['classifications_attributes'].each do |index, class_attr|
                  country_class = p.classifications.find {|c| c.country_id.to_s == class_attr['country_id']}
                  if country_class
                    class_attr['id'] = country_class.id

                    tariffs = class_attr['tariff_records_attributes']
                    if tariffs
                      # Now we should find which tariff records to update based on the line_number values.
                      # If that value isn't there, we'll fall back to using the display order (ie. attribute index counts).

                      # The keys are the the indexes these records appeared at on screen, so by sorting them
                      # we can process loop through these and process them in the order they appeared on screen.
                      # Which would, baring the line number being manually entered, naturally be the way the users 
                      # would want to also have them be displayed.
                      tariffs.keys.sort.each_with_index do |t_index, x|
                        tariff_attr = tariffs[t_index]
                        tariff_record = nil

                        # If someone actually entered a line number then we'll want to use that value
                        # (creating a new record if that line number didn't already exist).
                        # Otherwise, use the index count as the line # to find the tariff record associated with this classification
                        tariff_attr['line_number'] = (x+1).to_s if tariff_attr['line_number'].blank? 
                        if tariff_attr['line_number']
                          tariff_record = country_class.tariff_records.find {|t| t.line_number == tariff_attr['line_number'].to_i}
                        end

                        if tariff_record
                          tariff_attr['id'] = tariff_record.id
                          # It's possible that if there's no hts/schedule b values the the tariff records won't accept the update attributes
                          # so just make sure we always set the view_sequence otherwise custom values won't get set correctly
                          tariff_record.view_sequence = tariff_attr['view_sequence']
                        end
                      end
                    end
                  end
                end
              end
              success = lambda {|o, snapshot| 
                snapshot.bulk_process_log = log
                log.change_records.create! recordable: o, record_sequence_number: record_sequence, failed: false, entity_snapshot: snapshot
              }

              failure = lambda {|o,errors|
                raise OpenChain::ValidationLogicError.new(nil, o)
              }
              before_validate = lambda {|o| 
                CustomFieldProcessor.new(dup_params).save_classification_custom_fields(o,dup_params['product'])
                OpenChain::CoreModuleProcessor.update_status o
              }
              OpenChain::CoreModuleProcessor.validate_and_save_module(dup_params,p,dup_params['product'],success,failure,:before_validate=>before_validate)
            end
          else
            error_count += 1
            # If the user can't edit the product then that's the reason for the error here, otherwise it's because they can't classify.
            log.change_records.create!(recordable: p, record_sequence_number: record_sequence, failed: true).add_message("You do not have permission to #{p.can_edit?(current_user) ? "classify" : "edit"} product #{p.unique_identifier}.", true).save!
            good_count += -1
          end
        rescue OpenChain::ValidationLogicError => e
          # This ends up needing to be done outside of the failure lambda due to how that lambda must throw the 
          # logic error to force a rollback.
          o = e.base_object
          good_count += -1
          cr = log.change_records.create! recordable: o, record_sequence_number: record_sequence, failed: true
          o.errors.full_messages.each do |m| 
            cr.add_message"Error saving product #{o.unique_identifier}: #{m}", true
            error_count += 1
          end
          cr.save!
        end
      end
      
      log.update_attributes total_object_count: total_objects, changed_object_count: good_count, finished_at: Time.zone.now
      create_bulk_user_message current_user, good_count, error_count, log, options
    end

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
    private_class_method :apply_custom_values_to_object

    def self.create_bulk_user_message current_user, good_count, error_count, bulk_log, options
      title = "#{bulk_log.bulk_type} Job Complete"
      if error_count > 0
        title += " (#{error_count} #{"Error".pluralize(error_count)})" 
      end
      title += "."

      begin
        # Ideally, we use url_for here but it's a real pain to do so outside of a controller/view
        url = "https://#{MasterSetup.get.request_host}/bulk_process_logs/#{bulk_log.id}"
        body = "<p>Your #{bulk_log.bulk_type} job has completed.</p><p>#{good_count} #{"Product".pluralize(good_count)} saved.</p><p>The full update log is available <a href=\"#{url}\">here</a>.</p>"
        current_user.messages.create(:subject=>title, :body=>body)
      end unless options[:no_user_message]

      messages = {}
      messages[:message] = title
      error_messages = []
      bulk_log.change_records.each do |cr|
        if cr.failed
          cr.change_record_messages.each do |m|
            error_messages << m.message
          end
        end
      end
      messages[:errors] = error_messages
      messages[:good_count] = good_count
      messages
    end
    private_class_method :create_bulk_user_message    

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

              # Strip blank custom values
              custom_values = @params['classification_custom'][k.to_s]['classification_cf']
              custom_values.each do |k, v|
                custom_values.delete(k) if v.blank?
              end

              OpenChain::CoreModuleProcessor.update_custom_fields classification, custom_values
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
            # Strip blank custom values
            custom_values = custom_container['tariffrecord_cf']
            custom_values.each do |k, v|
              custom_values.delete(k) if v.blank?
            end

            OpenChain::CoreModuleProcessor.update_custom_fields tr, custom_values
          end
        end
      end
    end
  end
end
