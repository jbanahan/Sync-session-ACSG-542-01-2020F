# == Schema Information
#
# Table name: locations
#
#  coordinates  :string(255)
#  created_at   :datetime         not null
#  function     :string(255)
#  iata         :string(255)
#  id           :integer          not null, primary key
#  locode       :string(255)
#  name         :string(255)
#  status       :string(255)
#  sub_division :string(255)
#  updated_at   :datetime         not null
#

class Location < ActiveRecord::Base
  attr_accessible :coordinates, :function, :iata, :locode, :name, :status, :sub_division

end
