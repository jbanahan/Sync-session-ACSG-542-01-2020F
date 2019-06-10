module OpenChain; class NewRelicSetupMiddleware

  cattr_reader :custom_attributes

  def self.set_constant_custom_attributes opts = {}
   @@custom_attributes = {root: MasterSetup.instance_directory.basename.to_s, server_name: InstanceInformation.server_name, server_role: InstanceInformation.server_role }.merge opts
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    if defined? NewRelic::Agent && !@@custom_attributes.blank?
      NewRelic::Agent.add_custom_attributes @@custom_attributes
    end
    
    status, headers, response = @app.call(env)
    return [status, headers, response]
  end
end; end