class Email < ActiveRecord::Base
  attr_accessible :body_text, :json_content, :mailbox_id, :mime_content, :subject, :from, :assigned_to_id
  belongs_to :mailbox, :touch=>true, :inverse_of=>:emails
  belongs_to :email_linkable, :polymorphic=>true, :inverse_of=>:emails
  belongs_to :assigned_to, :inverse_of=>:assigned_emails, :class_name=>"User"
  has_many :attachments, :as=>:attachable, :dependent=>:destroy

  def self.create_from_postmark_json! json
    j = JSON.parse json
    stripped_j = j.clone
    stripped_j.delete 'Attachments'
    e = nil
    Email.transaction do |t|
      e = Email.create!(:subject=>j['Subject'],
        :body_text=>j['TextBody'],
        :from=>j['From'],
        :json_content=>stripped_j.to_json
      )
      if j["Attachments"]
        j["Attachments"].each do |att_hash|
          next if att_hash["Content"].blank?
          io = StringIO.new(Base64.decode64(att_hash["Content"]))
          io.class.class_eval { attr_accessor :original_filename, :content_type }
          io.original_filename = att_hash["Name"]
          io.content_type = att_hash["ContentType"]
          e.attachments.create!(:attached=>io)
        end
      end
    end
    e
  end

  #return a santized html string that is already marked html_safe
  #will return plain body text wrapped in a "pre" tag if no html available
  def safe_html 
    r = "<pre>\n[empty]\n</pre>"
    if self.json_content
      j = JSON.parse self.json_content
      h = j["HtmlBody"]
      if h
        r = h
      else
        r = "<pre>\n#{j["TextBody"]}\n</pre>" 
      end
    elsif !self.body_text.blank?
      r = "<pre>\n#{self.body_text}\n</pre>"
    end
    r.html_safe
  end

  def can_view? user
    return true if user.sys_admin?
    return true if self.mailbox && self.mailbox.can_view?(user)
    return true if self.email_linkable && self.email_linkable.can_view?(user)
    return true if !self.mailbox && !self.email_linkable && user.view_unfiled_emails?
    false
  end

  def can_edit? user
    return true if user.sys_admin?
    return true if self.mailbox && self.mailbox.can_edit?(user)
    return true if !self.mailbox && user.edit_unfiled_emails?
    false
  end

  def can_attach? user
    false
  end
end
