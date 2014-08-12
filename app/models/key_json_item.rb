# Stores JSON data keyed against the key_scope & logical_key fields
#
# `key_scope` must be the same for all entries serving the same purpose
# `logical_key` must be unique within the `key_scope`
# `json_data` must be JSON (use the `data` accessor helps with the conversion)
#
# For example, you might have 2 entries like with key_scope = car like
# `logical_key: 'audi', json_data: {'country':'germany','price_level':'mid'`
# `logical_key: 'ferrari', json_data: {'country':'italy','price_level':'high'`
#
# `json_data` is a TEXT field so it's limited by MYSQL max_allowed_packet size
class KeyJsonItem < ActiveRecord::Base
  attr_accessible :json_data, :key_scope, :logical_key

  validates :key_scope, :json_data, :logical_key, :presence=>true

  # Land's End Drawback Certificiate of Delivery data
  KS_LANDS_END_CD ||= 'le_cd'
  # Polo Fiber Report Date
  RL_FIBER_REPORT ||= 'rl_fiber'

  # turn the object into a json string and store it in the json_data field
  def data= d
    self.json_data = d.to_json
  end

  # retrieve the object from the json_data field and parse from JSON
  def data
    return nil if self.json_data.blank?
    JSON.parse self.json_data
  end

  scope :lands_end_cd, lambda {|logical_key| where(:key_scope=>KS_LANDS_END_CD).where(:logical_key=>logical_key)}
  scope :polo_fiber_report, lambda {|logical_key| where(:key_scope=>RL_FIBER_REPORT).where(:logical_key=>logical_key)}
end
