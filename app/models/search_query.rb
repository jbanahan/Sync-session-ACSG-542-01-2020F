#represents a direct SQL query executed for a SearchSetup
class SearchQuery
  attr_reader :search_setup
  attr_reader :user
  def initialize search_setup, user
    @search_setup = search_setup
    @user = user
  end

  # Execute the query returning either an array of hashes or yielding to a block with a hash for each row
  #
  # The hash for each row will look like {:row_key=>1,:result=>['a','b']} where :row_key is the primary key of the top level table in the module_chain 
  # and result is the returned values for the query
  #
  # opts paramter takes :per_page and :page values like `will_paginate`. NOTE: Target page starts with 1 to emulate will_paginate convention
  def execute opts={}
    rs = ActiveRecord::Base.connection.execute to_sql opts
    r = []
    rs.each do |row|
      k = row[0]
      raw = row.to_a.drop(1)
      
      #scrub results through model field
      result = []
      sorted_columns.each_with_index {|sc,i| result << sc.model_field.process_query_result(raw[i],@user)}

      result = result.collect {|r| r.nil? ? "" : r}

      h = {:row_key=>k, :result=>result}
      if block_given?
        yield h
      else
        r << h
      end
    end
    block_given? ? nil : r
  end

  #get distinct list of primary keys for the query
  def result_keys opts={}
    rs = ActiveRecord::Base.connection.execute to_sql opts
    keys = rs.collect {|r| r[0]}
    keys.uniq
  end
  
  #get the row count for the query
  def count
    ActiveRecord::Base.connection.execute(to_sql).size
  end

  #get the count of the total number of unique primary keys for the top level module 
  #
  # For example: If there are 7 entries returned with 3 commercial invoices each, this record will return 7
  # If you're looking for a return value of `21` you should use the `count` method
  def unique_parent_count
    r = "SELECT COUNT(DISTINCT #{@search_setup.core_module.table_name}.id) " +
      build_from + build_where
    ActiveRecord::Base.connection.execute(r).first.first
  end

  # get the SQL query that will be executed
  #
  # opts parameter takes :per_page and :page values like `will_paginate`
  def to_sql opts={}
    build_select + build_from + build_where + build_order + build_pagination_from_opts(opts)
  end
  private
  def build_select
    r = "SELECT DISTINCT "
    flds = ["#{search_setup.core_module.table_name}.id"]
    sorted_columns.each {|sc| flds << sc.model_field.qualified_field_name}
    r << "#{flds.join(", ")} "
    r
  end

  def build_from
    top_module = @search_setup.core_module
    dmc = top_module.default_module_chain
    r = "FROM #{top_module.table_name} "

    # build a list of all core modules used in the query
    core_modules = Set.new
    @search_setup.search_columns.each {|sc| core_modules << sc.model_field.core_module}
    @search_setup.search_criterions.each {|sc| core_modules << sc.model_field.core_module}
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
    if per_page
      return build_pagination(per_page, target_page)
    else
      return ""
    end
  end
  def build_pagination per_page, target_page
    " LIMIT #{per_page} OFFSET #{per_page*(target_page-1)} "
  end
  
  def sorted_columns
    cols = @search_setup.search_columns.to_a
    cols.sort! {|a,b|
      x = a.rank <=> b.rank
      x = a.model_field_uid <=> b.model_field_uid if x==0
      x
    }
  end
end
