class QuickSearchController < ApplicationController
  
  def show
    if params[:v].blank?
      error_redirect "You must enter a search value." 
      return
    end
    @value = params[:v].strip
    @available_modules = core_modules_with_quicksearch_fields(current_user)
  end

  def by_module
    limit_fields = params[:limit_fields] && params[:limit_fields].split(",").map(&:to_sym)
    hide_attachments = params[:hide_attachments] == "true"
    hide_business_rules = params[:hide_business_rules] == "true"
    override_extra_fields = params[:override_extra_fields]&.split(",")
    
    cm = CoreModule.find_by_class_name(params[:module_type])
    raise ActionController::RoutingError.new('Not Found') unless cm && cm.view?(current_user)
    return error_redirect("Parameter v is required.") if params[:v].blank?
    r = {module_type: cm.class_name, 
         adv_search_path: "#{cm.class_name.pluralize.underscore}/?force_search=true",
         fields:{}, vals:[], extra_fields: {}, extra_vals: {},  attachments: {}, business_validation_results: {},
         search_term:ActiveSupport::Inflector.transliterate(params[:v].to_s.strip)}
    with_fields_to_use(cm,current_user,override_extra_fields: override_extra_fields) do |field_defs, extra_field_defs|

      primary_search_clause = nil
      or_clause_array = []
      
      primary_additional_core_modules = []
      secondary_additional_core_modules = []
      uids = []
      extra_uids = []
      
      field_defs.each_with_index do |field_def, x|
        mf = ModelField.find_by_uid(field_def[:model_field_uid])
        uids << mf.uid
        r[:fields][mf.uid] = mf.label
        next if limit_fields && !limit_fields.include?(field_def[:model_field_uid])

        sc = SearchCriterion.new(model_field_uid:mf.uid.to_s, operator:'co', value: r[:search_term])
        value = sc.where_value
        clause = ActiveRecord::Base.send(:sanitize_sql_array, ["(#{sc.where_clause(value)})", value])

        if x == 0
          primary_search_clause = clause
          primary_additional_core_modules.push(*field_def[:joins]) if field_def[:joins]
        else
          or_clause_array << clause
          secondary_additional_core_modules.push(*field_def[:joins]) if field_def[:joins]
        end
      end

      extra_field_defs.each do |extra_field_def|
        mf = ModelField.find_by_uid(extra_field_def[:model_field_uid])
        extra_uids << mf.uid
        r[:extra_fields][mf.uid] = mf.label
      end

      distribute_reads do 
        if primary_search_clause
          results = build_relations(cm, current_user, [primary_search_clause], primary_additional_core_modules).limit(10)
          parse_query_results results, r, cm, current_user, uids, extra_uids, hide_attachments: hide_attachments, hide_business_rules: hide_business_rules
        end

        if r[:vals].length < 10 && or_clause_array.length > 0
          results = build_relations(cm, current_user, [or_clause_array], secondary_additional_core_modules, r[:vals]).limit(10 - r[:vals].length)
          parse_query_results results, r, cm, current_user, uids, extra_uids, hide_attachments: hide_attachments, hide_business_rules: hide_business_rules
        end
      end
      
    end

    render json: {qs_result:r}
  end

  private
    def with_fields_to_use core_module, user, override_extra_fields:nil
      @@custom_def_reset ||= nil
      @@qs_field_cache ||= {}
      @@qs_extra_field_cache ||= {}
      if @@custom_def_reset.nil? || CustomDefinition.last.pluck(:updated_at) > @@custom_def_reset
        @@qs_field_cache = {}
        with_core_module_fields(user, override_extra_fields: override_extra_fields) do |cm, fields, extra_fields|
          @@qs_field_cache[cm] = fields.collect {|f| field_definition f}
          @@qs_extra_field_cache[cm] = extra_fields.collect {|f| field_definition f}
        end

        cds = CustomDefinition.where(quick_searchable:true)
        cds.each do |cd|
          field_array = @@qs_field_cache[cd.core_module]
          field_array << field_definition(cd.model_field.uid) if field_array
        end
      end
      if @@qs_field_cache[core_module]
        yield @@qs_field_cache[core_module], @@qs_extra_field_cache[core_module]
      else
        yield []
      end
      return nil
    end

    def get_worst_business_state business_validations
      r = nil
      business_validations.each do |bvr|
        r = BusinessValidationResult.worst_state r, bvr.state
      end
      business_validations.find{|x| x[:state] == r}
    end

    def parse_query_results results, r, core_module, user, uids, extra_uids, hide_attachments:false, hide_business_rules:false
      results.each do |obj|
        obj_hash = {
          id:obj.id,
          view_url: instance_exec(obj, &core_module.view_path_proc)
        }
        extra_obj_hash = {}
        uids.each {|uid| obj_hash[uid] = ModelField.find_by_uid(uid).process_export(obj,user)}
        extra_uids.each {|extra_uid| extra_obj_hash[extra_uid] = ModelField.find_by_uid(extra_uid).process_export(obj,user)}
        r[:vals] << obj_hash
        r[:extra_vals][obj.id] = extra_obj_hash

        if obj.respond_to?(:attachments) && !hide_attachments
          r[:attachments][obj.id] = obj.attachments.select{|a| a.can_view?(user) }.map {|a| 
            att_returned = Attachment.attachment_json a
            att_returned[:download_link] = download_attachment_path a
            att_returned[:content_type] = a.attached_content_type
            att_returned
          }
        end

        if obj.respond_to?(:business_validation_results) && !hide_business_rules
          viewable_rules = obj.business_validation_results.select{ |r| r.can_view?(user)}
          if viewable_rules.length > 0
            worst_viewable_rule = get_worst_business_state viewable_rules
            validation = BusinessValidationResult.business_validation_json worst_viewable_rule
            method_name = "validation_results_#{obj.class.name.underscore}_path"
            validation[:validation_link] = self.send(method_name, obj) if self.respond_to?(method_name)
            r[:business_validation_results][obj.id] = validation
          end
        end
      end
      r
    end

    def build_relations core_module, user, clause_array, additional_parent_core_modules_required = nil, previous_results = nil
      relation = core_module.quicksearch_lambda.call(user, core_module.klass).where(clause_array.join(' OR '))
      if additional_parent_core_modules_required
        joins = additional_parent_core_modules_required.compact.uniq
        
        joins.each do |cm|
          if cm.is_a?(Symbol) || cm.is_a?(String)
            relation = relation.joins(cm)
          else
            raise "Invalid quicksearch field join clause specified."
          end
        end
      end

      if previous_results && previous_results.length > 0
        relation = relation.where(ActiveRecord::Base.sanitize_sql_array(["#{ActiveRecord::Base.connection.quote_table_name(core_module.table_name)}.id NOT IN (?)", previous_results.map {|r| r[:id]}]))
      end

      sort_by = core_module.quicksearch_sort_by
      relation.order("#{sort_by} DESC")
    end

    def field_definition qs
      if qs.respond_to?(:to_h)
        qs.to_h
      else
        {model_field_uid: qs}
      end
    end

    def with_core_module_fields user, override_extra_fields:nil
      CoreModule.all.each do |cm|
        next unless cm.enabled? && cm.view?(user)
        fields = cm.quicksearch_fields
        extra_fields = override_extra_fields&.map(&:to_sym) || cm.quicksearch_extra_fields || {}
        next if fields.nil?
        yield cm, fields, extra_fields
      end
    end

    def core_modules_with_quicksearch_fields user
      ordered_core_modules = [CoreModule::PRODUCT, CoreModule::ORDER, CoreModule::SHIPMENT, CoreModule::SECURITY_FILING, CoreModule::ENTRY,
                              CoreModule::BROKER_INVOICE, CoreModule::CUSTOMS_MONTHLY_STATEMENT, CoreModule::CUSTOMS_DAILY_STATEMENT, 
                              CoreModule::INVOICE, CoreModule::OFFICIAL_TARIFF]
      all_core_modules = CoreModule.all

      leftover_core_modules = (all_core_modules - ordered_core_modules).sort_by {|m| m.label.upcase }

      (ordered_core_modules + leftover_core_modules).keep_if { |cm| cm.enabled? && cm.view?(user) && cm.quicksearch_fields.present? }
    end
end
