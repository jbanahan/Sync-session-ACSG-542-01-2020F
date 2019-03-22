require 'spec_helper'

describe OpenChain::BusinessRulesNotifier do
  subject { described_class }

  let (:slack_client) {
    instance_double(OpenChain::SlackClient)
  }
  let! (:company) {
    Factory(:master_company, show_business_rules:true)
  }

  before(:each) do
    allow(subject).to receive(:slack_client).and_return slack_client
  end

  it "logs all errors" do
    imp1 = Factory(:importer, alliance_customer_number: '12345', slack_channel: 'company1')
    imp2 = Factory(:company, alliance_customer_number: '23456', slack_channel: 'company2')
    Factory(:entry, customer_number:'12345', importer: imp1)
    Factory(:entry, customer_number:'23456', importer: imp2)
    

    bvt1 = generate_business_rule('12345')
    bvt2 = generate_business_rule('23456')

    bvt1.create_results! run_validation: true
    bvt2.create_results! run_validation: true

    expect(slack_client).to receive(:send_message!).ordered.and_raise(StandardError, "Error 1")
    expect(slack_client).to receive(:send_message!).ordered.and_raise(StandardError, "Error 2")


    messages = []
    expect(subject).to receive(:log_error).exactly(2).times do |error, message|
      messages << message
    end

    subject.run_schedulable

    expect(messages.length).to eq 2
    expect(messages.first).to eq "Failed to post to the 'company1' slack channel."
    expect(messages.second).to eq "Failed to post to the 'company2' slack channel."
  end

  it "sends to the company's slack channel" do
    entry = Factory(:entry, customer_number:'12345')
    company = Factory(:company, alliance_customer_number: '12345', slack_channel: 'company1', name: "My Company")
    bvt = generate_business_rule('12345')

    bvt.create_results! run_validation: true

    expect(slack_client).to receive(:send_message!).with(company.slack_channel, "My Company (12345) has 1 failed business rule.")
    OpenChain::BusinessRulesNotifier.run_schedulable
  end

  def generate_business_rule(value)
    bvt = Factory(:business_validation_template)
    bvt.search_criterions.create!(model_field_uid:'ent_cust_num',operator:'eq',value:value)
    bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat', name: 'Name', description: 'Description', rule_attributes_json:{model_field_uid:'ent_entry_num',regex:'X'}.to_json)
    bvt.reload
    bvt
  end
end
