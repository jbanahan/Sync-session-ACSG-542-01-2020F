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

**Search Criterion Operators**

**FINISH THIS SECTION**

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