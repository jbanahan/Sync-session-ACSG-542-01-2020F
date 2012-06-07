class CriterionOperator
  attr_reader :key, :label
  
  def initialize(key, query_string, label)
    @key = key
    @query_string = query_string
    @label = label
  end

  def query_string(field_name)
    @query_string.gsub(/_fn_/,field_name)
  end
  
  OPERATORS = [
    new("eq","_fn_ = ?","Equals"),
    new("gt","_fn_ > ?","Greater Than"),
    new("lt","_fn_ < ?","Less Than"),
    new("co","_fn_ LIKE ?","Contains"),
    new("nc","NOT _fn_ LIKE ?","Doesn't Contain"),
    new("sw","_fn_ LIKE ?","Starts With"),
    new("ew","_fn_ LIKE ?","Ends With"),
    new("null","_fn_ IS NULL","Is Empty"),
    new("notnull","_fn_ IS NOT NULL","Is Not Empty"),
    new("bda","_fn_ < DATE_ADD(CURDATE(), INTERVAL -? DAY)","Before _ Days Ago"),
    new("ada","_fn_ >= DATE_ADD(CURDATE(), INTERVAL -? DAY)","After _ Days Ago"),
    new("adf","_fn_ >= DATE_ADD(CURDATE(), INTERVAL ? DAY)","After _ Days From Now"),
    new("bdf","_fn_ < DATE_ADD(CURDATE(), INTERVAL ? DAY)","Before _ Days From Now"),
    new("nq","(_fn_ IS NULL OR NOT _fn_ = ?)","Not Equal To"),
    new("in","(_fn_ IN (?))","One Of"),
    new("pm","(_fn_ >= CAST(DATE_FORMAT(DATE_ADD(NOW(),INTERVAL -? MONTH) ,\"%Y-%m-01\") as DATE) and _fn_ < NOW() and NOT (MONTH(_fn_) = MONTH(NOW()) AND YEAR(_fn_) = YEAR(NOW())))","Previous _ Months")
  ]
  
  def self.find_by_key(key)
    OPERATORS.each {|o| return o if o.key==key}
    nil
  end
end
