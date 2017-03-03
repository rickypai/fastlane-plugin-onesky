module Fastlane
  module Helper
    class OneskyHelper
      # class methods that you define here become available in your action
      # as `Helper::OneskyHelper.your_method`
      #
      def self.upload(public_key:, secret_key:, project_id:, strings_file_path:, strings_file_format:, deprecate_missing:, onesky_locale: nil, skip_if_in_translation: true, metadata: false)
        Actions.verify_gem!('onesky-ruby')
        require 'onesky'

        client = ::Onesky::Client.new(public_key, secret_key)

        project = client.project(project_id)
        filename = File.basename(strings_file_path)
        if skip_if_in_translation && files_in_translation(project: project).include?(filename)
          UI.error "#{filename} is currently in translation. Skipping upload."
          return
        end

        UI.success 'Starting the upload to OneSky'
        resp = project.upload_file(
          file: strings_file_path,
          file_format: strings_file_format,
          is_keeping_all_strings: !deprecate_missing,
          locale: onesky_locale
        )

        if resp.code == 201
          item = metadata ? "App store metadata" : filename
          destination = onesky_locale || "default_locale"
          UI.success "#{item} was successfully uploaded to project #{project_id}/#{destination} in OneSky"
        else
          item = metadata ? "metadata" : "file"
          UI.error "Error uploading #{item} to OneSky, Status code is #{resp.code}"
        end
      end


      private

      def self.files_in_translation(project:)
        in_progress_orders(project: project).map { |o| files_in_order(project: project, order_id: o["id"]) }.flatten.uniq.sort
      end

      def self.in_progress_orders(project:)
        resp = project.list_order
        return [] unless resp.length > 0 && resp.code == 200

        orders = JSON.parse(resp)["data"]
        orders.select { |o| o["status"] == "in-progress" }
      end

      def self.files_in_order(project:, order_id:)
        resp = project.show_order(order_id)
        return [] unless resp.length > 0 && resp.code == 200

        order = JSON.parse(resp)["data"]
        order["files"].map { |f| f["name"] }
      end

    end
  end
end
