module OpenChain; module ModelFieldGenerator; module BusinessRuleGenerator
  def make_business_rule_arrays(rank_start,uid_prefix,table_name,module_type)
    return [
      [rank_start,"#{uid_prefix}_rule_state",:rule_state,"Business Rule State",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Business Rule State ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rules_state },
        :qualified_field_name=> "(select state
          from business_validation_results bvr
          where bvr.validatable_type = '#{module_type}' and bvr.validatable_id = #{table_name}.id
          order by (
          case bvr.state
              when 'Fail' then 0
              when 'Review' then 1
              when 'Pass' then 2
              when 'Skipped' then 3
              else 4
          end
          )
          limit 1)",
        :can_view_lambda=>lambda {|u| u ? u.view_business_validation_results? : false}
      }],
      [rank_start+1,"#{uid_prefix}_failed_business_rules",:failed_business_rules,"Failed Business Rule Names",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Failed Business Rule Names ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.failed_business_rules.join("\n ") },
        :qualified_field_name=> "(SELECT GROUP_CONCAT(failed_rule.name ORDER BY failed_rule.name SEPARATOR '\n ')
          FROM business_validation_results failed_bvr
          INNER JOIN business_validation_rules failed_rule ON failed_rule.business_validation_template_id = failed_bvr.business_validation_template_id
          INNER JOIN business_validation_rule_results failed_bvrr ON failed_bvr.id = failed_bvrr.business_validation_result_id AND failed_bvrr.business_validation_rule_id = failed_rule.id AND failed_bvrr.state = 'Fail'
          WHERE failed_bvr.validatable_id = #{table_name}.id AND failed_bvr.validatable_type = '#{module_type}'
          GROUP BY failed_bvr.validatable_id)",
        :can_view_lambda=>lambda {|u| u ? u.view_business_validation_results? : false}
      }],
      [rank_start+2,"#{uid_prefix}_review_business_rules",:review_business_rules,"Review Business Rule Names",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Failed Business Rule Names ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.review_business_rules.join("\n ") },
        :qualified_field_name=> "(SELECT GROUP_CONCAT(review_rule.name ORDER BY review_rule.name SEPARATOR '\n ')
          FROM business_validation_results review_bvr
          INNER JOIN business_validation_rules review_rule ON review_rule.business_validation_template_id = review_bvr.business_validation_template_id
          INNER JOIN business_validation_rule_results review_bvrr ON review_bvr.id = review_bvrr.business_validation_result_id AND review_bvrr.business_validation_rule_id = review_rule.id AND review_bvrr.state = 'Review'
          WHERE review_bvr.validatable_id = #{table_name}.id AND review_bvr.validatable_type = '#{module_type}'
          GROUP BY review_bvr.validatable_id)",
        :can_view_lambda=>lambda {|u| u ? u.view_business_validation_results? : false}
      }]
    ]
  end
end; end; end
