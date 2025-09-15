# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative "config/application"

Rails.application.load_tasks

namespace :resque do
	desc 'Start a Resque worker'
	task :work => :environment do
		require 'resque'
		QUEUE = ENV['QUEUE'] || '*'
		Resque::Worker.new(QUEUE.split(',')).work
	end

	desc 'Start resque-scheduler'
	task :scheduler => :environment do
		require 'resque/scheduler'
		Resque::Scheduler.run
	end
end
