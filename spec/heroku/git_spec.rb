require "heroku/git"

describe Heroku::Git do
  # Secure versions from http://article.gmane.org/gmane.linux.kernel/1853266
  it "determines an insecure 1.7 version is insecure" do
    expect(Heroku::Git.git_is_insecure('1.7')).to eq(true)
  end

  it "determines an insecure 1.8 version is insecure" do
    expect(Heroku::Git.git_is_insecure('1.8.5')).to eq(true)
  end

  it "determines an secure 1.8 version is secure" do
    expect(Heroku::Git.git_is_insecure('1.8.5.6')).to eq(false)
  end

  it "determines an insecure 1.9 version is insecure" do
    expect(Heroku::Git.git_is_insecure('1.9.3')).to eq(true)
  end

  it "determines an secure 1.9 version is secure" do
    expect(Heroku::Git.git_is_insecure('1.9.5')).to eq(false)
  end

  it "determines an insecure 2.0 version is insecure" do
    expect(Heroku::Git.git_is_insecure('2.0')).to eq(true)
  end

  it "determines an secure 2.0 version is secure" do
    expect(Heroku::Git.git_is_insecure('2.0.5')).to eq(false)
  end

  it "determines an insecure 2.1 version is insecure" do
    expect(Heroku::Git.git_is_insecure('2.1')).to eq(true)
  end

  it "determines an secure 2.1 version is secure" do
    expect(Heroku::Git.git_is_insecure('2.1.4')).to eq(false)
  end

  it "determines an insecure 2.2 version is insecure" do
    expect(Heroku::Git.git_is_insecure('2.2')).to eq(true)
  end

  it "determines an secure 2.2 version is secure" do
    expect(Heroku::Git.git_is_insecure('2.2.1')).to eq(false)
  end
end
