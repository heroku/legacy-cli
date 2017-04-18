/**
 * This will conatain just the code in angularjs to invoke the rest api
 * 
 */

'use strict';

app.service("companyService",function(){
	
	$scope.companyOperations = function($scope,$rootScope,$resource,$http){
		var company = $http.post('/service/company/companydetails.json?option='x+"&companyID="xyz..thiss way other parameters);
		
		company.then(function(payload.data){
			//perform operatio
		});
		
		or 
		
		$http.post('/service/company/companydetails.json?option='x+"&companyID="xyz..thiss way other parameters)
		.success(function( data){
			
		}
		.failure(){
			
		});
	};
}
