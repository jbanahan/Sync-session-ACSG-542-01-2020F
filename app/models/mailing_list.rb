# == Schema Information
#
# Table name: mailing_lists
#
#  company_id        :integer
#  created_at        :datetime         not null
#  email_addresses   :text
#  id                :integer          not null, primary key
#  name              :string(255)
#  non_vfi_addresses :boolean
#  system_code       :string(255)      not null
#  updated_at        :datetime         not null
#  user_id           :integer
#
# Indexes
#
#  index_mailing_lists_on_system_code  (system_code) UNIQUE
#

class MailingList < ActiveRecord::Base
  # This is so we can give a warning on save.
  attr_accessor :non_vfi_email_addresses

  belongs_to :company
  belongs_to :user

  validates :system_code, presence: true
  validates :user, presence: true
  validates :company, presence: true
  validates :name, presence: true
  before_save :validate_email_addresses

  def self.mailing_lists_for_user(user)
    user.company.mailing_lists
  end

  def split_emails
    email_addresses.split(", ")
  end

  def extract_invalid_emails
    self.split_emails.map{ |e| e.strip}.reject{ |e| EmailValidator.valid? e }
  end

  def validate_email_addresses
    if self.email_addresses.present?
      self.email_addresses = self.email_addresses.gsub(/[\r\n]/, "").gsub(/;/, ", ")

      invalid_emails = extract_invalid_emails
      if invalid_emails.present?
        self.errors[:base] << "The following invalid email #{'address'.pluralize(invalid_emails.length)} were found: #{invalid_emails.join(", ")}"
        return false
      end

      addresses = self.split_emails

      addresses_in_system = Set.new(User.where(email: addresses).pluck(:email))
      self.non_vfi_email_addresses = addresses.reject { |email| addresses_in_system.include?(email) }.join(', ')

      self.non_vfi_addresses = self.non_vfi_email_addresses.present?
    end

    return true
  end
end