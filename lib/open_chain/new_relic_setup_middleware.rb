module OpenChain; class NewRelicSetupMiddleware

  cattr_reader :custom_attributes

  def self.set_constant_custom_attributes opts = {}
   @@custom_attributes = {root: Rails.root.basename.to_s}.merge opts
  end

  def initialize(app)
    @app = app
  end


  def call(env)
    if defined? NewRelic::Agent
      NewRelic::Agent.add_custom_attributes @@custom_attributes
    end
    
    status, headers, response = @app.call(env)
    return [status, headers, response]
  end
end; end