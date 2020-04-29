module OpenChain; module AwsUtilSupport
  extend ActiveSupport::Concern

  def convert_tag_hash_to_key_value_hash tags
    tags.map {|k, v| {key: k.to_s, value: v.to_s} }
  end

  def convert_tag_hash_to_filters_param tags
    tags.blank? ? [] : tags.map { |k, v| {name: "tag:#{k}", values: Array.wrap(v)} }
  end
end; end