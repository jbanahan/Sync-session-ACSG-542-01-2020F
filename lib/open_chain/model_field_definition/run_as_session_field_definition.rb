module OpenChain; module ModelFieldDefinition; module RunAsSessionFieldDefinition

  def add_run_as_session_fields
    add_fields CoreModule::RUN_AS_SESSION, [
        [1, :ras_admin_user, :user_id, "Admin User", {data_type: :string}],
        [2, :ras_run_as_user, :run_as_user_id, "Run As User", {data_type: :string, user_field: true}],
        [3, :ras_start_time, :start_time, "Start Time", {data_type: :datetime}],
        [4, :ras_end_time, :end_time, "End Time", {data_type: :datetime}],
        [5, :ras_admin_username, :user_id, "Admin Username", {
          :export_lambda => lambda { |obj|
            u = obj.user.username || obj.user.id
          },
          :qualified_field_name => "(SELECT username from users where users.id = run_as_sessions.user_id)",
          :data_type => :string
        }],
        [6, :ras_run_as_username, :run_as_user_id, "Run As Username", {
            :export_lambda => lambda { |obj|
              u = obj.run_as_user.username || obj.run_as_user.id
            },
            :qualified_field_name => "(SELECT username from users where users.id = run_as_sessions.run_as_user_id)",
            :data_type => :string
        }]
    ]
  end
end; end; end