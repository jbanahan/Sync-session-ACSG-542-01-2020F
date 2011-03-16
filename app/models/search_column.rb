class SearchColumn < ActiveRecord::Base
  include HoldsCustomDefinition
  belongs_to :search_setup
end
