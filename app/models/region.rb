class Region < ActiveRecord::Base
  attr_accessible :name
  has_and_belongs_to_many :countries

  default_scope :order=>"name ASC, id ASC"

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
