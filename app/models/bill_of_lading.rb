# == Schema Information
#
# Table name: bill_of_ladings
#
#  bill_number       :string(255)
#  bill_of_lading_id :integer
#  bill_type         :string(255)
#  created_at        :datetime         not null
#  entry_id          :integer
#  id                :integer          not null, primary key
#  updated_at        :datetime         not null
#

class BillOfLading < ActiveRecord::Base

  # Self join allows linking of house bills to master bills
  has_many :bill_of_ladings
  belongs_to :bill_of_lading
  belongs_to :entry
  has_many :bill_of_lading_containers, dependent: :destroy
  has_many :containers, through: :bill_of_lading_containers

end
