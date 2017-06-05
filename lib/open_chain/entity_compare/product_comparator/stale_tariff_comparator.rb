require 'open_chain/entity_compare/product_comparator'
require 'open_chain/entity_compare/product_comparator/product_comparator_helper'
require 'open_chain/custom_handler/vfitrack_custom_definition_support'

module OpenChain; module EntityCompare; module ProductComparator; class StaleTariffComparator
  extend OpenChain::EntityCompare::ProductComparator
  include OpenChain::EntityCompare::ProductComparator::ProductComparatorHelper
  include OpenChain::CustomHandler::VfitrackCustomDefinitionSupport

  def self.compare type, id, old_bucket, old_path, old_version, new_bucket, new_path, new_version
    comparator = self.new

    valid_tariffs = comparator.check_for_unstale_tariffs(old_bucket, old_path, old_version, new_bucket, new_path, new_version)
    stale_tariffs = comparator.check_for_stale_tariffs(new_bucket, new_path, new_version)
    
    if valid_tariffs.any? || stale_tariffs.any?
      comparator.update_product id, valid_tariffs, stale_tariffs
    end

  end

  def check_for_unstale_tariffs old_bucket, old_path, old_version, new_bucket, new_path, new_version
    
    new_snap = cached_json(new_bucket, new_path, new_version)
    # See if we have a classification marked as a stale tariff...if so, then check to see the tariff # 
    # for the classification changed since the previous snapshot.  If it did, then see if the new tariff is
    # valid, if so, then mark the classification as not stale.
    stale_cdef = cdefs[:class_stale_classification]

    stale_classifications = []
    json_child_entities(new_snap, "Classification").each do |classification|
      if mf(classification, stale_cdef.model_field_uid)
        stale_classifications << classification
      end
    end

    return {} unless stale_classifications.length > 0

    # If we found any stale classifications, check to see if the hts has been changed.
    changed_classifications = {}

    old_snap = cached_json(old_bucket, old_path, old_version)
    stale_classifications.each do |stale|
      stale_country = mf(stale, "class_cntry_iso")

      # There may be multiple hts numbers for sets
      stale_hts = get_all_hts(stale)

      # the old snapshot could be nil technically if this is a new product, though I'm not sure why
      # you'd be adding a stale tariff to a newly created product
      old_hts = old_snap.nil? ? nil : get_country_tariffs(old_snap, stale_country)

      if stale_hts != old_hts
        changed_classifications[stale_country] = stale_hts
      end

    end

    # So at this point we have a hash of classfication countries and the hts set on them
    #..let's validate them all by checking for official tariffs.  If they're official
    # we can unmark the product's stale classification.
    valid_tariffs = {}

    changed_classifications.each_pair do |country_iso, hts_numbers|
      if hts_numbers.all? {|hts| valid_hts?(country_iso, hts)}
        valid_tariffs[country_iso] = hts_numbers
      end
    end

    valid_tariffs
  end

  def check_for_stale_tariffs new_bucket, new_path, new_version
    new_snap = cached_json(new_bucket, new_path, new_version)

    # Check all the classifications that aren't stale and see if they actually are valid
    stale_cdef = cdefs[:class_stale_classification]

    valid_classifications = []
    json_child_entities(new_snap, "Classification").each do |classification|
      unless mf(classification, stale_cdef.model_field_uid)
        valid_classifications << classification
      end
    end

    return {} unless valid_classifications.length > 0


    # Whereas the code to remove teh stale tariff flag checks for changes, this check is really
    # running to see if an older product might be being changed that currently has a stale tariff.
    # If so, then it will be marked as such.  We prevent bad tariffs from getting into the system via uploads
    # and user interaction, so this is really just a check to flag older products that are being updated.
    stale_classifications = {}
    valid_classifications.each do |classification|
      country_iso = mf(classification, "class_cntry_iso")
      hts = get_all_hts(classification)

      if hts.any? {|hts| !valid_hts?(country_iso, hts)}
        stale_classifications[country_iso] = hts
      end
    end

    stale_classifications
  end

  def update_product id, valid_tariffs, invalid_tariffs
    # We need to be careful here...the product MAY have changed while the job for this comparator has been queued..
    # so ONLY mark the classification as not stale if the tariff for the country is the same as the 
    product = Product.where(id: id).first

    # product could have been deleted since this was queued
    return unless product

    stale_cdef = cdefs[:class_stale_classification]
    Lock.with_lock_retry(product) do
      updated = false

      valid_tariffs.each_pair do |country_iso, hts_numbers|
        classification = product.classifications.find {|c| c.country.iso_code == country_iso}
        next unless classification
        # At this point, just check that the hts numbers we found are the same ones present on the new product.
        # If they aren't it means the product was updated since this job ran...and we can't really do anything here.
        # Another comparator should be queued to handle the updated product.
        current_hts = classification.tariff_records.map {|t| t.hts_1 }

        if current_hts == hts_numbers
          # Nil out the value, rather than making it false, so the field doesn't even appear on the screen.
          classification.find_and_set_custom_value stale_cdef, nil
          updated = true
        end
      end

      invalid_tariffs.each_pair do |country_iso, hts_numbers|
        classification = product.classifications.find {|c| c.country.iso_code == country_iso}
        next unless classification

        # At this point, just check that the hts numbers we found are the same ones present on the new product.
        # If they aren't it means the product was updated since this job ran...and we can't really do anything here.
        # Another comparator should be queued to handle the updated product.
        current_hts = classification.tariff_records.map {|t| t.hts_1 }

        if current_hts == hts_numbers
          # Nil out the value, rather than making it false, so the field doesn't even appear on the screen.
          classification.find_and_set_custom_value stale_cdef, true
          updated = true
        end
      end

      if updated
        product.save!
        product.create_snapshot User.integration, nil, "Stale Tariff Detector"
      end
    end
  end

  def cached_json bucket, path, version
    @json_cache ||= {}

    key = [bucket, path, version]
    json = @json_cache[key]
    if json.nil?
      json = get_json_hash(bucket, path, version)
      @json_cache[key] = json
    end

    json
  end

  def valid_hts? country_iso, hts
    @cache ||= Hash.new do |h, k|
      h[k] = {}
    end

    if @cache[country_iso][hts].nil?
      @cache[country_iso][hts] = OfficialTariff.joins(:country).where(hts_code: hts).where(countries: {iso_code: country_iso}).first.present?
    end

    @cache[country_iso][hts]    
  end

  def cdefs
    @cdefs ||= self.class.prep_custom_definitions([:class_stale_classification])
    @cdefs
  end

end; end; end; end;