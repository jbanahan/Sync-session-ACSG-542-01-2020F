class InventoryIn < ActiveRecord::Base
  
  has_many  :piece_sets 
  
end
