# == Schema Information
#
# Table name: entry_exceptions
#
#  code                    :string(255)      not null
#  comments                :text(65535)
#  created_at              :datetime
#  entry_id                :integer          not null
#  exception_creation_date :datetime
#  id                      :integer          not null, primary key
#  resolved_date           :datetime
#  updated_at              :datetime
#
# Indexes
#
#  index_entry_exceptions_on_entry_id  (entry_id)
#

class EntryException < ActiveRecord::Base
  attr_accessible :code, :comments, :resolved_date, :exception_creation_date

  belongs_to :entry, inverse_of: :entry_exceptions

  def resolved?
    self.resolved_date.present?
  end
end
