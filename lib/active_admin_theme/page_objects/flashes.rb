module ActiveAdminTheme
  module PageObjects
    # Prepended to ActiveAdminPageObjects::Flashes. The theme renders every
    # flash type; the page objects accept ActiveAdmin's three, `warning` and
    # the types registered with `register_flash_type`, so a typo still raises.
    module Flashes
      @types = %i[warning]

      class << self
        attr_reader :types

        def register(type)
          type = type.to_sym
          @types |= [type]
          ActiveAdminPageObjects.register_selectors("flash_#{type}": ".aat-flash[data-flash='#{type}']")
        end
      end

      private

      def flash_types
        super | Flashes.types
      end
    end

    # Lets `flashes.has_flash?(type)` take a flash type the app sets, such as
    # `:info`.
    def self.register_flash_type(type)
      Flashes.register(type)
    end
  end
end

ActiveAdminPageObjects::Flashes.prepend(ActiveAdminTheme::PageObjects::Flashes)
