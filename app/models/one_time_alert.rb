# == Schema Information
#
# Table name: one_time_alerts
#
#  blind_copy_me                  :boolean
#  created_at                     :datetime         not null
#  email_addresses                :text
#  email_body                     :text
#  email_subject                  :string(255)
#  enabled_date                   :date
#  expire_date                    :date
#  expire_date_last_updated_by_id :integer
#  id                             :integer          not null, primary key
#  inactive                       :boolean          default(FALSE)
#  mailing_list_id                :integer
#  module_type                    :string(255)
#  name                           :string(255)
#  updated_at                     :datetime         not null
#  user_id                        :integer
#

class OneTimeAlert < ActiveRecord::Base
  belongs_to :user
  belongs_to :expire_date_last_updated_by, class_name: "User"
  belongs_to :mailing_list
  has_many :search_criterions, dependent: :destroy, autosave: true
  has_many :log_entries, class_name: "OneTimeAlertLogEntry"

  MODULE_CLASS_NAMES = ["BrokerInvoice", "Entry", "Order", "Product", "Shipment"].sort

  def self.can_view? user
    user.company.master? || user.admin
  end

  def self.can_edit? user
    can_view? user
  end

  def can_view? user
    user == self.user || user.admin?
  end

  def can_edit? user
    self.can_view? user
  end

  def test? obj
    result = false
    self.search_criterions.each do |sc|
      result = sc.test? obj
      break unless result
    end
    result
  end
  
  # obj needs to be saved afterwards
  def trigger obj
    now = Time.zone.now
    obj.sync_records.build(trading_partner: "one_time_alert", sent_at: now, confirmed_at: now + 1.minute, fingerprint: self.id)    
    send_email obj
    log obj, now
  end

  def send_email obj
    body = body_preamble(obj).html_safe + "<p>".html_safe + self.email_body + "</p>".html_safe
    if obj.nil?
      body += "<br><p>THIS IS A TEST EMAIL ONLY AND NOT A NOTIFICATION</p>".html_safe
    end
    bcc = self.user.email if self.blind_copy_me?
    OpenMailer.send_simple_html(recipients_and_mailing_lists, self.email_subject, body, [], bcc: bcc).deliver!
  end

  def recipients_and_mailing_lists
    emails = self.email_addresses

    if mailing_list.present?
      formatted_emails = mailing_list.split_emails.join(', ')
      if emails.present?
        emails << ", #{formatted_emails}"
      else
       emails = formatted_emails
      end
    end
    emails
  end

  def log obj, time
    self.log_entries.create! alertable: obj, logged_at: time, reference_fields: reference_fields
  end
  
  private

  def reference_fields
    fields = []
    self.search_criterions.each do |sc|
      mf = ModelField.find_by_uid(sc.model_field_uid)
      fields << "#{mf.label} #{sc.value}"
    end
    fields.join(", ")
  end

  def body_preamble obj
    notification_string = "#{label(obj)}: #{reference_fields}"
    "<p>A One Time Alert was triggered from VFI Track for #{notification_string}</p>"
  end

  def label obj
    cm = CoreModule.find_by_class_name(self.module_type)
    uid = obj ? cm.unique_id_field.process_export(obj, nil) : "<identifier>"
    "#{cm.label} - #{cm.unique_id_field.label} #{uid}"
  end
end
