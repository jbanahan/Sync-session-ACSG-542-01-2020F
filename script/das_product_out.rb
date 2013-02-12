fpos = lambda do |s,len|
	str = s.blank? ? "" : s.to_s
	return str.ljust(len) if str.length <= len
  return str[0,len]
end

f = File.open('tmp/das_out.txt','w')
us_id = Country.find_by_iso_code('US').id
uc = ModelField.find_by_uid "*cf_2".to_sym
coo = ModelField.find_by_uid "*cf_6".to_sym
Product.all.each do |p|
  hts = ""
	c = p.classifications.find_by_country_id us_id
  if c && c.tariff_records.first
		hts = c.tariff_records.first.hts_1
  end
  f << "#{fpos.call(p.unique_identifier,15)}#{fpos.call(p.name,40)}#{fpos.call(uc.process_export(p,nil,true),6)}#{fpos.call(coo.process_export(p,nil,true),2)}#{fpos.call(hts,10)}\r"
end
