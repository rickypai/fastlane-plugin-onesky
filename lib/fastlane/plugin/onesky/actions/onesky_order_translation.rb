module Fastlane
  module Actions
    class OneskyOrderTranslationAction < Action
      def self.run(params)
        Actions.verify_gem!('onesky-ruby')
        require 'onesky'

        client = ::Onesky::Client.new(params[:public_key], params[:secret_key])
        project = client.project(params[:project_id])

        resp = project.list_file
        files = JSON.parse(resp)["data"]
        filenames = files.map { |f| f["file_name"] }

        resp = project.show_quotation(files: filenames, to_locale: params[:locale], is_including_not_translated: true, is_including_not_approved: true, is_including_outdated: true, specialization: "general")
        quote = JSON.parse(resp)["data"]

        quote_order_type = ''
        case params[:order_type]
        when 'translate-only'
          quote_order_type = 'translation_only'
        when 'review-only'
          quote_order_type = 'review_only'
        when 'translate-review'
          quote_order_type = 'translation_and_review'
        end
        option = quote[quote_order_type]
        count = option['word_count']
        cost = option['total_cost'].to_f

        if count == 0
          UI.message "Nothing to translate. :-)"
          return
        end

        translator_type = params[:translator_type]
        preferred_time = option['preferred_translator']['seconds_to_complete'] * 1.0 / 86400.0
        fastest_time = option['seconds_to_complete'] * 1.0 / 86400.0
        requested_time = translator_type == 'preferred' ? preferred_time : fastest_time

        UI.message "Received quote to translate #{count} words from #{quote['from_language']['english_name']} to #{quote['to_language']['english_name']} for #{option['total_cost']} in #{requested_time} days with the #{translator_type} translator."

        if cost > params[:max_cost]
          UI.error "Translation cost $#{option['total_cost']} is over $#{params[:max_cost]}. Not automatically ordering translation."
          return
        end

        if requested_time > params[:max_days]
          if translator_type == 'preferred' && fastest_time < params[:max_days]
            translator_type = 'fastest'
            UI.message "Switching to quote to complete it in #{fastest_time} days with the fastest translator."
          else
            UI.error "Translation time of #{requested_time} days is over limit of #{params[:max_days]} days. Not automatically ordering translation."
            return
          end
        end

        resp = project.create_order(files: filenames, to_locale: params[:locale], order_type: params[:order_type], is_including_not_translated: true, is_including_not_approved: true, is_including_outdated: true, translator_type: params[:translator_type], tone: 'formal', specialization: 'general')
        order = JSON.parse(resp)["data"]
        UI.success "Placed translation order ##{order['id']} at #{order['ordered_at']}."
      end

      def self.description
        'Order a translation from OneSky'
      end

      def self.authors
        ['timshadel']
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :public_key,
                                       env_name: 'ONESKY_PUBLIC_KEY',
                                       description: 'Public key for OneSky',
                                       is_string: true,
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise "No Public Key for OneSky given, pass using `public_key: 'token'`".red unless value and !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :secret_key,
                                       env_name: 'ONESKY_SECRET_KEY',
                                       description: 'Secret Key for OneSky',
                                       is_string: true,
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise "No Secret Key for OneSky given, pass using `secret_key: 'token'`".red unless value and !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :project_id,
                                       env_name: 'ONESKY_PROJECT_ID',
                                       description: 'Project Id to upload file to',
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise "No project id given, pass using `project_id: 'id'`".red unless value and !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :locale,
                                       env_name: 'ONESKY_DOWNLOAD_LOCALE',
                                       description: 'Locale to download the translation for',
                                       is_string: true,
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise 'No locale for translation given'.red unless value and !value.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :max_cost,
                                       env_name: 'ONESKY_MAX_COST',
                                       description: 'Maximum cost for this translation',
                                       is_string: false,
                                       optional: false,
                                       verify_block: proc do |value|
                                         raise 'No maximum cost given'.red unless value
                                         raise 'Maximum cost must be a number'.red unless value.is_a? Numeric
                                       end),
          FastlaneCore::ConfigItem.new(key: :max_days,
                                       env_name: 'ONESKY_MAX_DAYS',
                                       description: 'Maximum number of days for this translation',
                                       optional: true,
                                       default_value: 3,
                                       verify_block: proc do |value|
                                         raise 'Maximum number of days must be a number'.red unless value.is_a? Numeric
                                       end),
          FastlaneCore::ConfigItem.new(key: :order_type,
                                       env_name: 'ONESKY_ORDER_TYPE',
                                       description: 'Order type for this translation',
                                       is_string: true,
                                       optional: true,
                                       default_value: 'translate-only'),
          FastlaneCore::ConfigItem.new(key: :translator_type,
                                       env_name: 'ONESKY_TRANSLATOR_TYPE',
                                       description: 'Should we use the preferred or fastest translator?',
                                       is_string: true,
                                       optional: true,
                                       default_value: 'preferred')
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
