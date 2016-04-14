module OpenChain; module EntityCompare; module ComparatorHelper

  def get_json_hash bucket, key, version
    # If anything is blank here, return a blank hash.  This occurs most often in the comparators
    # when you're doing a comparison for an object that is brand new and thus has no previous
    # versions.
    json = {}
    if !bucket.blank? && !key.blank? && !version.blank?
      data = OpenChain::S3.get_versioned_data(bucket, key, version)
      json = ActiveSupport::JSON.decode(data) unless data.blank?
    end

    json
  end

  def parse_time time, input_timezone: 'UTC', output_timezone: "America/New_York"
    if !time.blank?
      ActiveSupport::TimeZone[input_timezone].parse(time).in_time_zone(output_timezone)
    else
      nil
    end
  end

end; end; end