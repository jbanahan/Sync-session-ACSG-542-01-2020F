require 'open_chain/custom_handler/ann_inc/ann_custom_definition_support'

describe OpenChain::CustomHandler::AnnInc::AnnAuditComparator do
  subject { described_class }

  let (:ann) { FactoryBot(:importer, system_code: "ann") }
  let (:order) { FactoryBot(:order, importer: ann) }
  let (:country) { FactoryBot(:country, iso_code: "US")}
  let (:cdefs) { subject.new.cdefs }

  describe "compare" do
    let (:klass) { OpenChain::CustomHandler::AnnInc::AnnAuditComparator.new }

    it "does not reset docs required, if an audit has been initiated and docs required is already set" do
      allow(Order).to receive(:find).and_return(order)
      order.find_and_set_custom_value(cdefs[:ord_audit_initiated_by], User.integration)
      order.find_and_set_custom_value(cdefs[:ord_audit_initiated_date], Time.zone.now)
      order.find_and_set_custom_value(cdefs[:ord_docs_required], true)
      order.save!

      expect(order).to_not receive(:create_snapshot)
      expect(order).to_not receive(:find_and_set_custom_value)
      klass.compare order.id
    end

    it "sets docs required if an audit has been initiated" do
      allow(Order).to receive(:find).and_return(order)
      order.find_and_set_custom_value(cdefs[:ord_audit_initiated_by], User.integration)
      order.find_and_set_custom_value(cdefs[:ord_audit_initiated_date], Time.zone.now)
      order.save!

      expect(order).to receive(:create_snapshot)
      klass.compare order.id
      order.reload
      expect(order.get_custom_value(cdefs[:ord_docs_required]).value).to be_truthy
    end
  end
end
