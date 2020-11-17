# == Schema Information
#
# Table name: sort_criterions
#
#  created_at           :datetime         not null
#  custom_definition_id :integer
#  descending           :boolean
#  id                   :integer          not null, primary key
#  model_field_uid      :string(255)
#  rank                 :integer
#  search_setup_id      :integer
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_sort_criterions_on_search_setup_id  (search_setup_id)
#

class SortCriterion < ActiveRecord::Base
  include HoldsCustomDefinition
  include JoinSupport

  belongs_to :search_setup

  validates :model_field_uid, :presence => true

  def apply(p, module_chain=nil)
    p = p.where("1=1") if p.class.to_s == "Class"
    if module_chain.nil?
      set_module_chain p
    else
      @module_chain = module_chain
    end
    add_sort(add_join(p))
  end

  private
  def add_sort p
    mf = find_model_field
    return p if mf.blank?

    p.order("#{mf.qualified_field_name} #{self.descending ? "DESC" : "ASC"}")
  end
end
