class StatusableError < StandardError
  attr_accessor :http_status, :errors

  def initialize errors = [], http_status = :forbidden
    # Allow for simple case where we pass a single error message string
    @errors = errors.is_a?(String) ? [errors] : errors
    @http_status = http_status
    super(@errors.first)
  end
end
