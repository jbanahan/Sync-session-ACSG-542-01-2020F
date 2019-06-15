# == Schema Information
#
# Table name: regions
#
#  created_at :datetime         not null
#  id         :integer          not null, primary key
#  name       :string(255)
#  updated_at :datetime         not null
#

class Region < ActiveRecord::Base
  attr_accessible :name
  has_and_belongs_to_many :countries

  scope :by_name, -> { order(:name, :id) }

  after_destroy :clean_searches
  after_destroy :reload_fields
  after_save :reload_fields

  private
  def clean_searches
    [SearchColumn,SearchCriterion,SortCriterion].each do |k|
      k.where("model_field_uid like '*r_#{self.id}%'").destroy_all
    end
  end

  def reload_fields
    ModelField.reload true
  end
end
