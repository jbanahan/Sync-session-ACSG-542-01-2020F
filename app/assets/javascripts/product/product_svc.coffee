angular.module('ProductApp').factory 'productSvc', ['$http','$q',($http,$q) ->
  currentProduct = undefined
  productLoadSuccessHandler = (resp) ->
    #handle the response then pass it along in the chain
    currentProduct = resp.data.product
    resp

  return {
    getProduct: (id) ->
      if currentProduct && parseInt(currentProduct.id) == parseInt(id)
        #simulate the http response with the cached object
        $q.when {data: {product: currentProduct}}
      else
        $http.get('/api/v1/products/'+id+'.json').then(productLoadSuccessHandler)

    saveProduct: (prod) ->
      currentProduct = null
      method = 'post'
      suffix = ''

      if prod.id > 0
        method = 'put'
        suffix = "/#{prod.id}.json"

      $http[method]("/api/v1/products"+suffix,{product:prod}).then(productLoadSuccessHandler)
      
    classificationByISO: (iso,product) ->
      return null unless product && product.classifications
      for cls in product.classifications
        cci = cls.class_cntry_iso
        cci = '' unless cci
        return cls if cci.toLowerCase() == iso.toLowerCase()
      return null
  }
]