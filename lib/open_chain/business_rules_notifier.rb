module OpenChain
  class BusinessRulesNotifier
    def self.run_schedulable
      companies = Company.has_slack_channel

      companies.each do |company|
        rule_fail_count = get_rule_failures_count_for(company)

        if rule_fail_count > 0
          OpenChain::SlackClient.new.send_message!(company.slack_channel, "#{company.name_with_customer_number} has #{rule_fail_count} failed business rules", user: true)
        end
      end
    end

    private

    def self.get_rule_failures_count_for(company)
      customer_number = company.alliance_customer_number || company.fenix_customer_number

      ss = SearchSetup.new(module_type:'Entry',user:User.integration)
      ss.search_criterions.build(model_field_uid:'ent_rule_state',operator:'eq',value:'Fail')
      ss.search_criterions.build(model_field_uid:'ent_cust_num',operator:'eq',value:customer_number)
      SearchQuery.new(ss,User.integration).count
    end
  end
end