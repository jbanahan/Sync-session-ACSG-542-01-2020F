class CriterionOperator
  attr_reader :key, :label

  def initialize(key, query_string, label)
    @key = key
    @query_string = query_string
    @label = label
  end

  def query_string(field_name, data_type, include_empty = false)
    # This code is test cased in the search_criterion's test case
    query = @query_string.gsub(/_fn_/,field_name)
    if include_empty
      query = "#{query} OR #{field_name} IS NULL"

      if character_based_data_type? data_type
        # We'll consider having nothing but whitespace as being empty too
        query += " OR LENGTH(TRIM(#{field_name})) = 0"
      elsif numeric_data_type? data_type
        # We'll consider equaling zero as being empty too
        query += " OR #{field_name} = 0"
      end
      query = "#{query}"
    end

    query 
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
    new("pm","(_fn_ >= CAST(DATE_FORMAT(DATE_ADD(NOW(),INTERVAL -? MONTH) ,\"%Y-%m-01\") as DATE) and _fn_ < NOW() and NOT (MONTH(_fn_) = MONTH(NOW()) AND YEAR(_fn_) = YEAR(NOW())))","Previous _ Months"),
    new("notin","(_fn_ NOT IN (?))","Not One Of"),
  ]
  
  def self.find_by_key(key)
    OPERATORS.each {|o| return o if o.key==key}
    nil
  end

  private 
    def character_based_data_type? data_type
      return [:text, :string].include? data_type
    end

    def numeric_data_type? data_type
      return [:integer, :decimal, :fixnum].include? data_type
    end
end
