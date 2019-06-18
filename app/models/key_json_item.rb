# == Schema Information
#
# Table name: key_json_items
#
#  id          :integer          not null, primary key
#  json_data   :text(65535)
#  key_scope   :string(255)
#  logical_key :string(255)
#
# Indexes
#
#  scoped_logical_keys  (key_scope,logical_key) UNIQUE
#

# Stores JSON data keyed against the key_scope & logical_key fields
#
# `key_scope` must be the same for all entries serving the same purpose
# `logical_key` must be unique within the `key_scope`
# `json_data` must be JSON (use the `data` accessor helps with the conversion)
#
# For example, you might have 2 entries like with key_scope = car like
# `logical_key: 'audi', json_data: {'country':'germany','price_level':'mid'}`
# `logical_key: 'ferrari', json_data: {'country':'italy','price_level':'high'}`
#
# `json_data` is a TEXT field so it's limited by MYSQL max_allowed_packet size
class KeyJsonItem < ActiveRecord::Base
  attr_accessible :json_data, :key_scope, :logical_key

  validates :key_scope, :json_data, :logical_key, :presence=>true

  # Land's End Drawback Certificiate of Delivery data
  KS_LANDS_END_CD ||= 'le_cd'
  # Polo Fiber Report Date
  RL_FIBER_REPORT ||= 'rl_fiber'
  # Entry Data Request Time
  KEWILL_ENTRY_DATA ||= 'kc_entry'
  # US CUSTOMS PERIODIC MONTHLY DATES (logical key is the year, data is month => day)
  PERIODIC_MONTHLY_DATES ||= 'usc_periodic_dates'
  # Siemens Billing File Counter
  SIEMENS_BILLING_FILE_COUNTER ||= 'siemens_billing'
  POLLING_JOB ||= "polling_job"
  ENTRY_DOCUMENT_COUNTS ||= "ent_doc_count"
  ISF_CI_LOAD_CONFIG ||= "isf_config"
  SHIPMENT_SETTINGS ||= "shipment_settings"


  # turn the object into a json string and store it in the json_data field
  def data= d
    self.json_data = d.to_json
  end

  # retrieve the object from the json_data field and parse from JSON
  def data
    return nil if self.json_data.blank?
    JSON.parse self.json_data
  end

  scope :lands_end_cd, lambda {|logical_key| where(:key_scope=>KS_LANDS_END_CD, :logical_key=>logical_key)}
  scope :polo_fiber_report, lambda {|logical_key| where(:key_scope=>RL_FIBER_REPORT, :logical_key=>logical_key)}
  scope :updated_entry_data, lambda {|logical_key| where(:key_scope=>KEWILL_ENTRY_DATA, :logical_key=>logical_key)}
  scope :usc_periodic_dates, lambda {|logical_key| where(:key_scope=>PERIODIC_MONTHLY_DATES, :logical_key=>logical_key)}
  scope :siemens_billing, lambda {|logical_key| where(:key_scope=>SIEMENS_BILLING_FILE_COUNTER, :logical_key=>logical_key)}
  scope :polling_job, lambda {|logical_key| where(:key_scope=>POLLING_JOB, :logical_key=>logical_key)}
  scope :entry_document_counts, lambda {|logical_key| where(key_scope: ENTRY_DOCUMENT_COUNTS, logical_key: logical_key) }
  scope :isf_config, lambda {|logical_key| where(key_scope: ISF_CI_LOAD_CONFIG, logical_key: logical_key) }
  scope :shipment_settings, lambda {|logical_key| where(key_scope: SHIPMENT_SETTINGS, logical_key: logical_key)}
end
