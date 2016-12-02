require 'spec_helper'

describe OpenChain::BusinessRulesNotifier do
  before do
    Factory(:master_company,show_business_rules:true)
    @fake_client = double('Slack::Web::Client')
    allow(OpenChain::SlackClient).to receive(:slack_client).and_return @fake_client
  end

  it 'catches all errors and returns only one error' do
    Factory(:entry, customer_number:'12345')
    Factory(:company, alliance_customer_number: '12345', slack_channel: 'company1')
    Factory(:entry, customer_number:'23456')
    Factory(:company, alliance_customer_number: '23456', slack_channel: 'company2')

    bvt1 = generate_business_rule('12345')
    bvt2 = generate_business_rule('23456')

    bvt1.create_results! true
    bvt2.create_results! true

    expect(@fake_client).to receive(:chat_postMessage).ordered.and_raise("Error 1")
    expect(@fake_client).to receive(:chat_postMessage).ordered.and_raise("Error 2")

    expect { OpenChain::BusinessRulesNotifier.run_schedulable }.to raise_error("Error 1")
  end

  it 'sends to the company\'s slack channel' do
    @entry = Factory(:entry, customer_number:'12345')
    @company = Factory(:company, alliance_customer_number: '12345', slack_channel: 'company1')
    bvt = generate_business_rule('12345')

    bvt.create_results! true

    expected = {as_user: true, channel:@company.slack_channel, text: "DEV MESSAGE: #{@company.name_with_customer_number} has 1 failed business rules"}
    expect(@fake_client).to receive(:chat_postMessage).with(expected)
    OpenChain::BusinessRulesNotifier.run_schedulable
  end

  def generate_business_rule(value)
    bvt = Factory(:business_validation_template)
    bvt.search_criterions.create!(model_field_uid:'ent_cust_num',operator:'eq',value:value)
    bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat',rule_attributes_json:{model_field_uid:'ent_entry_num',regex:'X'}.to_json)
    bvt.reload
    bvt
  end
end
