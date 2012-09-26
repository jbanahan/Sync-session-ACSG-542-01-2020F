class EntryComment < ActiveRecord::Base
  belongs_to :entry, :inverse_of=>:entry_comments
end
