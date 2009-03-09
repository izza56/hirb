module Hirb
  module Console
    def table(output, options={})
      Hirb::View.console_output_value(output, options.merge(:class=>"Hirb::Helpers::AutoTable"))
    end

    def view(*args)
      Hirb::View.console_output_value(*args)
    end
  end
end