module OpenChain; module Api; module V1; class ApiJsonHttpContext

  attr_reader :params, :current_user

  def initialize params: , user: 
    @params = params
    @current_user = user
  end

end; end; end; end;