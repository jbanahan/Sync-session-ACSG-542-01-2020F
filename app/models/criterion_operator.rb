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
    new("notnull"," IS NOT NULL","Is Not Empty"),
    new("bda"," < DATE_ADD(CURDATE(), INTERVAL -? DAY)","Before _ Days Ago"),
    new("ada"," >= DATE_ADD(CURDATE(), INTERVAL -? DAY)","After _ Days Ago"),
    new("adf"," >= DATE_ADD(CURDATE(), INTERVAL ? DAY)","After _ Days From Now"),
    new("bdf"," < DATE_ADD(CURDATE(), INTERVAL ? DAY)","Before _ Days From Now")
  ]
  
  def self.find_by_key(key)
    OPERATORS.each {|o| return o if o.key==key}
    nil
  end
end
