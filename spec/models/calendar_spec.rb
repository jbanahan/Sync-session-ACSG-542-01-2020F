RSpec.describe Calendar, :type => :model do

  let! (:k84) { DataCrossReference.create!(cross_reference_type: "vfi_calendar", key:'K84Due', value:'K84 Due') }
  let! (:us) { DataCrossReference.create!(cross_reference_type: "vfi_calendar", key:'USHol', value:'US Holiday') }
  let! (:ca) { DataCrossReference.create!(cross_reference_type: "vfi_calendar", key:'CAHol', value:'CA Holiday') }

  let! (:calendar) { Calendar.create! calendar_type: k84.key, year: 2019 }
  let! (:calendar_event) { CalendarEvent.create!(event_date: Date.parse('2019-05-16'), calendar_id: calendar.id) }


  describe "find_all_events_in_calendar_month" do
    it "should return the k84 due date for a given month, year and calendar type" do
    	expect(Calendar.find_all_events_in_calendar_month(2019, 5, k84.key).first).to eq calendar_event
    end

    it "should return all holidays in a given month and country calendar" do
      c1 = FactoryBot(:calendar, calendar_type: us.key, year: 2019)
      hol1 = FactoryBot(:calendar_event, event_date: Date.parse('2019-05-16'), calendar_id: c1.id)
      hol2 = FactoryBot(:calendar_event, event_date: Date.parse('2019-05-17'), calendar_id: c1.id)
      hol3 = FactoryBot(:calendar_event, event_date: Date.parse('2019-05-18'), calendar_id: c1.id)

      expect(Calendar.find_all_events_in_calendar_month(2019, 5, us.key)).to eq [hol1, hol2, hol3]
    end

    it "should find calendar events relavent to a given company and not nil" do
      comp = FactoryBot(:company, name: "ACME")
      c1 = FactoryBot(:calendar, calendar_type: k84.key, company_id: comp.id, year: 2019)
      event = FactoryBot(:calendar_event, event_date: Date.parse('2019-05-18'), calendar_id: c1.id)

      expect(Calendar.find_all_events_in_calendar_month(2019, 5, k84.key, company_id: comp.id)).to eq [event]
    end

    it "should not find calendar events from other companies" do
      comp = FactoryBot(:company, name: "NOTACME")
      c1 = FactoryBot(:calendar, calendar_type: k84.key, company_id: comp.id, year: 2019)
      event1 = FactoryBot(:calendar_event, event_date: Date.parse('2019-05-18'), calendar_id: c1.id)

      comp1 = FactoryBot(:company, name: "ACME")
      c2 = FactoryBot(:calendar, calendar_type: k84.key, company_id: comp1.id, year: 2019)
      event2 = FactoryBot(:calendar_event, event_date: Date.parse('2019-05-19'), calendar_id: c2.id)

      expect(Calendar.find_all_events_in_calendar_month(2019, 5, k84.key, company_id: comp.id)).to eq [event1]
    end
  end

end
