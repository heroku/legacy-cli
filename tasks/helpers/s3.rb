def s3_connect
  return if @s3_connected

  require "aws/s3"

  unless ENV["HEROKU_RELEASE_ACCESS"] && ENV["HEROKU_RELEASE_SECRET"]
    puts "please set HEROKU_RELEASE_ACCESS and HEROKU_RELEASE_SECRET in your environment"
    exit 1
  end

  AWS::S3::Base.establish_connection!(
    :access_key_id => ENV["HEROKU_RELEASE_ACCESS"],
    :secret_access_key => ENV["HEROKU_RELEASE_SECRET"]
  )

  @s3_connected = true
end

def s3_store(package_file, filename, bucket="assets.heroku.com")
  s3_connect
  puts "storing: #{filename}"
  AWS::S3::S3Object.store(filename, File.open(package_file), bucket, :access => :public_read)
end

def s3_store_dir(from, to, bucket="assets.heroku.com")
  Dir.glob(File.join(from, "**", "*")).each do |file|
    next if File.directory?(file)
    remote = file.gsub(from, to)
    s3_store file, remote, bucket
  end
end
