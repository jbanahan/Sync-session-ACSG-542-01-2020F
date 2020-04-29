# == Schema Information
#
# Table name: entry_comments
#
#  body           :text(65535)
#  created_at     :datetime         not null
#  entry_id       :integer
#  generated_at   :datetime
#  id             :integer          not null, primary key
#  public_comment :boolean
#  updated_at     :datetime         not null
#  username       :string(255)
#
# Indexes
#
#  index_entry_comments_on_entry_id  (entry_id)
#

class EntryComment < ActiveRecord::Base
  attr_accessible :body, :created_at, :entry_id, :entry, :generated_at,
    :public_comment, :updated_at, :username

  # Be aware that the entry parsers, for performance reasons, do NOT call destroy_all when reprocessing entry notes,
  # so if ANY dependent destroys are added below, you MUST go back to the entry parser and amend that (or work around it)
  belongs_to :entry, :inverse_of=>:entry_comments
  before_validation :identify_public_comments

  USER_TYPE_MAP ||= {
    'ISF Upload' => 'ISF',
    'KC Abi Send' => 'ABI',
    "ABABIUP6" => 'ABI',
    "ABDUEDAT" => 'ABI',
    "ABISYS" => 'ABI',
    "ABQBLREQ" => 'ABI',
    "ABQSTADL" => 'ABI',
    "KC ABI Send" => 'ABI',
    "CUSTOMS" => 'ABI',
    "KC Email" => 'SYSTEM',
    "KC_KI" => 'SYSTEM',
    "SYSTEM" => 'SYSTEM',
    "PayDueRsnd" => 'SYSTEM',
    "UniversalEvent" => 'ABI',
    "Private Broker" => 'SYSTEM'
  }

  def can_view? user
    entry.can_view?(user) && (public_comment || user.company.broker?)
  end

  def comment_type
    r = USER_TYPE_MAP[self.username]
    r.blank? ? 'USER' : r
  end

  private
    def identify_public_comments
      # Don't run regexes if the flag has been set
      if public_comment.nil?
        self.public_comment = publicly_viewable?(self.body)
      end

      true
    end

    def publicly_viewable? comment
      # If any of the following regex's match, then this entry comment
      # should be private.
      match = [/^Document image created for/i,\
        /^Customer has been changed from/i,\
        /^E\/S Query received - Entry Summary Date updated/i,\
        /^Entry Summary Date Query Sent/i,\
        /^Pay Due not changed, Same Pay Due Date/i,\
        /^Payment Type Changed/i,\
        /^STMNT DATA REPLACED AS REQUESTED/i,\
        /^stmt.*authorized/i].any? {|r| r =~ comment}

      !match
    end
end
