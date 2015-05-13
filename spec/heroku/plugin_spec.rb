require "spec_helper"
require "heroku/plugin"

module Heroku
  describe Plugin do
    include SandboxHelper

    it "lives in ~/.heroku/plugins" do
      allow(Plugin).to receive(:home_directory).and_return('/home/user')
      expect(Plugin.directory).to eq('/home/user/.heroku/plugins')
    end

    it "extracts the name from git urls" do
      expect(Plugin.new('git://github.com/heroku/plugin.git').name).to eq('plugin')
    end

    describe "management" do
      before(:each) do
        @sandbox = "/tmp/heroku_plugins_spec_#{Process.pid}"
        FileUtils.mkdir_p(@sandbox)
        allow(Dir).to receive(:pwd).and_return(@sandbox)
        allow(Plugin).to receive(:directory).and_return(@sandbox)
      end

      after(:each) do
        FileUtils.rm_rf(@sandbox)
      end

      it "lists installed plugins" do
        FileUtils.mkdir_p(@sandbox + '/plugin1')
        FileUtils.mkdir_p(@sandbox + '/plugin2')
        expect(Plugin.list).to include 'plugin1'
        expect(Plugin.list).to include 'plugin2'
      end

      it "installs pulling from the plugin url" do
        plugin_folder = "/tmp/heroku_plugin"
        FileUtils.mkdir_p(plugin_folder)
        `cd #{plugin_folder} && git init && echo 'test' > README && git add . && git commit -m 'my plugin'`
        Plugin.new(plugin_folder).install
        expect(File.directory?("#{@sandbox}/heroku_plugin")).to be_truthy
        expect(File.read("#{@sandbox}/heroku_plugin/README")).to eq("test\n")
      end

      it "reinstalls over old copies" do
        plugin_folder = "/tmp/heroku_plugin"
        FileUtils.mkdir_p(plugin_folder)
        `cd #{plugin_folder} && git init && echo 'test' > README && git add . && git commit -m 'my plugin'`
        Plugin.new(plugin_folder).install
        Plugin.new(plugin_folder).install
        expect(File.directory?("#{@sandbox}/heroku_plugin")).to be_truthy
        expect(File.read("#{@sandbox}/heroku_plugin/README")).to eq("test\n")
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
          expect(File.directory?("#{@sandbox}/heroku_plugin")).to be_truthy
          expect(File.read("#{@sandbox}/heroku_plugin/README")).to eq("updated\n")
        end

        it "raises exception on symlinked plugins" do
          `cd #{@sandbox} && ln -s heroku_plugin heroku_plugin_symlink`
          expect { Plugin.new('heroku_plugin_symlink').update }.to raise_error Heroku::Plugin::ErrorUpdatingSymlinkPlugin
        end

      end


      it "uninstalls removing the folder" do
        FileUtils.mkdir_p(@sandbox + '/plugin1')
        Plugin.new('git://github.com/heroku/plugin1.git').uninstall
        expect(Plugin.list).to eq([])
      end

      it "adds the lib folder in the plugin to the load path, if present" do
        FileUtils.mkdir_p(@sandbox + '/plugin/lib')
        File.open(@sandbox + '/plugin/lib/my_custom_plugin_file.rb', 'w') { |f| f.write "" }
        Plugin.load!
        expect { require 'my_custom_plugin_file' }.not_to raise_error
      end

      it "loads init.rb, if present" do
        FileUtils.mkdir_p(@sandbox + '/plugin')
        File.open(@sandbox + '/plugin/init.rb', 'w') { |f| f.write "LoadedInit = true" }
        Plugin.load!
        expect(LoadedInit).to be_truthy
      end

      describe "when there are plugin load errors" do
        before(:each) do
          FileUtils.mkdir_p(@sandbox + '/some_plugin/lib')
          File.open(@sandbox + '/some_plugin/init.rb', 'w') { |f| f.write "require 'some_non_existant_file'" }
        end

        it "should not throw an error" do
          capture_stderr do
            expect { Plugin.load! }.not_to raise_error
          end
        end

        it "should fail gracefully" do
          stderr = capture_stderr do
            Plugin.load!
          end
          expect(stderr).to include('some_non_existant_file (LoadError)')
        end

        it "should still load other plugins" do
          FileUtils.mkdir_p(@sandbox + '/some_plugin_2/lib')
          File.open(@sandbox + '/some_plugin_2/init.rb', 'w') { |f| f.write "LoadedPlugin2 = true" }
          stderr = capture_stderr do
            Plugin.load!
          end
          expect(stderr).to include('some_non_existant_file (LoadError)')
          expect(LoadedPlugin2).to be_truthy
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
          allow(STDIN).to receive(:isatty).and_return(true)
          expect(Plugin).to receive(:confirm).with("The plugin heroku-releases has been deprecated. Would you like to remove it? (y/N)").and_return(true)
          expect(Plugin).to receive(:remove_plugin).with("heroku-releases")
          Plugin.load!
          allow(STDIN).to receive(:isatty).and_return(old_stdin_isatty)
        end

        it "should not prompt for deprecation if not in an interactive shell" do
          old_stdin_isatty = STDIN.isatty
          allow(STDIN).to receive(:isatty).and_return(false)
          expect(Plugin).not_to receive(:confirm)
          expect(Plugin).not_to receive(:remove_plugin).with("heroku-releases")
          Plugin.load!
          allow(STDIN).to receive(:isatty).and_return(old_stdin_isatty)
        end
      end
    end
  end
end
