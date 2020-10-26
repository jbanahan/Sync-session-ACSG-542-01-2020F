# == Schema Information
#
# Table name: canadian_pga_line_ingredients
#
#  canadian_pga_line_id :integer
#  created_at           :datetime
#  id                   :integer          not null, primary key
#  name                 :string(255)
#  quality              :decimal(13, 4)
#  quantity             :decimal(13, 4)
#  updated_at           :datetime
#

class CanadianPgaLineIngredient < ActiveRecord::Base
  belongs_to :canadian_pga_line

  attr_accessible :canadian_pga_line_id, :name, :quality, :quantity
end
