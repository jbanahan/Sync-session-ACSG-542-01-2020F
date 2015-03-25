class EntryComment < ActiveRecord::Base
  belongs_to :entry, :inverse_of=>:entry_comments
  before_save :identify_public_comments
 
  def can_view? user
    entry.can_view?(user) && (public_comment || user.company.broker?)
  end

  private 
    def identify_public_comments
      # Don't run regexes if the flag has been set
      return false unless public_comment.nil?

      self.public_comment = publicly_viewable?(self.body)
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
        /^stmt.*authorized/i].any?{|r| r =~ comment}

      !match
    end
end
