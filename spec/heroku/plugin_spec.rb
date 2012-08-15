require "spec_helper"
require "heroku/plugin"

module Heroku
  describe Plugin do
    include SandboxHelper

    it "lives in ~/.heroku/plugins" do
      Plugin.stub!(:home_directory).and_return('/home/user')
      Plugin.directory.should == '/home/user/.heroku/plugins'
    end

    it "extracts the name from git urls" do
      Plugin.new('git://github.com/heroku/plugin.git').name.should == 'plugin'
    end

    describe "management" do
      before(:each) do
        @sandbox = "/tmp/heroku_plugins_spec_#{Process.pid}"
        FileUtils.mkdir_p(@sandbox)
        Dir.stub!(:pwd).and_return(@sandbox)
        Plugin.stub!(:directory).and_return(@sandbox)
      end

      after(:each) do
        FileUtils.rm_rf(@sandbox)
      end

      it "lists installed plugins" do
        FileUtils.mkdir_p(@sandbox + '/plugin1')
        FileUtils.mkdir_p(@sandbox + '/plugin2')
        Plugin.list.should include 'plugin1'
        Plugin.list.should include 'plugin2'
      end

      it "installs pulling from the plugin url" do
        plugin_folder = "/tmp/heroku_plugin"
        FileUtils.mkdir_p(plugin_folder)
        `cd #{plugin_folder} && git init && echo 'test' > README && git add . && git commit -m 'my plugin'`
        Plugin.new(plugin_folder).install
        File.directory?("#{@sandbox}/heroku_plugin").should be_true
        File.read("#{@sandbox}/heroku_plugin/README").should == "test\n"
      end

      it "reinstalls over old copies" do
        plugin_folder = "/tmp/heroku_plugin"
        FileUtils.mkdir_p(plugin_folder)
        `cd #{plugin_folder} && git init && echo 'test' > README && git add . && git commit -m 'my plugin'`
        Plugin.new(plugin_folder).install
        Plugin.new(plugin_folder).install
        File.directory?("#{@sandbox}/heroku_plugin").should be_true
        File.read("#{@sandbox}/heroku_plugin/README").should == "test\n"
      end

      context "update" do

        before(:each) do
          plugin_folder = "/tmp/heroku_plugin"
          FileUtils.mkdir_p(plugin_folder)
          `cd #{plugin_folder} && git init && echo 'test' > README && git add . && git commit -m 'my plugin'`
          Plugin.new(plugin_folder).install
          `cd #{plugin_folder} && echo 'updated' > README && git add . && git commit -m 'my plugin update'`
        end

        it "updates existing copies" do
          Plugin.new('heroku_plugin').update
          File.directory?("#{@sandbox}/heroku_plugin").should be_true
          File.read("#{@sandbox}/heroku_plugin/README").should == "updated\n"
        end

        it "warns on legacy plugins" do
          `cd #{@sandbox}/heroku_plugin && git config --unset branch.master.remote`
          stderr = capture_stderr do
            begin
              Plugin.new('heroku_plugin').update
            rescue SystemExit
            end
          end
          stderr.should == <<-STDERR
 !    heroku_plugin is a legacy plugin installation.
 !    Enable updating by reinstalling with `heroku plugins:install`.
STDERR
        end

        it "raises exception on symlinked plugins" do
          `cd #{@sandbox} && ln -s heroku_plugin heroku_plugin_symlink`
          lambda { Plugin.new('heroku_plugin_symlink').update }.should raise_error Heroku::Plugin::ErrorUpdatingSymlinkPlugin
        end

      end


      it "uninstalls removing the folder" do
        FileUtils.mkdir_p(@sandbox + '/plugin1')
        Plugin.new('git://github.com/heroku/plugin1.git').uninstall
        Plugin.list.should == []
      end

      it "adds the lib folder in the plugin to the load path, if present" do
        FileUtils.mkdir_p(@sandbox + '/plugin/lib')
        File.open(@sandbox + '/plugin/lib/my_custom_plugin_file.rb', 'w') { |f| f.write "" }
        Plugin.load!
        lambda { require 'my_custom_plugin_file' }.should_not raise_error(LoadError)
      end

      it "loads init.rb, if present" do
        FileUtils.mkdir_p(@sandbox + '/plugin')
        File.open(@sandbox + '/plugin/init.rb', 'w') { |f| f.write "LoadedInit = true" }
        Plugin.load!
        LoadedInit.should be_true
      end

      describe "when there are plugin load errors" do
        before(:each) do
          FileUtils.mkdir_p(@sandbox + '/some_plugin/lib')
          File.open(@sandbox + '/some_plugin/init.rb', 'w') { |f| f.write "require 'some_non_existant_file'" }
        end

        it "should not throw an error" do
          capture_stderr do
            lambda { Plugin.load! }.should_not raise_error
          end
        end

        it "should fail gracefully" do
          stderr = capture_stderr do
            Plugin.load!
          end
          stderr.should include('some_non_existant_file (LoadError)')
        end

        it "should still load other plugins" do
          FileUtils.mkdir_p(@sandbox + '/some_plugin_2/lib')
          File.open(@sandbox + '/some_plugin_2/init.rb', 'w') { |f| f.write "LoadedPlugin2 = true" }
          stderr = capture_stderr do
            Plugin.load!
          end
          stderr.should include('some_non_existant_file (LoadError)')
          LoadedPlugin2.should be_true
        end
      end

      describe "deprecated plugins" do
        before(:each) do
          FileUtils.mkdir_p(@sandbox + '/heroku-releases/lib')
        end

        after(:each) do
          FileUtils.rm_rf(@sandbox + '/heroku-releases/lib')
        end

        it "should show confirmation to remove deprecated plugins if in an interactive shell" do
          old_stdin_isatty = STDIN.isatty
          STDIN.stub!(:isatty).and_return(true)
          Plugin.should_receive(:confirm).with("The plugin heroku-releases has been deprecated. Would you like to remove it? (y/N)").and_return(true)
          Plugin.should_receive(:remove_plugin).with("heroku-releases")
          Plugin.load!
          STDIN.stub!(:isatty).and_return(old_stdin_isatty)
        end

        it "should not prompt for deprecation if not in an interactive shell" do
          old_stdin_isatty = STDIN.isatty
          STDIN.stub!(:isatty).and_return(false)
          Plugin.should_not_receive(:confirm)
          Plugin.should_not_receive(:remove_plugin).with("heroku-releases")
          Plugin.load!
          STDIN.stub!(:isatty).and_return(old_stdin_isatty)
        end
      end
    end
  end
end
