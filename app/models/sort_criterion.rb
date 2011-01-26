class SortCriterion < ActiveRecord::Base
  include HoldsCustomDefinition
  
  belongs_to :search_setup
  
  validates :model_field_uid, :presence => true
  
  def apply(p)
    mf = ModelField.find_by_uid self.model_field_uid
    p = p.joins(mf.join_statement) unless mf.join_statement.nil?
    p.order("#{mf.join_alias}.#{mf.field_name} #{self.descending? ? "DESC" : "ASC"}")
  end
  
end
