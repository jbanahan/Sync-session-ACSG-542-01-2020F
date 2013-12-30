class FixFenixEntryPorts < ActiveRecord::Migration
  def up
    3.times do 
      execute "UPDATE entries SET entry_port_code = CONCAT('0',entry_port_code) WHERE source_system = 'Fenix' AND length(entry_port_code) between 1 and 3"
    end
  end

  def down
  end
end
