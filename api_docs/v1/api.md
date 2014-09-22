# VFI Track - Version 1.0
API for interacting with the Vandegrift VFI Track system

**Conventions**

All API URLs are prefixed by `/api/v1`, so a call listed in this documentation as `/entity/1.json` lives at the url `/api/v1/entity/1.json`

**Versioning**

There will not be breaking changes within the same major version.  Field and methods may be added (but not removed) between minor releases.

**Data Format**

_Date_: YYYY-MM-DD (December 25, 2014 = 2014-12-25)
_Number_: 

* Decimal points must be included.  Non significant are optional do not need to be included. (One Hundred dollars can be represented as 100 or 100.0 or 100.00)
* Negative numbers should be prefixed with a `-` like `-100`

**Errors**

All request are wrapped in transactions, and any error results in a full rollback.

Errors are returned with a 400 or 500 series error code.

400 series errors include a JSON response like `{error:"error message 1\nerror message2"}` where each message is separated by a newline character.

## <a name="QueryAPI"></a>Query API

The query api provides a standard mechanism for most index methods allowing you to provide an arbitrary number of sorts and filters over the data.

A sample request to get all commercial invoices where the invoice number starts with a 7, sorted by invoice date looks like...

**Request**

This get's all commercial invocies with an invoice number that starts with "xyz" ordered by invoice date starting with the oldest.

```
GET - /commercial_invoices.json?page=1&per_page=10&sid1=ci_invoice_number&sop1=sw&sv1=xyz&oid1=ci_invoice_date&oo1=A
```

Parameters:

* page - Search result page (starting with 1, default = 1)
* per_page - How many results per page (default = 10, max = 50)
* sidX - field_id for search criterion X
* sopX - operator for search criterion X
* svX - value for search criterion X
* oidX - field_id for order operation X
* ooX - order value for order operation X (A = Ascending, D = Descending, default = A)

You can have as many search criteria and order operations as you want, just increment the suffix.

**Response**
```
200 - 
{
  results:[
    {
      id:2
      ci_invoice_number:'7abc'
      ci_invoice_date:'2014-12-25'
      ci_imp_syscode:'IMPNUM'
      ci_mfid:'ZYAJFJAKDIA'
      lines: [{
        id:2
        cil_line_number:1
        cil_part_number:'pnum'
        ...
      }]
    },
    {
      id:1
      ci_invoice_number:'def'
      ci_invoice_date:'2014-12-27'
      ...
    }
  ]
  per_page:10 #max value = 50
  page:1 #start at 1
}
```

**Search Operators**

* eq - Equals 
* gt - Greater Than
* lt - Less Than
* co - Contains
* nc - Doesn't Contain
* sw - Starts With
* ew - Ends With
* nsw - Noes Not Start With
* new - Does Not End With
* null - Is Empty
* notnull - Is Not Empty
* bda - Before _ Days Ago
* ada - After _ Days Ago
* adf - After _ Days From Now
* bdf - Before _ Days From Now
* nq - Not Equal To
* in - One Of
* pm - Previous _ Months
* notin - Not One Of

_Currently, you can only search and sort using fields from the top level of the given data object.  For example, you **cannot** search for commercial invoices by the line level part number. Including criteria from the wrong level will result in an error._

## CommercialInvoice

Represents a commercial invoice which may or may not be part of a CustomsEntry

Values should be converted to the currency of the country where the customs entry will be done.  For example, all commercial invoice values for US bound shipments should be in USD.

### Data Object

```
{commercial_invoice:{
    # HEADER INFO
    id:1
    ci_invoice_number:'abc' #required
    ci_invoice_date:'2014-12-25'
    ci_imp_syscode:'IMPNUM' #required
    ci_mfid:'ZYAJFJAKDIA' #manufacturer id number
    ci_currency:'GBP' #base currency for invoice
    ci_invoice_value_foreign:73477.81 #total invoice value in base currency
    ci_invoice_value: 123450.00 #total invoice value in country of entry
    ci_vendor_name:'MyVendor' #name of vendor
    ci_gross_weight: 1000 #weight in KGS
    ci_total_charges: 13 #total of ancillary charges on invoice
    ci_exchange_rate: 1.68 #foreign value * exchange rate = invoice value
    ci_total_quantity: 1000 #total units
    ci_total_quantity_uom: 'PCS' #unit of measure for all items on invoice (only send if it is the same)
    ci_docs_received_date: '2014-01-01' #date documents received from origin
    ci_docs_ok_date: '2014-01-02' #date documents validated as acceptable by rater
    ci_issue_codes:'X ZA' #mutually defined issue codes
    ci_rater_comments:'Illegible documents' #comments from rater
    lines: [{
      id:2 #include for update, otherwise will add
      cil_line_number:1 #required
      cil_part_number:'pnum'
      cil_po_number:'PO12345'
      cil_units:1000 #total commercial units shipped (value / unit price)
      cil_value:123450.00 #commercial value (quanity * unit price) in country of entry
      cil_country_origin_code: 'GB' #iso 2 digit code
      cil_country_export_code: 'DE' #iso 2 digit code
      cil_value_foreign: 73477.81 #line value in base currency
      cil_currency: 'GBP' #base currency for cil_value_foreign
      ent_unit_price:123.45 #same as quantity / value
      tariffs: [{
        cit_hts_code:'1234567890' # no punctuation, required
        cit_entered_value:99.45 #amount to declare to customs
        cit_spi_primary:'A' #special program indicator 1
        cit_spi_secondary:'B' #special program indicator 2
        cit_classification_qty_1:100 #customs quantity 1
        cit_classification_uom_1:'DOZ' #customs unit of measure 1
        cit_classification_qty_2:101 #customs quantity 2 
        cit_classification_uom_2:'KGS' #customs unit of measure 2
        cit_classification_qty_3:102 #customs quantity 3
        cit_classification_uom_3:'OTR' #customs unit of measure 3
        cit_gross_weight:203 #gross weight in KGS (integer)
        cit_tariff_description:'My Desc' #description for customs
        }]
      }]
  }
}
```

### Methods

#### Index

Retrieve a list of commercial invoices

`GET - /commercial_invoices.json`

_See [QueryApi](#QueryAPI) for more info_

#### Show

Retrieve one commercial invoice by ID

_Request_

`GET - /commercial_invoices/1.json` **NOT IMPLEMENTED YET**

_Response_

`200 - one data object as defined above`

#### Create

Retrive multiple commercial invoices

_Request_

`POST - /commercial_invoices.json` with JSON payload of 1 data object as defined above without any `id` attributes at any level

_Response_

`200 - data object with IDs included`

## Company

Represents a Company

__Companies are read only via the API.__

They may be assigned one or more of the following roles:

* Master - The main administrative company for the system
* Vendor - Can receive and accept Purchase Orders, may be able to pack Purchase Orders onto shipments
* Customer - Can issue Purchase Orders, and Shipments and have shpments sent to them
* Importer - Can create Products and can be the importer on a customs entry
* Broker - Can create Customs Entries

_* These descriptions are a partial list of the things that each role may do in the system._


### Data Object

```
{company:{
    # HEADER INFO
    id:1 #database id
    name:'My Company'
    system_code:'MCOM' #code used to assign company in other api modules
    master: true #is the company the master company
    vendor: true 
    customer: true
    importer: true
    broker: true
    carrier: true
  }
}
```

### Methods

#### Index

Retrieve a list of all companies sorted alphabetically by name

`GET - /companies.json`

Returns:
```
{companies:[{id:1 ...},{id:2 ...}]}
```

You can add a query string with a comma separated list of roles to get all companies for each role in a single object like:

`GET - /companies.json?roles=vendor,customer`

Returns
```
{vendors:[{id:1 ...},{id:7 ...}],customers:[{id:1 ...},{id:3 ...}]
```


## Fields

Provides a reference to the logical fields available in the system.

Fields are sorted by ModuleType.  The following ModuleTypes are available to query via the API:

* commercial_invoice
* commercial_invoice_line
* commercial_invoice_tariff
* container
* shipment
* shipment_line

### Data Object

```
{shipment_fields:[
  {uid:'shp_ref',label:'Shipment Reference',data_type:'string'}
  {uid:'shp_mode',label:'Mode',data_type:'string'}
  {uid:'*cf_27',label:'My Custom Field',data_type:'string'}
  ...
  ]
  shipment_line_fields:[
  {uid:'shpln_line_number',label:'Line Number',data_type:'integer'}
  ...
  ]
}
```

### Methods

#### Index

Retrieve a list of fields for comma separated (and case sensitive) list of ModuleTypes

`GET - fields?module_types=shipment,shipment_line`

This method returns all fields available in the system regardless of whether the user has permission to view them or whether they are available in the API.

You will receive a 401 status if you try to query a ModuleType that the user does not have permission to view.

You will receive a 404 status if you try to query a ModuleType that does not exist.

## Order

Represents the purchase of goods.

### Data Object
```
{order:
  #HEADER INFO
  id: 1
  ord_ord_num: 'UID1' #unique order number
  ord_cust_ord_no: 'C_ORD_1' #customer order number
  ord_imp_name: 'My Company'
  ord_imp_syscode: 'MC'
  ord_mode: 'Air' #requested ship mode
  ord_ord_date: '2014-01-01'
  ord_ven_name: 'My Vendor LLC'
  ord_ven_syscode: 'MV'
  *cf_99: 'VAL' #custom field value for custom definition 99, see the custom values section of this documentation for more info
  lines: [{
    id: 2
    ordln_line_number: 1
    ordln_puid: 'SKU123' #product unique identifier
    ordln_pname: 'HAT' #product name
    ordln_ppu: 1.25 #price per unit
    ordln_currency: 'USD'
    ordln_ordered_qty: 100.24
    ordln_country_of_origin: 'CN'
    ordln_hts: '1234567890' #hts code for country where order will be imported
    *cf_1: 'VAL' #custom field value for custom definition 1, see the custom values section of this documentation for more info
    }]
  }
```

### Methods

#### Index

Retrieve a list of shipments

`GET - /orders.json`

_See [QueryApi](#QueryAPI) for more info_



## Shipment

Represents the movement of goods.

In order to build a container based shipment, you must first save the shipment and with the containers then save the lines.  This is because each line must container the 'shpln_container_uid' value in order to be assigned to the container.

When creating  or updating lines, they can be linked to order lines by passing a `linked_order_line_id` attribute in the line object that indicates the order line's DB id that should be linked.

You can optionally have any related order lines nested in the shipment lines by including the parameter `include=order_lines` in your request.  When the order lines are returned they will also include read only convenience fields with each line as follows:

```
ord_ord_num: 'UID1' #unique order number
ord_cust_ord_no: 'ORD123' #customer order number
allocated_quantity: 7 #the quantity from the order line that is allocated to the shipment line
order_id: 77 #db id of order
```

### Data Object
```
{shipment:
  #HEADER INFO
  shp_ref: 'MYSHIPREF'
  shp_mode: 'Air'
  shp_ven_name: 'Vendor Name'
  shp_ven_syscode: 'VENSYSCODE' #unique system code for vender
  shp_ship_to_name: 'Joe Warehouse'
  shp_ship_from_name: 'My Factory'
  shp_car_name: 'Vandegrift Logistics'
  shp_car_syscode: 'VFILOG' #unique system code for carrier
  shp_imp_name: 'My Company'
  shp_imp_syscode: 'MYCOMP' #unique system code for importer - REQUIRED FOR CREATE
  shp_master_bill_of_lading: 'MBOL'
  shp_house_bill_of_lading: 'HBOL'
  shp_booking_number: 'BOOK1'
  shp_receipt_location: 'YANTIAN'
  shp_freight_terms: 'COB'
  shp_lcl: true #boolean true for LCL freight, false for fcl freight
  shp_shipment_type: 'CFS/CY' #free form
  shp_booking_shipment_type: 'CFS/CY' #free form
  shp_booking_mode: 'Air' #mode requested at time of booking confirmation
  shp_vessel: 'CSCLVANCOUVER'
  shp_voyage: '0098'
  shp_vessel_carrier_scac: 'CHHK'
  shp_booking_received_date: '2014-01-01'
  shp_booking_confirmed_date: '2014-01-02'
  shp_booking_cutoff_date: '2014-01-10'
  shp_booking_est_departure_date: '2014-01-15'
  shp_booking_est_arrival_date: '2014-01-30'
  shp_docs_received_date: '2014-01-06'
  shp_cargo_on_hand_date: '2014-01-08'
  shp_est_departure_date: '2014-01-15'
  shp_departure_date: '2014-01-15'
  shp_est_arrival_port_date: '2014-01-30'
  shp_arrival_port_date: '2014-01-30'
  shp_est_delivery_date: '2014-02-03'
  shp_delivered_date: '2014-02-03'
  *cf_99: 'VAL' #custom field value for custom definition 99, see the custom values section of this documentation for more info
  lines: [{
    shpln_line_number: 1 #sequential line number for this line on the shipment
    shpln_shipped_qty: 1.23 #quantity shipped
    shpln_puid: 'PARTNUM' #unique ID of product shipped
    shpln_pname: 'CHAIR' #product name
    shpln_container_uid: 123 #database id of container
    shpln_container_number: 'ABCD12345' 
    shpln_container_size: '40HC'
    *cf_1: 'VAL' #custom field value for custom definition 1, see the custom values section of this documentation for more info
    #OPTIONAL with includes=order_lines parameter
    order_lines: [{
      id: 2
      ord_ord_num: 'ORDER123'
      ord_cust_ord_no: 'CORDER1234'
      order_id: 77
      allocated_quantity: 7
      ordln_line_number: 1
      ordln_puid: 'SKU123' #product unique identifier
      ordln_pname: 'HAT' #product name
      ordln_ppu: 1.25 #price per unit
      ordln_currency: 'USD'
      ordln_ordered_qty: 100.24
      ordln_country_of_origin: 'CN'
      ordln_hts: '1234567890' #hts code for country where order will be imported
      *cf_50: 'VAL'
      }]
    }]
  containers: [{
    con_uid: 123 #database id of container
    con_container_number: 'ABCD12345'
    con_container_size: '40HC'
    con_size_description: '40FT HIGH CUBE'
    con_weight: 100
    con_seal_number: 'ABC555'
    con_teus: 2
    con_fcl_lcl: 'fcl' #fcl for full container, lcl for LCL shipment within consolidated container
    con_quantity: 10 #AMS reporting quantity (usually in cartons)
    con_uom: 'CTNS' #AMS reporting unit of measure (usually CTNS)
    }]
  permissions: [ #these are the permissions this user has for this specific object
    can_view:true
    can_edit:false
    can_attach:true #can add file attachments
    can_comment:false #cannot add comments
  ]
  }
```

### Methods

#### Index

Retrieve a list of shipments

`GET - /shipments.json`

_See [QueryApi](#QueryAPI) for more info_

#### Show

Retrieve one shipment by ID

_Request_

`GET - /shipments/1.json`

_Response_

`200 - one data object as defined above`

#### Create

Make a new shipment

_Request_

`POST - /shipment.json` with JSON payload of 1 data object as defined above without any `id` attributes at any level

#### Update

Update a shipment

_Request_

`PUT - /shipment/1.json` with JSON payload of 1 data object with an id attribute that matches the path.  Child level objects with id attributes will be updated and child level objects without will be created.

_Response_

`200 - data object with IDs included`

#### Available Orders

List orders which may be added to this shipment

`GET - /shipments/1/available_orders.json`

_Response_

```
{available_orders:[{
  id: 1
  ord_ord_num: 'UID1' #unique order number
  ord_cust_ord_no: 'C_ORD_1' #customer order number
  ord_imp_name: 'My Company' #importer name
  ord_mode: 'Air' #requested ship mode
  ord_ord_date: '2014-01-01' #order date
  ord_ven_name: 'My Vendor LLC' #vendor name
}]}
```

## User - Event Subscriptions

Represents a user's notification subscriptions for certain system generated events.

The following event types are available:

* ORDER_COMMENT_CREATE - When a comment is added to an order by someone other than the user in question

### Data Object
{event_subscription:{
  event_type:'ORDER_COMMENT_CREATE'
  email:true #the user has elected to receive email when this event happens
  user_id: 7 #user's unique id
  }
}

### Methods

#### Index

List all subscriptions for the given user

`GET - /users/7/event_subscriptions.json`

_Response_

{event_subscriptions:[{event_type:'ORDER_COMMENT_CREATE',email:true,user_id:7},
{event_type:'SHIPMENT_COMMENT_CREATE',email:true,user_id:7}]}

#### Replace

Replace user's subscriptions with the given array

`POST - /users/7/event_subscriptions` with a JSON payload of an event_subscriptions object with array of event subscriptions (just like `index`).  The `user_id` attribute in the subscription objects will be ignored in favor of the `user_id` in the URL.



