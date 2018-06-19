module ConfigMigrations; module Common; class YoyReportSow1452

  def up
    Group.use_system_group 'entry_yoy_report', name: 'Entry Year Over Year Report', description: 'Users permitted to run a report comparing company entry data by month/year.', create: true
  end

  def down
    Group.where(system_code:'entry_yoy_report').destroy_all
  end

end; end; end