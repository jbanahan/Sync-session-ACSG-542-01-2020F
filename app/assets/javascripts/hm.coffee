app = angular.module 'HMApp', ['ChainComponents']
app.config(['$httpProvider', ($httpProvider) ->
    $httpProvider.defaults.headers.common['Accept'] = 'application/json';
])
app.factory 'hmService', ['$http',($http) ->
  sys_code: 'HENNE'
  line_to_api : (line) ->
    r = {commercial_invoice:
      {
        ci_invoice_number:line.po_number
        ci_imp_syscode:@.sys_code
        ci_invoice_value_foreign:line.invoice_value
        ci_total_quantity:line.cartons
        ci_total_quantity_uom:'CTNS'
        ci_docs_received_date:line.docs_rec_date
        ci_docs_ok_date:line.docs_ok_date
        ci_issue_codes:line.issue_codes
        ci_rater_comments:line.comment
        ci_mfid:line.mid
        ci_destination_code:line.coast
        commercial_invoice_lines:[
          {
            cil_value_foreign:line.adjusted_value
            cil_currency:line.currency
            cil_line_number:1
            cil_units:line.quantity
            cil_country_origin_code:line.origin_country
            ent_unit_price:line.unit_cost
            commercial_invoice_tariffs:[{
              cit_hts_code:line.hts_code
              cit_gross_weight: line.gross_weight
              cit_classification_qty_1: line.reporting_quantity
              cit_classification_uom_1: line.reporting_uom
            }
            ]
          }
        ]
      }
    }
    r.commercial_invoice.id = line.id if line.id
    r.commercial_invoice.commercial_invoice_lines[0].id = line.ci_line_id if line.ci_line_id
    if line.net_weight && line.net_weight > 0
      t = r.commercial_invoice.commercial_invoice_lines[0].commercial_invoice_tariffs[0]
      t.cit_classification_qty_2 = line.net_weight
      t.cit_classification_uom_2 = 'KGS'
    r

  api_to_line : (ci) ->
    ci_line = ci.commercial_invoice_lines[0]
    r = {
      po_number:ci.ci_invoice_number
      id:ci.id
      cartons:Number(ci.ci_total_quantity)
      invoice_value:Number(ci.ci_invoice_value_foreign)
      docs_rec_date:ci.ci_docs_received_date
      docs_ok_date:ci.ci_docs_ok_date
      issue_codes:ci.ci_issue_codes
      comment:ci.ci_rater_comments
      quantity:Number(ci_line.cil_units)
      unit_cost:Number(ci_line.ent_unit_price)
      adjusted_value:Number(ci_line.cil_value_foreign)
      ci_line_id:ci_line.id
      currency:ci_line.cil_currency
      origin_country:ci_line.cil_country_origin_code
      mid:ci.ci_mfid
      coast:ci.ci_destination_code
    }
    if ci_line.commercial_invoice_tariffs && ci_line.commercial_invoice_tariffs[0]
      t = ci_line.commercial_invoice_tariffs[0]
      r.hts_code = (if t.cit_hts_code then t.cit_hts_code.replace(/\./g, '') else null)
      r.net_weight = Number(t.cit_classification_qty_2 )
      r.gross_weight = Number(t.cit_gross_weight)
      r.reporting_quantity = Number(t.cit_classification_qty_1)
      r.reporting_uom = t.cit_classification_uom_1
    r

  recalc : (line) ->
    if line.unit_cost && line.unit_cost > 0 && line.quantity && line.quantity > 0
      iv = BigNumber(line.unit_cost).times(BigNumber(line.quantity))
      av = iv.times(BigNumber('1.0049'))
      line.invoice_value = Number(iv.round(2))
      line.adjusted_value = Number(av.round(2))

  getLines : (pageNumber,searchOpts) ->
    svc = @
    req = {
      page:pageNumber
      per_page:20
      sid1:'ci_imp_syscode'
      sop1:'eq'
      sv1:'HENNE'
      oid1:'ci_updated_at'
      oo1:'D'
    }
    sCounter = 2
    if searchOpts
      if searchOpts.poNumber
        req['sid'+sCounter] = 'ci_invoice_number'
        req['sop'+sCounter] = 'eq'
        req['sv'+sCounter] = searchOpts.poNumber
        sCounter++

    $http.get('/api/v1/commercial_invoices.json',{params:req}).success((d) ->
      d.lines = (svc.api_to_line(r) for r in d.results)
    )

  saveLine : (line) ->
    line.saving = true
    promise = null
    svc = @
    if line.id
      promise = $http.put('/api/v1/commercial_invoices/'+line.id+'.json',@.line_to_api(line))
    else
      promise = $http.post('/api/v1/commercial_invoices.json',@.line_to_api(line))
    promise.success((d,s,h,c) ->
      d.line = svc.api_to_line(d.commercial_invoice)
    ).error((d,s,h,c) ->
      line.saving = false
    )
    promise
]   

app.controller 'HMPOLineController', ['$scope','$interval','hmService',($scope,$interval,hmService) ->
  $scope.svc = hmService
  $scope.poLine = null
  $scope.recentLines = []
  $scope.searchField = 'poNumber'
  $scope.searchValue = undefined
  $scope.page = 1
  $scope.selectLine = (line) ->
    $scope.poLine = line

  $scope.saveLine = (line) ->
    return if line.saving #already saving, move on
    hmService.saveLine(line).success((data,status,headers,config) ->
      r = data.line
      foundPosition = undefined
      for ln, i in $scope.recentLines
        foundPosition = i if  ln.id == r.id
      $scope.recentLines.splice(foundPosition,1)
      $scope.recentLines.unshift r
      $scope.poLine = null #reset PO Line
      $scope.errorMessage = ""
      $scope.actionResponse = "Saved!"
      $interval(
        (() ->
          $scope.actionResponse = ""
        ),1000,1
      )
    ).error((d,s,h,c) ->
      $scope.errorMessage = d.errors[0]
    )

  $scope.getLineByPO = () ->
    if $scope.searchPO && $scope.searchPO.length > 0
      searchOpts = {poNumber:$scope.searchPO}
      $scope.missingPO = null
      $scope.poLine = null
      hmService.getLines(1,searchOpts).success((d,s,h,c) ->
        lines = d.lines
        if d.lines.length > 0
          $scope.poLine = d.lines[0]
        else
          $scope.missingPO = searchOpts.poNumber
      ).error((d,s,h,c) ->
        $scope.errorMessage = d.errors[0]
      )
  $scope.getLines = () ->
    $scope.loadingLines = true
    searchOpts = {}
    if $scope.searchField && $scope.searchValue && $scope.searchValue.length > 0
      searchOpts[$scope.searchField] = $scope.searchValue
    hmService.getLines($scope.page,searchOpts).success((d,s,h,c) ->
      $scope.loadingLines = false
      $scope.recentLines = d.lines
    ).error((d,s,h,c) ->
      $scope.errorMessage = d.errors[0]
    )
]