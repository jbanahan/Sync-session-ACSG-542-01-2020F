require 'open_chain/entity_compare/multi_class_comparator'

module OpenChain; module EntityCompare; class OneTimeAlertsComparator
  extend OpenChain::EntityCompare::MultiClassComparator.includes("Entry", "Order", "Product", "Shipment")

  def self.compare type, id, _old_bucket, _old_path, _old_version, _new_bucket, _new_path, _new_version
    alerts = OneTimeAlert.where(module_type: type)
                         .where(inactive: [nil, false])
                         .where("expire_date IS NULL OR expire_date >= ?", Time.zone.now.to_date)
    return if alerts.blank?

    obj = type.constantize.where(id: id).first
    return unless obj
    updated = nil
    alerts.each do |a|
      if a.test?(obj) && obj.sync_records.find { |s| s.trading_partner == "one_time_alert" && s.fingerprint == a.id.to_s }.nil?
        a.trigger obj
        updated = true
      end
    end
    obj.save! if updated
  end

end; end; end
