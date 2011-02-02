m = MasterSetup.first
if m.nil?
  m = MasterSetup.create!(:uuid => UUIDTools::UUID.timestamp_create.to_s)
end