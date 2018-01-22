# == Schema Information
#
# Table name: locations
#
#  id           :integer          not null, primary key
#  locode       :string(255)
#  name         :string(255)
#  sub_division :string(255)
#  function     :string(255)
#  status       :string(255)
#  iata         :string(255)
#  coordinates  :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#

class Location < ActiveRecord::Base


end
