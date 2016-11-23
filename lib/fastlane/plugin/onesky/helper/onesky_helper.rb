module Fastlane
  module Helper
    class OneskyHelper
      # class methods that you define here become available in your action
      # as `Helper::OneskyHelper.your_method`
      #
      def self.upload(public_key:, secret_key:, project_id:, strings_file_path:, strings_file_format:, deprecate_missing:, metadata: false)
        Actions.verify_gem!('onesky-ruby')
        require 'onesky'

        client = ::Onesky::Client.new(public_key, secret_key)

        project = client.project(project_id)

        UI.success 'Starting the upload to OneSky'
        resp = project.upload_file(
          file: strings_file_path,
          file_format: strings_file_format,
          is_keeping_all_strings: !deprecate_missing
        )

        if resp.code == 201
          item = metadata ? "App store metadata" : File.basename(strings_file_path)
          UI.success "#{item} was successfully uploaded to project #{project_id} in OneSky"
        else
          item = metadata ? "metadata" : "file"
          UI.error "Error uploading #{item} to OneSky, Status code is #{resp.code}"
        end
      end
    end
  end
end
