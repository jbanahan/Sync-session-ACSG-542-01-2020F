module ConfigMigrations; module Common; class PopulateCalendar

  def up
    generate_data_cross_references
    generate_holiday_calendars
    generate_pms_calendar_events
    generate_k84_calendar_events
  end

  def down
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_CALENDAR).destroy_all
    Calendar.destroy_all
    CalendarEvent.destroy_all
    nil
  end

  def generate_data_cross_references
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_CALENDAR, key:'USHol', value:'US Holiday').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_CALENDAR, key:'CAHol', value:'CA Holiday').first_or_create!
  end

  def generate_holiday_calendars
    us = DataCrossReference.where('value = ?', 'US Holiday').first
    Calendar.where(calendar_type: us.key, year: 2019).first_or_create!

    ca = DataCrossReference.where('value = ?', 'CA Holiday').first
    Calendar.where(calendar_type: ca.key, year: 2019).first_or_create!
  end

  def generate_pms_calendar_events
    pms = DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_CALENDAR, key:'PMS', value:'PMS').first_or_create!
    pms2019 = Calendar.where(calendar_type: pms.key, year: 2019).first_or_create!

    CalendarEvent.where(calendar_id: pms2019.id, event_date: Date.parse('2019-01-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2019.id, event_date: Date.parse('2019-02-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2019.id, event_date: Date.parse('2019-03-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2019.id, event_date: Date.parse('2019-04-19')).first_or_create!
    CalendarEvent.where(calendar_id: pms2019.id, event_date: Date.parse('2019-05-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2019.id, event_date: Date.parse('2019-06-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2019.id, event_date: Date.parse('2019-07-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2019.id, event_date: Date.parse('2019-08-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2019.id, event_date: Date.parse('2019-09-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2019.id, event_date: Date.parse('2019-10-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2019.id, event_date: Date.parse('2019-11-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2019.id, event_date: Date.parse('2019-12-20')).first_or_create!

    pms2018 = Calendar.where(calendar_type: pms.key, year: 2018).first_or_create!
    CalendarEvent.where(calendar_id: pms2018.id, event_date: Date.parse('2018-01-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2018.id, event_date: Date.parse('2018-02-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2018.id, event_date: Date.parse('2018-03-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2018.id, event_date: Date.parse('2018-04-20')).first_or_create!
    CalendarEvent.where(calendar_id: pms2018.id, event_date: Date.parse('2018-05-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2018.id, event_date: Date.parse('2018-06-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2018.id, event_date: Date.parse('2018-07-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2018.id, event_date: Date.parse('2018-08-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2018.id, event_date: Date.parse('2018-09-24')).first_or_create!
    CalendarEvent.where(calendar_id: pms2018.id, event_date: Date.parse('2018-10-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2018.id, event_date: Date.parse('2018-11-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2018.id, event_date: Date.parse('2018-12-21')).first_or_create!

    pms2017 = Calendar.where(calendar_type: pms.key, year: 2017).first_or_create!
    CalendarEvent.where(calendar_id: pms2017.id, event_date: Date.parse('2017-01-24')).first_or_create!
    CalendarEvent.where(calendar_id: pms2017.id, event_date: Date.parse('2017-02-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2017.id, event_date: Date.parse('2017-03-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2017.id, event_date: Date.parse('2017-04-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2017.id, event_date: Date.parse('2017-05-19')).first_or_create!
    CalendarEvent.where(calendar_id: pms2017.id, event_date: Date.parse('2017-06-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2017.id, event_date: Date.parse('2017-07-24')).first_or_create!
    CalendarEvent.where(calendar_id: pms2017.id, event_date: Date.parse('2017-08-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2017.id, event_date: Date.parse('2017-09-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2017.id, event_date: Date.parse('2017-10-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2017.id, event_date: Date.parse('2017-11-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2017.id, event_date: Date.parse('2017-12-21')).first_or_create!

    pms2016 = Calendar.where(calendar_type: pms.key, year: 2016).first_or_create!
    CalendarEvent.where(calendar_id: pms2016.id, event_date: Date.parse('2016-01-25')).first_or_create!
    CalendarEvent.where(calendar_id: pms2016.id, event_date: Date.parse('2016-02-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2016.id, event_date: Date.parse('2016-03-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2016.id, event_date: Date.parse('2016-04-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2016.id, event_date: Date.parse('2016-05-20')).first_or_create!
    CalendarEvent.where(calendar_id: pms2016.id, event_date: Date.parse('2016-06-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2016.id, event_date: Date.parse('2016-07-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2016.id, event_date: Date.parse('2016-08-19')).first_or_create!
    CalendarEvent.where(calendar_id: pms2016.id, event_date: Date.parse('2016-09-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2016.id, event_date: Date.parse('2016-10-24')).first_or_create!
    CalendarEvent.where(calendar_id: pms2016.id, event_date: Date.parse('2016-11-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2016.id, event_date: Date.parse('2016-12-21')).first_or_create!

    pms2015 = Calendar.where(calendar_type: pms.key, year: 2015).first_or_create!
    CalendarEvent.where(calendar_id: pms2015.id, event_date: Date.parse('2015-01-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2015.id, event_date: Date.parse('2015-02-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2015.id, event_date: Date.parse('2015-03-20')).first_or_create!
    CalendarEvent.where(calendar_id: pms2015.id, event_date: Date.parse('2015-04-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2015.id, event_date: Date.parse('2015-05-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2015.id, event_date: Date.parse('2015-06-19')).first_or_create!
    CalendarEvent.where(calendar_id: pms2015.id, event_date: Date.parse('2015-07-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2015.id, event_date: Date.parse('2015-08-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2015.id, event_date: Date.parse('2015-09-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2015.id, event_date: Date.parse('2015-10-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2015.id, event_date: Date.parse('2015-11-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2015.id, event_date: Date.parse('2015-12-21')).first_or_create!

    pms2014 = Calendar.where(calendar_type: pms.key, year: 2014).first_or_create!
    CalendarEvent.where(calendar_id: pms2014.id, event_date: Date.parse('2014-01-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2014.id, event_date: Date.parse('2014-02-24')).first_or_create!
    CalendarEvent.where(calendar_id: pms2014.id, event_date: Date.parse('2014-03-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2014.id, event_date: Date.parse('2014-04-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2014.id, event_date: Date.parse('2014-05-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2014.id, event_date: Date.parse('2014-06-20')).first_or_create!
    CalendarEvent.where(calendar_id: pms2014.id, event_date: Date.parse('2014-07-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2014.id, event_date: Date.parse('2014-08-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2014.id, event_date: Date.parse('2014-09-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2014.id, event_date: Date.parse('2014-10-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2014.id, event_date: Date.parse('2014-11-24')).first_or_create!
    CalendarEvent.where(calendar_id: pms2014.id, event_date: Date.parse('2014-12-19')).first_or_create!

    pms2013 = Calendar.where(calendar_type: pms.key, year: 2013).first_or_create!
    CalendarEvent.where(calendar_id: pms2013.id, event_date: Date.parse('2013-01-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2013.id, event_date: Date.parse('2013-02-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2013.id, event_date: Date.parse('2013-03-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2013.id, event_date: Date.parse('2013-04-19')).first_or_create!
    CalendarEvent.where(calendar_id: pms2013.id, event_date: Date.parse('2013-05-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2013.id, event_date: Date.parse('2013-06-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2013.id, event_date: Date.parse('2013-07-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2013.id, event_date: Date.parse('2013-08-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2013.id, event_date: Date.parse('2013-09-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2013.id, event_date: Date.parse('2013-10-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2013.id, event_date: Date.parse('2013-11-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2013.id, event_date: Date.parse('2013-12-20')).first_or_create!

    pms2012 = Calendar.where(calendar_type: pms.key, year: 2012).first_or_create!
    CalendarEvent.where(calendar_id: pms2012.id, event_date: Date.parse('2012-01-24')).first_or_create!
    CalendarEvent.where(calendar_id: pms2012.id, event_date: Date.parse('2012-02-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2012.id, event_date: Date.parse('2012-03-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2012.id, event_date: Date.parse('2012-04-20')).first_or_create!
    CalendarEvent.where(calendar_id: pms2012.id, event_date: Date.parse('2012-05-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2012.id, event_date: Date.parse('2012-06-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2012.id, event_date: Date.parse('2012-07-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2012.id, event_date: Date.parse('2012-08-21')).first_or_create!
    CalendarEvent.where(calendar_id: pms2012.id, event_date: Date.parse('2012-09-24')).first_or_create!
    CalendarEvent.where(calendar_id: pms2012.id, event_date: Date.parse('2012-10-22')).first_or_create!
    CalendarEvent.where(calendar_id: pms2012.id, event_date: Date.parse('2012-11-23')).first_or_create!
    CalendarEvent.where(calendar_id: pms2012.id, event_date: Date.parse('2012-12-21')).first_or_create!
  end

  def generate_k84_calendar_events
    k84 = DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_CALENDAR, key:'K84Due', value:'K84 Due').first_or_create!
    k842019 = Calendar.where(calendar_type: k84.key, year: 2019).first_or_create!

    CalendarEvent.where(calendar_id: k842019.id, event_date: Date.new(2019,1,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842019.id, event_date: Date.new(2019,2,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842019.id, event_date: Date.new(2019,3,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842019.id, event_date: Date.new(2019,4,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842019.id, event_date: Date.new(2019,5,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842019.id, event_date: Date.new(2019,6,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842019.id, event_date: Date.new(2019,7,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842019.id, event_date: Date.new(2019,8,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842019.id, event_date: Date.new(2019,9,27)).first_or_create!
    CalendarEvent.where(calendar_id: k842019.id, event_date: Date.new(2019,10,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842019.id, event_date: Date.new(2019,11,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842019.id, event_date: Date.new(2019,12,30)).first_or_create!

    k842015 = Calendar.where(calendar_type: k84.key, year: 2015).first_or_create!
    CalendarEvent.where(calendar_id: k842015.id, event_date: Date.new(2015,1,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842015.id, event_date: Date.new(2015,2,26)).first_or_create!
    CalendarEvent.where(calendar_id: k842015.id, event_date: Date.new(2015,3,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842015.id, event_date: Date.new(2015,4,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842015.id, event_date: Date.new(2015,5,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842015.id, event_date: Date.new(2015,6,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842015.id, event_date: Date.new(2015,7,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842015.id, event_date: Date.new(2015,8,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842015.id, event_date: Date.new(2015,9,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842015.id, event_date: Date.new(2015,10,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842015.id, event_date: Date.new(2015,11,27)).first_or_create!
    CalendarEvent.where(calendar_id: k842015.id, event_date: Date.new(2015,12,30)).first_or_create!

    k842016 = Calendar.where(calendar_type: k84.key, year: 2016).first_or_create!
    CalendarEvent.where(calendar_id: k842016.id, event_date: Date.new(2016,1,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842016.id, event_date: Date.new(2016,2,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842016.id, event_date: Date.new(2016,3,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842016.id, event_date: Date.new(2016,4,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842016.id, event_date: Date.new(2016,5,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842016.id, event_date: Date.new(2016,6,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842016.id, event_date: Date.new(2016,7,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842016.id, event_date: Date.new(2016,8,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842016.id, event_date: Date.new(2016,9,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842016.id, event_date: Date.new(2016,10,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842016.id, event_date: Date.new(2016,11,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842016.id, event_date: Date.new(2016,12,30)).first_or_create!

    k842017 = Calendar.where(calendar_type: k84.key, year: 2017).first_or_create!
    CalendarEvent.where(calendar_id: k842017.id, event_date: Date.new(2017,1,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842017.id, event_date: Date.new(2017,2,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842017.id, event_date: Date.new(2017,3,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842017.id, event_date: Date.new(2017,4,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842017.id, event_date: Date.new(2017,5,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842017.id, event_date: Date.new(2017,6,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842017.id, event_date: Date.new(2017,7,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842017.id, event_date: Date.new(2017,8,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842017.id, event_date: Date.new(2017,9,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842017.id, event_date: Date.new(2017,10,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842017.id, event_date: Date.new(2017,11,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842017.id, event_date: Date.new(2017,12,29)).first_or_create!

    k842018 = Calendar.where(calendar_type: k84.key, year: 2018).first_or_create!
    CalendarEvent.where(calendar_id: k842018.id, event_date: Date.new(2018,1,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842018.id, event_date: Date.new(2018,2,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842018.id, event_date: Date.new(2018,3,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842018.id, event_date: Date.new(2018,4,27)).first_or_create!
    CalendarEvent.where(calendar_id: k842018.id, event_date: Date.new(2018,5,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842018.id, event_date: Date.new(2018,6,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842018.id, event_date: Date.new(2018,7,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842018.id, event_date: Date.new(2018,8,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842018.id, event_date: Date.new(2018,9,28)).first_or_create!
    CalendarEvent.where(calendar_id: k842018.id, event_date: Date.new(2018,10,30)).first_or_create!
    CalendarEvent.where(calendar_id: k842018.id, event_date: Date.new(2018,11,29)).first_or_create!
    CalendarEvent.where(calendar_id: k842018.id, event_date: Date.new(2018,12,28)).first_or_create!
  end

end; end; end
