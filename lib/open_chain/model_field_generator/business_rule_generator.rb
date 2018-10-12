module OpenChain; module ModelFieldGenerator; module BusinessRuleGenerator
  def make_business_rule_arrays(rank_start,uid_prefix,table_name,module_type)
    return [
      [rank_start,"#{uid_prefix}_rule_state",:rule_state,"Internal Business Rule State",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Internal Business Rule State ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rules_state },
        :qualified_field_name=> <<-SQL, 
           (SELECT state
            FROM business_validation_results bvr
            WHERE bvr.validatable_type = '#{module_type}' AND bvr.validatable_id = #{table_name}.id
            ORDER BY (
              CASE bvr.state
                WHEN 'Fail' THEN 0
                WHEN 'Review' THEN 1
                WHEN 'Pass' THEN 2
                WHEN 'Skipped' THEN 3
                ELSE 4
              END)
            LIMIT 1)
          SQL
        :can_view_lambda=>lambda {|u| u ? u.view_all_business_validation_results? : false},
        :read_only=>true
      }],
      [rank_start+1,"#{uid_prefix}_public_rule_state",:public_rule_state,"Business Rule State",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Business Rule State ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rules_state(include_private: false) },
        :qualified_field_name=> <<-SQL,
           (SELECT state
            FROM business_validation_results bvr
            INNER JOIN business_validation_templates bvt ON bvt.id = bvr.business_validation_template_id
            WHERE bvr.validatable_type = '#{module_type}' AND bvr.validatable_id = #{table_name}.id
               AND (bvt.private = false OR bvt.private IS NULL)
            ORDER BY (
               CASE bvr.state
                 WHEN 'Fail' THEN 0
                 WHEN 'Review' THEN 1
                 WHEN 'Pass' THEN 2
                 WHEN 'Skipped' THEN 3
                 ELSE 4
               END)
             LIMIT 1)
          SQL
        :can_view_lambda=>lambda {|u| u ? u.view_business_validation_results? : false},
        :read_only=>true
      }],
      [rank_start+2,"#{uid_prefix}_failed_business_rules",:failed_business_rules,"Internal Failed Business Rule Names",{:data_type=>:string,

        :import_lambda=>lambda {|o,d| "Internal Failed Business Rule Names ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rules("Fail").join("\n ") },
        :qualified_field_name=> <<-SQL,
            (SELECT GROUP_CONCAT(failed_rule.name ORDER BY failed_rule.name SEPARATOR '\n ')
             FROM business_validation_results failed_bvr
               INNER JOIN business_validation_rules failed_rule ON failed_rule.business_validation_template_id = failed_bvr.business_validation_template_id
               INNER JOIN business_validation_rule_results failed_bvrr ON failed_bvr.id = failed_bvrr.business_validation_result_id AND failed_bvrr.business_validation_rule_id = failed_rule.id AND failed_bvrr.state = 'Fail'
             WHERE failed_bvr.validatable_id = #{table_name}.id AND failed_bvr.validatable_type = '#{module_type}'
             GROUP BY failed_bvr.validatable_id)
          SQL
        :can_view_lambda=>lambda {|u| u ? u.view_all_business_validation_results? : false},
        :read_only=>true
      }],
      [rank_start+3,"#{uid_prefix}_public_failed_business_rules",:public_failed_business_rules,"Failed Business Rule Names",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Failed Business Rule Names ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rules("Fail", include_private: false).join("\n ") },
        :qualified_field_name=> <<-SQL,
            (SELECT GROUP_CONCAT(failed_rule.name ORDER BY failed_rule.name SEPARATOR '\n ')
             FROM business_validation_results failed_bvr
               INNER JOIN business_validation_templates template ON template.id = failed_bvr.business_validation_template_id
               INNER JOIN business_validation_rules failed_rule ON failed_rule.business_validation_template_id = failed_bvr.business_validation_template_id
               INNER JOIN business_validation_rule_results failed_bvrr ON failed_bvr.id = failed_bvrr.business_validation_result_id AND failed_bvrr.business_validation_rule_id = failed_rule.id AND failed_bvrr.state = 'Fail'
             WHERE failed_bvr.validatable_id = #{table_name}.id AND failed_bvr.validatable_type = '#{module_type}'
               AND (template.private = false OR template.private IS NULL)
             GROUP BY failed_bvr.validatable_id)
          SQL
        :can_view_lambda=>lambda {|u| u ? u.view_business_validation_results? : false},
        :read_only=>true
      }],
      [rank_start+4,"#{uid_prefix}_review_business_rules",:review_business_rules,"Internal Review Business Rule Names",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Internal Review Business Rule Names ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rules("Review").join("\n ") },
        :qualified_field_name=> <<-SQL,
            (SELECT GROUP_CONCAT(review_rule.name ORDER BY review_rule.name SEPARATOR '\n ')
             FROM business_validation_results review_bvr
               INNER JOIN business_validation_rules review_rule ON review_rule.business_validation_template_id = review_bvr.business_validation_template_id
               INNER JOIN business_validation_rule_results review_bvrr ON review_bvr.id = review_bvrr.business_validation_result_id AND review_bvrr.business_validation_rule_id = review_rule.id AND review_bvrr.state = 'Review'
             WHERE review_bvr.validatable_id = #{table_name}.id AND review_bvr.validatable_type = '#{module_type}'
             GROUP BY review_bvr.validatable_id)
          SQL
        :can_view_lambda=>lambda {|u| u ? u.view_all_business_validation_results? : false},
        :read_only=>true
      }],
      [rank_start+5,"#{uid_prefix}_public_review_business_rules",:public_review_business_rules,"Review Business Rule Names",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Review Business Rule Names ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rules("Review", include_private: false).join("\n ") },
        :qualified_field_name=> <<-SQL,
            (SELECT GROUP_CONCAT(review_rule.name ORDER BY review_rule.name SEPARATOR '\n ')
             FROM business_validation_results review_bvr
               INNER JOIN business_validation_templates template ON template.id = review_bvr.business_validation_template_id
               INNER JOIN business_validation_rules review_rule ON review_rule.business_validation_template_id = review_bvr.business_validation_template_id
               INNER JOIN business_validation_rule_results review_bvrr ON review_bvr.id = review_bvrr.business_validation_result_id AND review_bvrr.business_validation_rule_id = review_rule.id AND review_bvrr.state = 'Review'
             WHERE review_bvr.validatable_id = #{table_name}.id AND review_bvr.validatable_type = '#{module_type}'
               AND (template.private = false OR template.private IS NULL)
             GROUP BY review_bvr.validatable_id)
          SQL
        :can_view_lambda=>lambda {|u| u ? u.view_business_validation_results? : false},
        :read_only=>true
      }],
      [rank_start+6,"#{uid_prefix}_failed_business_rule_templates",:failed_business_rule_templates,"Internal Failed Business Rule Template Names",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Internal Failed Business Rule Template Names ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rule_templates("Fail").join("\n ") },
        :qualified_field_name=> business_rule_templates_qry(table_name, module_type, "Fail"),
        :can_view_lambda=>lambda {|u| u ? u.view_all_business_validation_results? : false},
        :read_only=>true
      }],
      [rank_start+7,"#{uid_prefix}_public_failed_business_rule_templates",:public_failed_business_rule_templates,"Failed Business Rule Template Names",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Failed Business Rule Template Names ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rule_templates("Fail", include_private: false).join("\n ") },
        :qualified_field_name=> public_business_rule_templates_qry(table_name, module_type, "Fail"),
        :can_view_lambda=>lambda {|u| u ? u.view_business_validation_results? : false},
        :read_only=>true
      }],
      [rank_start+8,"#{uid_prefix}_review_business_rule_templates",:review_business_rule_templates,"Internal Review Business Rule Template Names",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Internal Review Business Rule Template Names ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rule_templates("Review").join("\n ") },
        :qualified_field_name=> business_rule_templates_qry(table_name, module_type, "Review"),
        :can_view_lambda=>lambda {|u| u ? u.view_all_business_validation_results? : false},
        :read_only=>true
      }],
      [rank_start+9,"#{uid_prefix}_public_review_business_rule_templates",:public_review_business_rule_templates,"Review Business Rule Template Names",{:data_type=>:string,
        :import_lambda=>lambda {|o,d| "Failed Business Rule Template Names ignored. (read only)"},
        :export_lambda=>lambda {|obj| obj.business_rule_templates("Review", include_private: false).join("\n ") },
        :qualified_field_name=> public_business_rule_templates_qry(table_name, module_type, "Review"),
        :can_view_lambda=>lambda {|u| u ? u.view_business_validation_results? : false},
        :read_only=>true
      }]
    ]
  end

  def business_rule_templates_qry table_name, module_type, state, additional_where="1=1"
    <<-SQL
      (SELECT GROUP_CONCAT(templates.name ORDER BY templates.name SEPARATOR "\n ")
       FROM business_validation_results results
        INNER JOIN business_validation_templates templates ON templates.id = results.business_validation_template_id AND results.state = "#{state}"
       WHERE results.validatable_id = #{table_name}.id AND results.validatable_type = "#{module_type}"
         AND #{additional_where}
       GROUP BY results.validatable_id)
    SQL
  end

  def public_business_rule_templates_qry table_name, module_type, state
    where = "(templates.private = false OR templates.private IS NULL)"
    business_rule_templates_qry table_name, module_type, state, where
  end
end; end; end
