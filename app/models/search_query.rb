#represents a direct SQL query executed for a SearchSetup
class SearchQuery
  attr_reader :search_setup
  attr_reader :user

  #
  # search_setup must be an object that implements the following interface
  # * #core_module - returns CoreModule
  # * #search_columns - returns Enumerable of SearchColumn objects
  # * #search_criterions - returns Enumerable of SearchCriterions
  # * #sort_criterions - returns Enumberable of SortCriterions
  #
  # valid values for opts = {:extra_where=>'a where clause that will be appended to all queries as an AND'}
  #
  def initialize search_setup, user, opts={}
    @search_setup = search_setup
    @user = user
    @extra_from = opts[:extra_from]
    @extra_where = opts[:extra_where]
  end

  # Execute the query returning either an array of hashes or yielding to a block with a hash for each row
  #
  # The hash for each row will look like {:row_key=>1,:result=>['a','b']} where :row_key is the primary key of the top level table in the module_chain 
  # and result is the returned values for the query
  #
  # opts paramter takes :per_page and :page values like `will_paginate`. NOTE: Target page starts with 1 to emulate will_paginate convention
  # See to_sql for full list of options
  def execute opts={}
    rs = ActiveRecord::Base.connection.execute to_sql opts
    rows = []
    
    # This gives us the number of table.id columns prefixed onto the query that will need to get dropped
    core_module_id_aliases = ordered_core_modules(opts)

    rs.each do |row|
      # We want to remove these from the selected row since they're not actual query data
      # First column to remove is ALWAYS the core primary key
      core_primary_key = row[0]
      raw_result_row = row.to_a.drop(core_module_id_aliases.size)
      
      #scrub results through model field
      result = []
      sorted_columns.each_with_index {|sc,i| result << sc.model_field.process_query_result(raw_result_row[i],@user)}

      result = result.collect {|column| column.nil? ? "" : column}

      h = {:row_key=>core_primary_key, :result=>result}
      if block_given?
        yield h
      else
        rows << h
      end
    end
    block_given? ? nil : rows
  end

  #get distinct list of primary keys for the query
  def result_keys opts={}
    # Using a hash to preserve insertion order (Set doesn't guarantee that while hash does)
    keys = {}
    execute(opts.merge(select_core_module_keys_only:true)) {|result| keys[result[:row_key]] = true}
    keys.keys
  end
  
  #get the row count for the query
  def count
    # Limit count to only including the core module keys will eliminate running any subselects in the select clauses
    ActiveRecord::Base.connection.execute("#{to_sql(select_core_module_keys_only:true, disable_pagination: true)} LIMIT 1000").count
  end

  #get the count of the total number of unique primary keys for the top level module 
  #
  # For example: If there are 7 entries returned with 3 commercial invoices each, this record will return 7
  # If you're looking for a return value of `21` you should use the `count` method
  def unique_parent_count
    r = "SELECT COUNT(DISTINCT #{ordered_core_modules(select_parent_key_only:true)[0].table_name}.id) " +
      build_from(disable_join_optimization: true) + build_where
    ActiveRecord::Base.connection.execute(r).first.first
  end

  # get the SQL query that will be executed
  #
  # opts parameter takes :per_page and :page values like `will_paginate`
  # use the 'select_parent_key_only' opt to create a query only returning the parent core object keys (ala unique_parent_count)
  # use the 'select_core_module_keys_only' to create a query returning the parent and child core module keys, 
  # when utilized the parent core module key is ALWAYS returned in the first column
  def to_sql opts={}
    # By default, only allow the maximum number of results the search setup affords
    # This can be overridden by passing a true value for disable_pagination op
    opts = {per_page: @search_setup.max_results}.merge opts
    build_select(opts) + build_from(opts) + build_where + build_order + build_pagination_from_opts(opts)
  end

  private
  def build_select opts
    r = "SELECT DISTINCT "
    flds = core_module_id_select_list opts
    unless opts[:select_core_module_keys_only] || opts[:select_parent_key_only]
      sorted_columns.each_with_index {|sc,idx| flds << "#{sc.model_field.qualified_field_name} AS \"#{idx}\""}
    end
    r << "#{flds.join(", ")} "
    r
  end

  def core_module_id_select_list opts
    # We need to use a SELECT DISTINCT for cases where we have to join a child table into the query because the
    # user added a parameter or sort from it but did NOT have that table as part of the select list.  Because of this
    # we need to make sure then that we're NOT combining results via the distinct from any of the tables the user did included 
    # in the select list.  Include the table's id column for any core module table included in the select list.

    # .ie User queries for invoice amounts on entries with invoice line po number of 123.  If two different invoices
    # had PO 123 on them and totaled to 100, we want to make sure we're showing both of them.  With just a plain distinct
    # they'll roll together.
    ordered_core_modules(opts).map {|cm| "#{cm.table_name}.id as \"#{cm.table_name}_id\""}
  end

  def ordered_core_modules opts
    if opts[:select_parent_key_only]
      [@search_setup.core_module]
    else
      # Some columns (like _blank)  won't have core modules
      child_core_modules = Set.new(@search_setup.search_columns.map {|sc| sc.model_field.core_module}.compact)

      # Keep the primary core module's id as the first column
      child_core_modules.delete(@search_setup.core_module)

      [@search_setup.core_module] + child_core_modules.to_a
    end
  end

  def build_from opts
    top_module = @search_setup.core_module
    dmc = top_module.default_module_chain
    r = "FROM #{top_module.table_name} "

    # build a list of all core modules used in the query
    core_modules = Set.new
    @search_setup.search_columns.each {|sc| core_modules << sc.model_field.core_module}
    @search_setup.search_criterions.each {|sc| 
      core_modules << sc.model_field.core_module
      # Some search criterions can contain references to mutiple model fields, which may
      # be at different levels.  Make sure we're adding the core modules for these 
      # secondary fields.
      mf_two = sc.secondary_model_field
      if mf_two
        core_modules << mf_two.core_module
      end
    }
    @search_setup.sort_criterions.each {|sc| core_modules << sc.model_field.core_module}

    # loop through the chain including all modules used and all of their parents
    join_statements = []
    include_remaining = false
    module_chain = dmc.to_a
    while !module_chain.empty?
      cm = module_chain.pop
      next if cm == top_module
      include_remaining = true if core_modules.include? cm
      join_statements << dmc.parent(cm).child_joins[cm] if include_remaining
    end
    unless join_statements.empty?
      r << join_statements.reverse.join("  ")
    end
    r << " #{@extra_from} " unless @extra_from.blank?

    unless opts[:disable_join_optimization] || opts[:select_core_module_keys_only]
      r << from_inner_optimization(opts)
    end
    r
  end

  def build_where
    wheres = @search_setup.search_criterions.collect do |sc| 
      v = sc.where_value
      if v.respond_to? :collect
        v = v.collect {|val| ActiveRecord::Base.sanitize val}.join(",")
      else
        v = ActiveRecord::Base.sanitize v
      end
      sc.where_clause(v).gsub("?",v)
    end
    wheres << @search_setup.core_module.klass.search_where(@user)
    wheres << @extra_where unless @extra_where.blank?
    if wheres.empty?
      return ""
    else 
      return " WHERE (#{wheres.join(") AND (")}) "
    end
  end

  def build_order
    r = " ORDER BY "
    sorts = @search_setup.sort_criterions
    #using this sort instead of .order so we don't make a db call when working with an unsaved SearchSetup
    sorts.sort! {|a,b|
      x = a.rank <=> b.rank
      x = a.model_field_uid <=> b.model_field_uid if x==0
      x
    }
    #need to put the sorts in the right order from top of the module chain to the bottom
    #and also inject id sorts on any parent levels that don't already have a sort
    sort_clause_hash = {}
    module_chain_array = @search_setup.core_module.default_module_chain.to_a
    module_chain_array.each {|cm| sort_clause_hash[cm] = []}
    sorts.each do |sc|
      mf = sc.model_field
      sort_clause_hash[mf.core_module] << "#{mf.qualified_field_name} #{sc.descending? ? "DESC" : "ASC"}"
    end
    sort_clauses = []
    need_parent_sorts = false
    while !module_chain_array.empty?
      cm = module_chain_array.pop
      a = sort_clause_hash[cm]
      need_parent_sorts = true unless a.empty?
      if need_parent_sorts && a.empty?
        a << "#{cm.table_name}.id"
      end
      sort_clauses = a + sort_clauses #add clauses to the beginning because we're looping backwards 
    end
    sort_clauses.empty? ? "" : r << sort_clauses.join(", ")
  end
  
  #build pagination from the options hash or return empty string if :per_page and :page values aren't there
  def build_pagination_from_opts opts
    target_page = (opts[:page].blank? || !opts[:page].to_s.strip.match(/^[1-9]([0-9]*)$/)) ? 1 : opts[:page].to_i
    per_page = (opts[:per_page].blank? || !opts[:per_page].to_s.strip.match(/^[1-9]([0-9]*)$/)) ? nil : opts[:per_page].to_i
    if per_page && !opts[:disable_pagination]
      return build_pagination(per_page, target_page)
    else
      return ""
    end
  end
  def build_pagination per_page, target_page
    paginate = ""
    paginate += " LIMIT #{per_page}" if per_page
    paginate += " OFFSET #{per_page*(target_page-1)} " if target_page
    paginate
  end
  
  def sorted_columns
    cols = @search_setup.search_columns.to_a
    cols.sort! {|a,b|
      x = a.rank <=> b.rank
      x = a.model_field_uid <=> b.model_field_uid if x==0
      x
    }
  end

  def from_inner_optimization opts
    # The optimization we're doing here is to join on a subselect of the data so that we can eliminate having to
    # do the select subselects for all but only the data we're going to be showing to the user, it also allows
    # the query to only buffer for DISTINCT the values we'll actually be displaying as well.

    # This isn't necessarily an optimization for search queries hitting small bits of data but it helps quite a bit on very broad ones.
    # A further optimization might be to track runtimes of searches and only add this optimization if the query runs
    # over X amount of seconds.
    inner_optimization = ""
    pagination = build_pagination_from_opts(opts)

    # There's little point in doing this optimation if we're not paginating the results since the whole point of this
    # is to only do the full select subselects over the range of data we're going to be viewing.  This also means
    # that the downloads will NOT have this optimization applied.  We could possible further optimize those cases by 
    # taking an iterative approach to the downloads and walking through those one "page" at a time as part of the 
    # download process which would allow for applying this method to downloads as well.
    unless pagination.blank?
      inner_opts = opts.merge select_core_module_keys_only: true, disable_join_optimization: true
      core_modules = ordered_core_modules inner_opts

      inner_optimization = " INNER JOIN (" + to_sql(inner_opts) + ") AS inner_opt ON "

      core_modules.each_with_index do |cm, i|
        inner_optimization += " AND " if i > 0
        inner_optimization += "(#{cm.table_name}.id = inner_opt.#{cm.table_name}_id"
        # The first element of core modules is the base model (ie. product, entry, etc) we never have to worry about
        # a null value in there
        if i > 0
          inner_optimization += " OR (#{cm.table_name}.id IS NULL AND #{cm.table_name}_id IS NULL)"
        end
        inner_optimization += ")"
      end

      # We need to disable the pagination because the subselect optimization already determined what 
      # set of data keys the outer query should include (thus ensuring the correct paginated range 
      # of data is used)
      opts[:disable_pagination] = true
    end

    inner_optimization
  end
end
