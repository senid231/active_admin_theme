require "active_admin_page_objects/rspec"
require "active_admin_theme/page_objects"

module ActiveAdminTheme
  module PageObjects
    # RSpec matchers for the theme's page objects. Include the module after
    # ActiveAdminPageObjects::RSpec::Matchers, and require this file only in a
    # suite that uses RSpec:
    #
    #   require "active_admin_theme/page_objects/rspec"
    #
    #   RSpec.configure do |config|
    #     config.include ActiveAdminPageObjects::RSpec::Matchers
    #     config.include ActiveAdminTheme::PageObjects::RSpec::Matchers
    #   end
    #
    #   expect(show.attributes_table).to have_secret_mask(:token)
    #   expect(show.attributes_table).to have_secret_value(:token, "s3cr3t")
    #   expect(show.attributes_table.secret(:token)).to have_secret_value("s3cr3t")
    module RSpec
      NAMES = %i[have_secret_mask have_secret_value].freeze

      # `have_secret_mask(key)`: the secret is shown masked. `have_secret_value(key, "s3cr3t")`:
      # it is shown and equals the value. A SecretReveal takes no key.
      module Matchers
        NAMES.each do |name|
          define_method(name) do |*args, **options, &block|
            other = defined?(super) ? -> { super(*args, **options, &block) } : nil
            ActiveAdminPageObjects::RSpec::Matcher.new(name, other, *args, **options, &block)
          end
        end
      end
    end
  end
end
