class InventoryOut < ActiveRecord::Base
  has_many  :piece_sets
end
