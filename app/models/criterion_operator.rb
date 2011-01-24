class CriterionOperator
  attr_reader :key, :query_string, :label
  
  def initialize(key, query_string, label)
    @key = key
    @query_string = query_string
    @label = label
  end
  
  OPERATORS = [
    new("eq"," = ?","Equals"),
    new("gt"," > ?","Greater Than"),
    new("lt"," < ?","Less Than"),
    new("co"," LIKE ?","Contains"),
    new("sw"," LIKE ?","Starts With"),
    new("ew"," LIKE ?","Ends With")
  ]
  
  def self.find_by_key(key)
    OPERATORS.each {|o| return o if o.key==key}
  end
end