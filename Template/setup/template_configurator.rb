require 'fileutils'
require 'colored2'

module Stanwood
  class TemplateConfigurator

    attr_reader :pod_name, :pods_for_podfile, :test_example_file, :username, :email

    def initialize(pod_name)
      @pod_name = pod_name
      @pods_for_podfile = []
      @message_bank = MessageBank.new(self)
    end

    def run
      @message_bank.welcome_message

      ConfigureSwift.perform(configurator: self)

      puts "Replace variables in files"
      replace_variables_in_files

      puts "Clean template files"
      clean_template_files

      puts "Adding pods to podfile"
      add_pods_to_podfile

      puts "Renaming classes folder"
      rename_classes_folder

      puts "Ensuring carthage compatibility"
      ensure_carthage_compatibility

      puts "Reinitializing git repo"
      reinitialize_git_repo

      puts "Running pod install"
      run_pod_install

      `mv ./#{pod_name}/ ../`

      @message_bank.farewell_message
    end

    def ask(question)
      answer = ""
      loop do
        puts "\n#{question}?"

        @message_bank.show_prompt
        answer = gets.chomp

        break if answer.length > 0

        print "\nYou need to provide an answer."
      end
      answer
    end

    def ask_for_project_key(question)
      answer = ""

      puts "\n#{question}?"
      @message_bank.show_prompt
      answer = gets.chomp

      if answer.length === 3 then
        answer
      else
        print "\nYou need to provide a project key with three characters."
        ask_for_project_key(question)
      end
    end

    def ask_with_answers(question, possible_answers)

      print "\n#{question}? ["

      print_info = Proc.new {

        possible_answers_string = possible_answers.each_with_index do |answer, i|
           _answer = (i == 0) ? answer.underlined : answer
           print " " + _answer
           print(" /") if i != possible_answers.length-1
        end
        print " ]\n"
      }
      print_info.call

      answer = ""

      loop do
        @message_bank.show_prompt
        answer = gets.downcase.chomp

        answer = "yes" if answer == "y"
        answer = "no" if answer == "n"

        # default to first answer
        if answer == ""
          answer = possible_answers[0].downcase
          print answer.yellow
        end

        break if possible_answers.map { |a| a.downcase }.include? answer

        print "\nPossible answers are ["
        print_info.call
      end

      answer
    end

    #----------------------------------------#

    def ensure_carthage_compatibility
      FileUtils.ln_s('PROJECT/Pods/Pods.xcodeproj', '_Pods.xcodeproj')
    end

    def run_pod_install
      puts "\nRunning " + "pod install".magenta + " on your new library."
      puts ""

      Dir.chdir(pod_name) do
        system "pod install"
      end

      `git add #{pod_name}/#{pod_name}.xcodeproj/project.pbxproj`
      `git commit -m "Initial commit"`
    end

    def clean_template_files
      ["./**/.gitkeep", "configure", "_CONFIGURE.rb", "templates", "setup"].each do |asset|
        `rm -rf #{asset}`
      end
    end

    def replace_variables_in_files
      file_names = [podfile_path]
      file_names.each do |file_name|
        text = File.read(file_name)
        text.gsub!("${POD_NAME}", @pod_name)
        text.gsub!("${REPO_NAME}", @pod_name.gsub('+', '-'))
        text.gsub!("${USER_NAME}", user_name)
        text.gsub!("${USER_EMAIL}", user_email)
        text.gsub!("${YEAR}", year)
        text.gsub!("${DATE}", date)
        File.open(file_name, "w") { |file| file.puts text }
      end
    end

    def add_pod_to_podfile podname
      @pods_for_podfile << podname
    end

    def add_pods_to_podfile
      podfile = File.read podfile_path
      podfile_content = @pods_for_podfile.map do |pod|
        "pod " + pod
      end.join("\n    ")
      podfile.gsub!("${INCLUDED_PODS}", podfile_content)
      File.open(podfile_path, "w") { |file| file.puts podfile }
    end

    def set_test_framework(test_type, extension, folder)
      content_path = "setup/test_examples/" + test_type + "." + extension
      tests_path = "templates/" + folder + "/PROJECT/Tests/Tests." + extension
      tests = File.read tests_path
      tests.gsub!("${TEST_EXAMPLE}", File.read(content_path) )
      File.open(tests_path, "w") { |file| file.puts tests }
    end

    def rename_classes_folder
      FileUtils.mv "Pod", @pod_name
    end

    def reinitialize_git_repo
      `rm -rf .git`
      `git init`
      `git add -A`
    end

    def validate_user_details
        return (user_email.length > 0) && (user_name.length > 0)
    end

    #----------------------------------------#

    def user_name
      (ENV['GIT_COMMITTER_NAME'] || github_user_name || `git config user.name` || `<GITHUB_USERNAME>` ).strip
    end

    def github_user_name
      github_user_name = `security find-internet-password -s github.com | grep acct | sed 's/"acct"<blob>="//g' | sed 's/"//g'`.strip
      is_valid = github_user_name.empty? or github_user_name.include? '@'
      return is_valid ? nil : github_user_name
    end

    def user_email
      (ENV['GIT_COMMITTER_EMAIL'] || `git config user.email`).strip
    end

    def year
      Time.now.year.to_s
    end

    def date
      Time.now.strftime "%m/%d/%Y"
    end

    def podfile_path
      pod_name + '/Podfile'
    end

    #----------------------------------------#
  end
end
