class SyncRecord < ActiveRecord::Base
   belongs_to :syncable, :polymorphic => true
   validates :trading_partner, :presence=>true
   validates :syncable_id, :presence=>true
   validates :syncable_type, :presence=>true
end
