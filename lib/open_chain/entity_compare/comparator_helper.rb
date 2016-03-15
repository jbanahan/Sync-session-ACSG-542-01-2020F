module OpenChain; module EntityCompare; module ComparatorHelper

  def get_json_hash bucket, key, version
    # If anything is blank here, return a blank hash.  This occurs most often in the comparators
    # when you're doing a comparison for an object that is brand new and thus has no previous
    # versions.
    json = {}
    if !bucket.blank? && !key.blank? && !version.blank?
      data = OpenChain::S3.get_versioned_data(bucket, key, version)
      json = JSON.parse data unless data.blank?
    end

    json
  end

end; end; end
