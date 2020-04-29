# == Schema Information
#
# Table name: status_rules
#
#  created_at  :datetime         not null
#  description :string(255)
#  id          :integer          not null, primary key
#  module_type :string(255)
#  name        :string(255)
#  test_rank   :integer
#  updated_at  :datetime         not null
#

class StatusRule < ActiveRecord::Base
  attr_accessible :description, :module_type, :name, :test_rank, :search_criterions_attributes

  has_many :search_criterions, :dependent => :destroy

  # module links (NEVER MAKE THESE :dependent => :destroy)
  has_many :products

  validates :module_type, :presence => true
  validates :name, :presence => true
  validates :test_rank, :presence => true
  validates_uniqueness_of :name, :scope => :module_type
  validates_uniqueness_of :test_rank, :scope => :module_type

  accepts_nested_attributes_for :search_criterions, :allow_destroy => true,
    :reject_if => lambda { |a|
      r_val = false
      [:model_field_uid, :operator, :value].each { |f|
        r_val = true if a[f].blank?
      }
      r_val
  }

  def locked?
    false
  end
end
