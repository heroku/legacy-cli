require "spec_helper"
require "heroku/command/status"

module Heroku::Command
  describe Status do

    before(:each) do
      stub_core
    end

    it "displays status information" do
      Excon.stub(
        {
          :host   => 'status.heroku.com',
          :method => :get,
          :path   => '/api/v3/current-status.json'
        },
        {
          :body   => Heroku::API::OkJson.encode({"status"=>{"Production"=>"red", "Development"=>"red"}, "issues"=>[{"created_at"=>"2012-06-07T15:55:51Z", "id"=>372, "resolved"=>false, "title"=>"HTTP Routing Errors", "updated_at"=>"2012-06-07T16:14:37Z", "href"=>"https://status.heroku.com/api/v3/issues/372", "updates"=>[{"contents"=>"The number of applications seeing H99 errors is continuing to decrease as we continue to work toward a full resolution of the HTTP routing issues. The API is back online now as well. ", "created_at"=>"2012-06-07T17:47:26Z", "id"=>1088, "incident_id"=>372, "status_dev"=>"red", "status_prod"=>"red", "update_type"=>"update", "updated_at"=>"2012-06-07T17:47:26Z"}, {"contents"=>"Our engineers are continuing to work toward a full resolution of the HTTP routing issues. The API is currently in maintenance mode intentionally as we restore application operations. ", "created_at"=>"2012-06-07T17:16:40Z", "id"=>1086, "incident_id"=>372, "status_dev"=>"red", "status_prod"=>"red", "update_type"=>"update", "updated_at"=>"2012-06-07T17:26:55Z"}, {"contents"=>"Most applications are back online at this time. Our engineers are working on getting the remaining apps back online. ", "created_at"=>"2012-06-07T16:50:21Z", "id"=>1085, "incident_id"=>372, "status_dev"=>"red", "status_prod"=>"red", "update_type"=>"update", "updated_at"=>"2012-06-07T16:50:21Z"}, {"contents"=>"Our routing engineers have pushed out a patch to our routing tier. The platform is recovering and applications are coming back online. Our engineers are continuing to fully restore service.", "created_at"=>"2012-06-07T16:36:37Z", "id"=>1084, "incident_id"=>372, "status_dev"=>"red", "status_prod"=>"red", "update_type"=>"update", "updated_at"=>"2012-06-07T16:36:37Z"}, {"contents"=>"We have identified an issue with our routers that is causing errors on HTTP requests to applications. Engineers are working to resolve the issue.\r\n", "created_at"=>"2012-06-07T16:15:25Z", "id"=>1083, "incident_id"=>372, "status_dev"=>"red", "status_prod"=>"red", "update_type"=>"update", "updated_at"=>"2012-06-07T16:15:28Z"}, {"contents"=>"We have confirmed widespread errors on the platform. Our engineers are continuing to investigate.\r\n", "created_at"=>"2012-06-07T15:58:56Z", "id"=>1082, "incident_id"=>372, "status_dev"=>"red", "status_prod"=>"red", "update_type"=>"update", "updated_at"=>"2012-06-07T15:58:58Z"}, {"contents"=>"Our automated systems have detected potential platform errors.  We are investigating.\r\n", "created_at"=>"2012-06-07T15:55:51Z", "id"=>1081, "incident_id"=>372, "status_dev"=>"yellow", "status_prod"=>"yellow", "update_type"=>"issue", "updated_at"=>"2012-06-07T15:55:55Z"}]}]}),
          :status => 200
        }
      )

      Heroku::Command::Status.any_instance.should_receive(:time_ago).and_return('3h ago', '1m ago', '5m ago', '10m ago', '30m ago', '1h ago', '2h ago', '3h ago')

      stderr, stdout = execute("status")
      stderr.should == ''
      stdout.should == <<-STDOUT
=== Heroku Status
Development: red
Production:  red

=== HTTP Routing Errors (3h+)
1m ago   update  The number of applications seeing H99 errors is continuing to decrease as we continue to work toward a full resolution of the HTTP routing issues. The API is back online now as well.
5m ago   update  Our engineers are continuing to work toward a full resolution of the HTTP routing issues. The API is currently in maintenance mode intentionally as we restore application operations.
10m ago  update  Most applications are back online at this time. Our engineers are working on getting the remaining apps back online.
30m ago  update  Our routing engineers have pushed out a patch to our routing tier. The platform is recovering and applications are coming back online. Our engineers are continuing to fully restore service.
1h ago   update  We have identified an issue with our routers that is causing errors on HTTP requests to applications. Engineers are working to resolve the issue.
2h ago   update  We have confirmed widespread errors on the platform. Our engineers are continuing to investigate.
3h ago   issue   Our automated systems have detected potential platform errors.  We are investigating.

STDOUT

      Excon.stubs.shift
    end

  end
end
