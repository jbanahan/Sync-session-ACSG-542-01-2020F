# == Schema Information
#
# Table name: stitch_queue_items
#
#  id                   :integer          not null, primary key
#  stitch_type          :string(255)
#  stitch_queuable_type :string(255)
#  stitch_queuable_id   :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_stitch_queue_item_by_types_and_id  (stitch_type,stitch_queuable_type,stitch_queuable_id) UNIQUE
#

class StitchQueueItem < ActiveRecord::Base

end
