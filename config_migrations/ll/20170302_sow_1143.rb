require 'open_chain/custom_handler/lumber_liquidators/lumber_custom_definition_helper'
class SOW1143
  def up
    create_companies
    update_orders
  end

  def create_companies
    [
      {name:"LL Global Sourcing - EU", system_code: "GS-EU", vendor_codes: ["0000100326", "0000200910", "0000300100", "0000100236", "0000300180", "0000300211", "0000300210", "0000300168"]},
      {name:"LL Global Sourcing - US", system_code: "GS-US", vendor_codes: ["0000300118", "0000200996", "0000203938", "0000300051", "0000206880", "0000600000", "0000300046", "0000205429", "0000206291", "0000205389", "0000201875", "0000205300", "0000300045", "0000206825", "0000300140", "0000206236", "0000300130", "0000300108", "0000300053", "0000203874", "0000300060", "0000206601", "0000204846", "0000206870", "0000204314", "0000300212", "0000300155", "0000205731", "0000206865", "0000200337", "0000203928", "0000202945", "0000204840", "0000203302", "0000200696", "0000300146", "0000206886", "0000300052", "0000200226", "0000206681", "0000300121", "0000100091", "0000202713", "0000202765", "0000300026", "0000206850", "0000206845", "0000200435", "0000204036", "0000201814", "0000200631", "0000203260", "0000300050", "0000206860", "0000202029", "0000204995"]},
      {name:"LL Global Sourcing - CA", system_code: "GS-CA", vendor_codes: ["0000300010", "0000206847", "0000100035", "0000100161"]}
    ].each do |c|
      comp = Company.where(system_code:c[:system_code]).first_or_create!(name:c[:name])
      comp.linked_companies.clear # in case this is the second run
      Company.where("system_code IN (?)", c[:vendor_codes]).each {|v| comp.linked_companies << v}
    end
  end

  def update_orders
    u = User.integration
    cd = OpenChain::CustomHandler::LumberLiquidators::LumberCustomDefinitionHelper.prep_custom_definitions([:ord_assigned_agent])[:ord_assigned_agent]
    where = "orders.id in (select ord.id from orders ord inner join custom_values cv on cv.custom_definition_id = #{cd.id} and cv.customizable_type = 'Order' and cv.customizable_id = ord.id WHERE cv.string_value is null OR cv.string_value = '')"
    Order.where(where).each do |ord|
      agent = assigned_agent(ord)
      if !agent.blank?
        ord.update_custom_value!(cd, agent)
        ord.save!
        ord.create_snapshot u, nil, "SOW 1143, update agent."
      end
    end
  end

  def assigned_agent order
    linked_system_codes = Company.where("companies.id IN (SELECT parent_id FROM linked_companies WHERE child_id = ?)", order.vendor_id).pluck(:system_code)
    agent_codes = ['GELOWELL', 'RO', 'GS-EU', 'GS-US', 'GS-CA'] & linked_system_codes
    agent_codes.sort.join("/")
  end
end
