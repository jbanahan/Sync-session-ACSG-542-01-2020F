#object manages which server should be the active server for processing scheduled jobs
#DO NOT CREATE OBJECTS MANUALLY.  ONLY USE THE check_in METHOD TO CREATE OBJECTS!
class ScheduleServer < ActiveRecord::Base
  
  HOSTNAME = `hostname`.strip
  EXPIRE_SECONDS = 15

  #is this the current active server in the group (h variable only needs to be passed in unit tests)
  def self.active_schedule_server? h=HOSTNAME
    c = self.connection
    begin
      c.execute "LOCK TABLES schedule_servers WRITE;"
      result = c.execute "SELECT `host` FROM schedule_servers;"
    ensure
      c.execute "UNLOCK TABLES;"
    end
    result.first.first==h 
  end

  #check in and try to become the active server if needed
  def self.check_in h=HOSTNAME
    r = nil
    c = self.connection
    begin
      c.execute "LOCK TABLES schedule_servers WRITE, master_setups as ss1 READ, schedule_servers as ss2 READ;"
      c.execute "INSERT INTO `schedule_servers` (`host`,`touch_time`) SELECT '#{h}' as ip, UTC_TIMESTAMP() as tm FROM `master_setups` as ss1 WHERE NOT EXISTS (SELECT * FROM `schedule_servers` as ss2) LIMIT 1;"
      c.execute "UPDATE `schedule_servers` SET `touch_time` = UTC_TIMESTAMP(), `host` = '#{h}' WHERE (`host` = '#{h}') OR (`touch_time` < DATE_SUB(UTC_TIMESTAMP(), INTERVAL #{EXPIRE_SECONDS} SECOND));"
      r = c.execute "SELECT `host` FROM `schedule_servers`;"
    ensure
      c.execute "UNLOCK TABLES;"
    end
    r.first.first
  end

end
