module OpenChain; module ActiveDatesSupport
  def self.included(base)
      base.extend(ClassMethods)
  end

  def active? for_date=Date.current
    return false unless self.start_date && self.end_date
    return for_date >= self.start_date && for_date <= self.end_date
  end

  module ClassMethods
    def active for_date=Date.current
      where(active_where_clause(for_date))
    end

    # this is separate from the active method so the ModelField implementation can access it directly
    # when building search queries
    def active_where_clause for_date=Date.current
      tn = table_name
      "#{tn}.start_date <= ':effective_date' AND #{tn}.end_date >= ':effective_date'".gsub(/:effective_date/,for_date.to_formatted_s(:db))
    end
  end
end; end
