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
    new("ew"," LIKE ?","Ends With"),
    new("null"," IS NULL","Is Empty"),
    new("notnull"," IS NOT NULL","Is Not Empty")
  ]
  
  def self.find_by_key(key)
    OPERATORS.each {|o| return o if o.key==key}
  end
end