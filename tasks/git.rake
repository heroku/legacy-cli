namespace :git do
  desc "tags the repo at the current version and pushes it to github"
  task :tag do
    sh "git tag v#{version}"
    sh "git push origin v#{version}"
  end
end
