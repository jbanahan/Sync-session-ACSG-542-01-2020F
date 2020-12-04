# == Schema Information
#
# Table name: bill_of_lading_containers
#
#  bill_of_lading_id :integer
#  container_id      :integer
#  created_at        :datetime         not null
#  id                :integer          not null, primary key
#  updated_at        :datetime         not null
#

class BillOfLadingContainer < ActiveRecord::Base

  belongs_to :bill_of_lading, inverse_of: :bill_of_lading_containers
  belongs_to :container, inverse_of: :bill_of_lading_containers
end
