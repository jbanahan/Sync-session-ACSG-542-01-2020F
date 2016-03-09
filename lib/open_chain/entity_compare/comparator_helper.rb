module OpenChain; module EntityCompare; module ComparatorHelper

  def get_json_hash bucket, key, version
    data = OpenChain::S3.get_versioned_data(bucket, key, version)
    return nil if data.blank?
    JSON.parse data
  end

end; end; end
