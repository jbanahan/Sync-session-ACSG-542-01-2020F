# == Schema Information
#
# Table name: tariff_sets
#
#  active     :boolean
#  country_id :integer
#  created_at :datetime         not null
#  id         :integer          not null, primary key
#  label      :string(255)
#  updated_at :datetime         not null
#

require 'open_chain/official_tariff_processor/tariff_processor'
class TariffSet < ActiveRecord::Base
  has_many :tariff_set_records, :dependent => :destroy
  belongs_to :country

  # Replaces the OfficialTariffs for this country with the values from this set
  # If a user is provided, the user will receive a system message when the process is complete
  def activate user=nil, log=nil
    Lock.acquire("OfficialTariff-#{self.country.iso_code}") do
      OfficialTariff.where(:country_id=>self.country_id).destroy_all
      self.tariff_set_records.each do |tsr|
        ot = tsr.build_official_tariff
        ot.save!
      end
      OfficialQuota.relink_country(self.country)
      OpenChain::OfficialTariffProcessor::TariffProcessor.process_country(self.country, log)
      TariffSet.where(:country_id=>self.country_id).where("tariff_sets.id = #{self.id} OR tariff_sets.active = ?", true).each do |ts|
        ts.update_attributes(:active=>ts.id==self.id)
      end
    end

    if user
      self.class.delay.notify_user_of_tariff_set_update(self.id, user.id)
    end

    self.class.delay.notify_of_tariff_set_update(self.id)
    nil
  end

  # returns an array where the first element is a collection of TariffSetRecords that have been added
  # the second element is a collection of TariffSetRecords that have been removed
  # and the third element is a hash where the key is the hts_code and the values are the output of TariffSetRecord#compare for records that have changed
  def compare old_tariff_set

    added = self.tariff_set_records.where("hts_code NOT IN (SELECT hts_code FROM tariff_set_records WHERE tariff_set_id = ?)", old_tariff_set.id)
    removed = old_tariff_set.tariff_set_records.where("hts_code NOT IN (SELECT hts_code FROM tariff_set_records WHERE tariff_set_id = ?)", self.id)

    changed = {}
    new_records = self.tariff_set_records.to_a
    old_record_hash = {}
    old_tariff_set.tariff_set_records.each {|tr| old_record_hash[tr.hts_code] = tr}

    new_records.each do |nr|
      o = old_record_hash[nr.hts_code]
      if o
        comparison = nr.compare o
        changed[nr.hts_code] = comparison unless comparison.first.blank?
      end
    end
    [added, removed, changed]
  end

  def self.notify_of_tariff_set_update tariff_set_id
    ts = TariffSet.where(id: tariff_set_id).first
    return if ts.nil?

    User.where(tariff_subscribed:true, disabled: [nil, 0]).each {|u| OpenMailer.send_tariff_set_change_notification(ts, u).deliver_later }
  end

  def self.notify_user_of_tariff_set_update tariff_set_id, user_id
    ts = TariffSet.where(id: tariff_set_id).first
    return if ts.nil?

    user = User.where(id: user_id).first
    return if user.nil?

    user.messages.create(:subject=>"Tariff Set #{ts.label} activated.", :body=>"Tariff Set #{ts.label} has been successfully activated.")
  end

end
