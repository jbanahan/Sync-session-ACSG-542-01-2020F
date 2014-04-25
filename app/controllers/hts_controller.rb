class HtsController < ApplicationController

  skip_filter :require_user,:new_relic,:set_user_time_zone,:log_request,:set_cursor_position,:force_reset

  def index

  end

  def country
    c = Country.find_by_iso_code params[:iso]
    h = {chapters:[]}
    c.official_tariffs.select("distinct left(hts_code,2) as 'ch_code', chapter").order('left(hts_code,4) ASC').each do |ot|
      hd = {num:ot.ch_code,name:ot.chapter,sub_headings:[]}
      h[:chapters] << hd
    end
    render json: h
  end

  def chapter
    h = {headings:[]}
    Country.find_by_iso_code(params[:iso]).official_tariffs.select("distinct mid(hts_code,3,2) as 'hd_code', heading").order('left(hts_code,4) ASC').where("left(hts_code,2) = ?",params[:chapter]).each do |ot|
      h[:headings] << {num:ot.hd_code,name:ot.heading}
    end
    render json: h
  end

  def heading
    h = {sub_headings:[]}
    c = Country.find_by_iso_code(params[:iso])
    c.official_tariffs.select("distinct mid(hts_code,5,2) as 'sh_code', sub_heading").order('left(hts_code,6) ASC').where("left(hts_code,4) = ?",params[:heading]).each do |ot|
      sh = {num:ot.sh_code,name:ot.sub_heading,remaining_descriptions:[]}
      c.official_tariffs.order('hts_code ASC').where('left(hts_code,6) = ?',"#{params[:heading]}#{ot.sh_code}").each do |rd|
        sh[:remaining_descriptions] << {
          num:rd.hts_code[6,4],
          name:rd.remaining_description,
          uom:rd.unit_of_measure,
          general:rd.common_rate,
          special:rd.special_rates,
          col2:rd.column_2_rate
        }
      end
      h[:sub_headings] << sh
    end
    render json: h
  end

  def subscribed_countries
    if logged_in?
      available_countries = Country.where(import_location: true)
      country_hashes = {:countries => []}
      available_countries.each do |country|
        country_hashes[:countries] << {:name => country.name, :iso => country.iso_code}
      end
      render json: country_hashes
    else
      render json: {:countries => [
        {iso:'US',name:'United States'},{iso:'CA',name:'Canada'},{iso:'AU',name:'Australia'},{iso:'CL',name:'Chile'},{iso:'CN',name:'China'},{iso:'HK',name:'Hong Kong'},
        {iso:'ID',name:'Indonesia'},{iso:'IT',name:'Italy'},{iso:'JP',name:'Japan'},{iso:'KR',name:'Korea, Republic of'},{iso:'MO',name:'Macao'},{iso:'MY',name:'Malaysia'},
        {iso:'MX',name:'Mexico'},{iso:'NZ',name:'New Zealand'},{iso:'NO',name:'Norway'},{iso:'PE',name:'Peru'},{iso:'PH',name:'Philippines'},{iso:'RU',name:'Russian Federation'},
        {iso:'SG',name:'Singapore'},{iso:'TW',name:'Taiwan'},{iso:'TH',name:'Thailand'},{iso:'TR',name:'Turkey'},{iso:'VN',name:'Vietnam'}
      ]}
    end
  end

end
