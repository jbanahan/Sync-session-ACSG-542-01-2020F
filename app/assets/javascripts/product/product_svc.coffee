angular.module('ProductApp').factory 'productSvc', ['$http','$q',($http,$q) ->
  currentProduct = undefined
  productSuccessHandler = (resp) ->
    #handle the response then pass it along in the chain
    currentProduct = resp.data.product
    resp

  return {
    getProduct: (id) ->
      if currentProduct && parseInt(currentProduct.id) == parseInt(id)
        #simulate the http response with the cached object
        $q.when {data: {product: currentProduct}}
      else
        $http.get('/api/v1/products/'+id+'.json').then(productSuccessHandler)
  }
]