require 'spec_helper'

describe OpenChain::BusinessRulesNotifier do
  before do
    Factory(:master_company)
    @fake_client = double('Slack::Web::Client')
    OpenChain::SlackClient.stub(:slack_client).and_return @fake_client
    generate_business_rule
  end

  it 'sends to the company\'s slack channel' do
    @entry = Factory(:entry, customer_number:'12345')
    @company = Factory(:company, alliance_customer_number: '12345', slack_channel: 'company1')
    @bvt.create_results! true

    expected = {as_user: true, user: true, channel:@company.slack_channel, text: "DEV MESSAGE: #{@company.name_with_customer_number} has 1 failed business rules"}
    @fake_client.should_receive(:chat_postMessage).with(expected)
    OpenChain::BusinessRulesNotifier.run_schedulable
  end

  def generate_business_rule
    @bvt = Factory(:business_validation_template)
    @bvt.search_criterions.create!(model_field_uid:'ent_cust_num',operator:'eq',value:'12345')
    @bvt.business_validation_rules.create!(type:'ValidationRuleFieldFormat',rule_attributes_json:{model_field_uid:'ent_entry_num',regex:'X'}.to_json)
    @bvt.reload
  end
end