# == Schema Information
#
# Table name: search_table_configs
#
#  company_id  :integer
#  config_json :text
#  created_at  :datetime         not null
#  id          :integer          not null, primary key
#  name        :string(255)
#  page_uid    :string(255)
#  updated_at  :datetime         not null
#  user_id     :integer
#
# Indexes
#
#  index_search_table_configs_on_company_id  (company_id)
#  index_search_table_configs_on_page_uid    (page_uid)
#  index_search_table_configs_on_user_id     (user_id)
#

class SearchTableConfig < ActiveRecord::Base
  # user and company are optional
  belongs_to :user
  belongs_to :company

  validates :name, presence: true
  validates :page_uid, presence: true

  def self.for_user user, page_uid
    self.
      where(page_uid:page_uid).
      where("search_table_configs.user_id IS NULL OR search_table_configs.user_id = ?",user.id).
      where("search_table_configs.company_id IS NULL OR search_table_configs.company_id = ?",user.company_id)
  end

  def config_hash
    return {} if self.config_json.blank?
    return JSON.parse(self.config_json)
  end
  def config_hash= h
    self.config_json = nil if h.nil?
    self.config_json = h.to_json
  end
end
